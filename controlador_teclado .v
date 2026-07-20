module controlador_teclado (
    input clk_50Mhz,
    input rst,
    input [3:0] cols,             // Columnas del teclado (Entradas con pull-up)
    output reg [3:0] rows,        // Filas del teclado (Salidas)
    output reg [6:0] sw_datos,    // Emula los switches (0 a 59 en binario)
    output reg [0:0] sw_selector, // Emula el selector (0 = Minutos, 1 = Horas)
    output reg btn_guardar_emulado// Emula el botón físico (Activo en BAJO)
);

    // =========================================================================
    // 1. DIVISOR DE FRECUENCIA A 1 kHz (Integrado desde tu laboratorio)
    // =========================================================================
    reg [15:0] contador_1khz;
    reg tick_1ms;
    
    always @(posedge clk_50Mhz or posedge rst) begin
        if (rst) begin
            contador_1khz <= 16'd0;
            tick_1ms <= 1'b0;
        end else begin
            if (contador_1khz >= 16'd49999) begin // 50,000 ciclos = 1 ms
                contador_1khz <= 16'd0;
                tick_1ms <= 1'b1;
            end else begin
                contador_1khz <= contador_1khz + 16'd1;
                tick_1ms <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 2. ESCÁNER FSM (Extraído exactamente de escaner_teclado.v)
    // =========================================================================
    reg [1:0] fila_actual;
    reg [3:0] contador_debounce;
    reg [1:0] estado;

    localparam ESCANEO             = 2'd0;
    localparam VALIDAR_PRESION     = 2'd1;
    localparam ESPERAR_LIBERACION  = 2'd2;
    localparam VALIDAR_LIBERACION  = 2'd3;
    localparam DEBOUNCE_TIME       = 10; // 10 ms para estabilidad

    reg [3:0] tecla_detectada;
    reg nuevo_pulso_tecla; 

        always @(posedge clk_50Mhz or posedge rst) begin
        if (rst) begin
            fila_actual <= 2'b00;
            rows <= 4'b1110;
            contador_debounce <= 4'd0;
            estado <= ESCANEO;
            tecla_detectada <= 4'hF;
            nuevo_pulso_tecla <= 1'b0;
        end else begin
            nuevo_pulso_tecla <= 1'b0; // Apagado por defecto

            if (tick_1ms) begin
                case (estado)
                    ESCANEO: begin
                        if (cols == 4'b1111) begin
                            fila_actual <= fila_actual + 1'b1;
                            case (fila_actual + 1'b1)
                                2'b00: rows <= 4'b1110;
                                2'b01: rows <= 4'b1101;
                                2'b10: rows <= 4'b1011;
                                2'b11: rows <= 4'b0111;
                            endcase
                        end else begin
                            contador_debounce <= 4'd0;
                            estado <= VALIDAR_PRESION;
                        end
                    end

                    VALIDAR_PRESION: begin
                        if (cols != 4'b1111) begin
                            if (contador_debounce < DEBOUNCE_TIME) begin
                                contador_debounce <= contador_debounce + 4'd1;
                            end else begin
                                estado <= ESPERAR_LIBERACION;
                                nuevo_pulso_tecla <= 1'b1; // ¡Pulsación validada!

                                case ({fila_actual, cols})
                                    6'b00_1110: tecla_detectada <= 4'd1;
                                    6'b00_1101: tecla_detectada <= 4'd2;
                                    6'b00_1011: tecla_detectada <= 4'd3;
                                    6'b00_0111: tecla_detectada <= 4'hA; // A

                                    6'b01_1110: tecla_detectada <= 4'd4;
                                    6'b01_1101: tecla_detectada <= 4'd5;
                                    6'b01_1011: tecla_detectada <= 4'd6;
                                    6'b01_0111: tecla_detectada <= 4'hB; // B

                                    6'b10_1110: tecla_detectada <= 4'd7;
                                    6'b10_1101: tecla_detectada <= 4'd8;
                                    6'b10_1011: tecla_detectada <= 4'd9;
                                    6'b10_0111: tecla_detectada <= 4'hC; // C

                                    6'b11_1110: tecla_detectada <= 4'hE; // *
                                    6'b11_1101: tecla_detectada <= 4'd0; // 0
                                    6'b11_1011: tecla_detectada <= 4'hF; // #
                                    6'b11_0111: tecla_detectada <= 4'hD; // D
                                    default: tecla_detectada <= tecla_detectada;
                                endcase
                            end
                        end else begin
                            estado <= ESCANEO;
                        end
                    end

                    ESPERAR_LIBERACION: begin
                        if (cols == 4'b1111) begin
                            contador_debounce <= 4'd0;
                            estado <= VALIDAR_LIBERACION;
                        end
                    end

                    VALIDAR_LIBERACION: begin
                        if (cols == 4'b1111) begin
                            if (contador_debounce < DEBOUNCE_TIME) begin
                                contador_debounce <= contador_debounce + 4'd1;
                            end else begin
                                estado <= ESCANEO;
                            end
                        end else begin
                            estado <= ESPERAR_LIBERACION;
                        end
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // 3. EMULADOR DE SWITCHES Y BOTÓN DE GUARDADO SEGURO SÍNCRONO
    // =========================================================================
    reg [3:0] digito_dec;
    reg [3:0] digito_uni;
    reg guardar_activo;

    always @(posedge clk_50Mhz or posedge rst) begin
        if (rst) begin
            sw_selector         <= 1'b0;
            digito_dec          <= 4'd0;
            digito_uni          <= 4'd0;
            sw_datos            <= 7'd0;
            guardar_activo      <= 1'b0;
            btn_guardar_emulado <= 1'b1;
        end else begin
            // Si la FSM regresa a buscar teclas (ESCANEO), significa que soltaste la tecla.
            // Por lo tanto, liberamos inmediatamente el pulso de guardado.
            if (estado == ESCANEO) begin
                guardar_activo <= 1'b0;
            end

            if (nuevo_pulso_tecla) begin
                if (tecla_detectada == 4'hE) begin       // Tecla '*' (Cambia Horas/Minutos)
                    sw_selector <= ~sw_selector;
                    digito_dec  <= 4'd0;
                    digito_uni  <= 4'd0;
                    sw_datos    <= 7'd0;
                end else if (tecla_detectada == 4'hF) begin // Tecla '#' (Guardar Alarma)
                    guardar_activo <= 1'b1; // Se enclava hasta que la FSM detecte la liberación
                end else if (tecla_detectada <= 4'd9) begin // Entradas numéricas (0-9)
                    digito_dec <= digito_uni;
                    digito_uni <= tecla_detectada;
                    // Conversión segura desplazando unidades a decenas mediante lógica de registros anteriores
                    sw_datos   <= ( {3'b000, digito_uni} * 7'd10 ) + {3'b000, tecla_detectada};
                end
            end

            // Asignación de salida controlada (Activo en BAJO, imita perfectamente el push-button físico)
            btn_guardar_emulado <= ~guardar_activo;
        end
    end

endmodule