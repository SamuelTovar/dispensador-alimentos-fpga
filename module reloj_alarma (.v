module reloj_alarma (
    input clk_fpga,             // Reloj maestro de la FPGA (50 MHz)
    input rst,                  // Reset general (Activo en ALTO interno)
    input btn_guardar,          // Botón físico para guardar la alarma permanente
    input [6:0] sw_datos,       // 7 Switches para ingresar el valor numérico
    input sw_selector,          // 1 Switch para elegir: 0 = Minutos, 1 = Horas
    output reg [4:0] curr_hrs,  // Hora actual del reloj
    output reg [5:0] curr_mins, // Minutos actuales del reloj
    output reg [4:0] alrm_hrs,  // Alarma final memorizada (Horas)
    output reg [5:0] alrm_mins, // Alarma final memorizada (Minutos)
    output reg [4:0] cfg_hrs,   // Horas que se muestran en la LCD al mover switches
    output reg [5:0] cfg_mins,  // Minutos que se muestran en la LCD al mover switches
    output reg clk_1hz,         // Reloj de 1 Hz
    output reg alerta_hora      // Bandera hacia la FSM principal
);

    // 1. Divisor de Frecuencia (50 MHz a 1 Hz)
    reg [25:0] contador_1hz;
    always @(posedge clk_fpga or posedge rst) begin
        if (rst) begin
            contador_1hz <= 0;
            clk_1hz      <= 0;
        end else if (contador_1hz == 26'd24999999) begin
            contador_1hz <= 0;
            clk_1hz      <= ~clk_1hz;
        end else begin
            contador_1hz <= contador_1hz + 1;
        end
    end

    // 2. Contador de Tiempo Real (Reloj que arranca a las 17:50 por defecto)
    reg [5:0] curr_secs;
    always @(posedge clk_1hz or posedge rst) begin
        if (rst) begin
            curr_secs <= 0; 
            curr_mins <= 6'd50;  
            curr_hrs  <= 5'd17;  
        end else begin
            if (curr_secs == 59) begin
                curr_secs <= 0;
                if (curr_mins == 59) begin
                    curr_mins <= 0;
                    if (curr_hrs == 23) curr_hrs <= 0;
                    else curr_hrs <= curr_hrs + 1;
                end else begin
                    curr_mins <= curr_mins + 1;
                end
            end else begin
                curr_secs <= curr_secs + 1;
            end
        end
    end

    // 3. Lógica de Pre-visualización en la Pantalla LCD 
    always @(*) begin
        if (sw_selector == 1'b1) begin
            cfg_hrs  = sw_datos[4:0]; // Muestra en tiempo real lo que mueves en los switches
            cfg_mins = alrm_mins;     // Muestra lo que ya guardaste previamente en minutos
        end else begin
            cfg_hrs  = alrm_hrs;      // Muestra lo que ya guardaste previamente en horas
            cfg_mins = sw_datos[5:0]; // Muestra en tiempo real lo que mueves en los switches
        end
    end

    // 4. Guardado independiente por flanco de bajada del botón (negedge)
    always @(negedge btn_guardar or posedge rst) begin
        if (rst) begin
            alrm_hrs  <= 5'd0;
            alrm_mins <= 6'd0;
        end else begin
            if (sw_selector == 1'b1) begin
                alrm_hrs  <= sw_datos[4:0]; // Guarda solo las horas
            end else begin
                alrm_mins <= sw_datos[5:0]; // Guarda solo los minutos
            end
        end
    end

    // 5. Comparador Continuo (Encendido durante TODO el minuto coincidente)
    always @(*) begin
        if ((curr_hrs == alrm_hrs) && (curr_mins == alrm_mins))
            alerta_hora = 1'b1;
        else
            alerta_hora = 1'b0;
    end

endmodule