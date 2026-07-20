module controlador_rtc_ds3231 (
    input clk_50Mhz,           // Reloj base de la FPGA
    input rst,                 // Reset del sistema
    output reg scl,            // Pin físico SCL hacia el RTC
    inout sda,                 // Pin físico SDA (bidireccional)
    output reg [7:0] segundos, // Salida en BCD
    output reg [7:0] minutos,  // Salida en BCD
    output reg [7:0] horas     // Salida en BCD
);

    // Generador de ticks a 400 kHz (Genera 4 fases precisas para los 100 kHz del I2C)
    reg [7:0] clk_div;
    reg i2c_tick;
    always @(posedge clk_50Mhz or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            i2c_tick <= 0;
        end else begin
            if (clk_div >= 124) begin // 50 MHz / 125 = 400 kHz
                clk_div <= 0;
                i2c_tick <= 1'b1;
            end else begin
                clk_div <= clk_div + 1;
                i2c_tick <= 1'b0;
            end
        end
    end

    // Fases del reloj y control del pin bidireccional (Open-Drain real)
    reg [1:0] phase;
    reg sda_out;
    reg sda_en;
    assign sda = (sda_en && sda_out == 1'b0) ? 1'b0 : 1'bz;
    wire sda_in = sda;

    // Máquina de estados sincronizada por fases
    reg [5:0] estado;
    reg [3:0] bit_cnt;
    reg [7:0] data_reg;
    reg [19:0] delay_cnt;

    localparam IDLE         = 0,
               START        = 1,
               WRITE_ADDR   = 2,
               ACK1         = 3,
               WRITE_REG    = 4,
               ACK2         = 5,
               RESTART_ST   = 6,
               WRITE_ADDR_R = 7,
               ACK3         = 8,
               READ_SEC     = 9,
               ACK_SEC      = 10,
               READ_MIN     = 11,
               ACK_MIN      = 12,
               READ_HR      = 13,
               NACK_HR      = 14,
               STOP         = 15,
               DELAY        = 16;

    always @(posedge clk_50Mhz or posedge rst) begin
        if (rst) begin
            estado <= IDLE;
            phase <= 0;
            scl <= 1'b1;
            sda_out <= 1'b1;
            sda_en <= 1'b0;
            bit_cnt <= 7;
            segundos <= 8'h00;
            minutos <= 8'h00;
            horas <= 8'h00;
            delay_cnt <= 0;
        end else if (i2c_tick) begin
            phase <= phase + 1;

            case (estado)
                IDLE: begin
                    scl <= 1'b1;
                    sda_out <= 1'b1;
                    sda_en <= 1'b1;
                    if (phase == 3) estado <= START;
                end

                START: begin
                    if (phase == 0) sda_out <= 1'b0; // SDA baja mientras SCL=1
                    if (phase == 2) scl <= 1'b0;     // SCL baja
                    if (phase == 3) begin
                        data_reg <= 8'hD0; // Dirección I2C + Escritura
                        bit_cnt <= 7;
                        estado <= WRITE_ADDR;
                    end
                end

                WRITE_ADDR: begin
                    if (phase == 0) sda_out <= data_reg[bit_cnt]; // Escribe en SCL bajo
                    if (phase == 1) scl <= 1'b1;                  // SCL sube
                    if (phase == 3) scl <= 1'b0;                  // SCL baja
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b0; // Libera SDA para leer el ACK
                            estado <= ACK1;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK1: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        sda_en <= 1'b1;
                        data_reg <= 8'h00; // Registro 0x00 (Segundos)
                        bit_cnt <= 7;
                        estado <= WRITE_REG;
                    end
                end

                WRITE_REG: begin
                    if (phase == 0) sda_out <= data_reg[bit_cnt];
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b0; // Libera SDA
                            estado <= ACK2;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK2: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        sda_en <= 1'b1;
                        sda_out <= 1'b1;
                        estado <= RESTART_ST;
                    end
                end

                RESTART_ST: begin
                    if (phase == 0) scl <= 1'b1;     // SCL sube
                    if (phase == 1) sda_out <= 1'b0; // SDA baja con SCL alto (Re-Start)
                    if (phase == 3) scl <= 1'b0;     // SCL baja
                    if (phase == 3) begin
                        data_reg <= 8'hD1; // Dirección I2C + Lectura
                        bit_cnt <= 7;
                        estado <= WRITE_ADDR_R;
                    end
                end

                WRITE_ADDR_R: begin
                    if (phase == 0) sda_out <= data_reg[bit_cnt];
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b0; // Libera SDA
                            estado <= ACK3;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK3: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        bit_cnt <= 7;
                        estado <= READ_SEC;
                    end
                end

                READ_SEC: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 2) segundos[bit_cnt] <= sda_in; // Lee el dato exactamente en el centro
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b1;
                            sda_out <= 1'b0; // Prepara ACK maestro
                            estado <= ACK_SEC;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK_SEC: begin
                    if (phase == 0) sda_out <= 1'b0; // Maestro envía ACK (0)
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        sda_en <= 1'b0; // Libera SDA para la siguiente lectura
                        bit_cnt <= 7;
                        estado <= READ_MIN;
                    end
                end

                READ_MIN: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 2) minutos[bit_cnt] <= sda_in;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b1;
                            sda_out <= 1'b0; // Prepara ACK maestro
                            estado <= ACK_MIN;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK_MIN: begin
                    if (phase == 0) sda_out <= 1'b0; // Maestro envía ACK (0)
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        sda_en <= 1'b0; // Libera SDA
                        bit_cnt <= 7;
                        estado <= READ_HR;
                    end
                end

                READ_HR: begin
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 2) horas[bit_cnt] <= sda_in;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        if (bit_cnt == 0) begin
                            sda_en <= 1'b1;
                            sda_out <= 1'b1; // Prepara NACK maestro (1) indicando fin
                            estado <= NACK_HR;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                NACK_HR: begin
                    if (phase == 0) sda_out <= 1'b1; // Maestro envía NACK (1)
                    if (phase == 1) scl <= 1'b1;
                    if (phase == 3) scl <= 1'b0;
                    if (phase == 3) begin
                        sda_out <= 1'b0; // Tira SDA a cero antes del STOP
                        estado <= STOP;
                    end
                end

                STOP: begin
                    if (phase == 1) scl <= 1'b1;     // SCL sube
                    if (phase == 2) sda_out <= 1'b1; // SDA sube mientras SCL es alto (Secuencia STOP)
                    if (phase == 3) begin
                        sda_en <= 1'b0;
                        estado <= DELAY;
                    end
                end

                DELAY: begin
                    // Ticks a 400kHz. 200,000 ticks = 0.5 segundos de espera
                    if (delay_cnt >= 200000) begin
                        delay_cnt <= 0;
                        estado <= IDLE;
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule