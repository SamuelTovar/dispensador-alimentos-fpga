module fsm_principal (
    input clk_1hz,           // Reloj lento de 1 Hz para contar los segundos de apertura
    input rst,               // Reset general (Activo en ALTO)
    input alerta_hora,       // Viene del comparador del reloj
    output reg servo_pos     // 0 = Cerrado (0 grados), 1 = Abierto (90 grados)
);

    // Definición de Estados de la Máquina de Estados (FSM)
    reg [1:0] state, next_state;
    localparam STATE_ESPERA = 2'b00,
               STATE_ABRIR  = 2'b01,
               STATE_PLATO  = 2'b10,
               STATE_CERRAR = 2'b11;

    reg [3:0] timer; // Contador interno para controlar los segundos que dura abierto

    // Transición de estados síncrona
    always @(posedge clk_1hz or posedge rst) begin
        if (rst) begin
            state <= STATE_ESPERA;
            timer <= 0;
        end else begin
            state <= next_state;
            if (state == STATE_PLATO)
                timer <= timer + 1;
            else
                timer <= 0;
        end
    end

    // Lógica combinacional de los estados
    always @(*) begin
        next_state = state;
        servo_pos  = 1'b0; // Por defecto el motor está cerrado

        case (state)
            STATE_ESPERA: begin
                servo_pos = 1'b0;
                if (alerta_hora) 
                    next_state = STATE_ABRIR;
            end
            
            STATE_ABRIR: begin
                servo_pos = 1'b1; // Mueve el servo a posición abierto
                next_state = STATE_PLATO;
            end
            
            STATE_PLATO: begin
                servo_pos = 1'b1; // Se queda abierto dejando caer la comida
                if (timer >= 4)   // Espera 4 segundos en esta posición
                    next_state = STATE_CERRAR;
            end
            
            STATE_CERRAR: begin
                servo_pos = 1'b0; // Regresa el servo a la posición original
                if (!alerta_hora) // Espera que termine el minuto para no repetir el ciclo
                    next_state = STATE_ESPERA;
            end
            
            default: next_state = STATE_ESPERA;
        endcase
    end

endmodule