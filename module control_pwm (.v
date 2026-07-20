module control_pwm (
    input clk_fpga,     
    input rst,          
    input servo_pos,    
    output reg pwm_out  
);
    localparam PERIODO_20MS   = 20'd1000000; 
    localparam PULSO_CERRADO  = 20'd50000;   
    localparam PULSO_ABIERTO  = 20'd100000;  

    reg [19:0] cuenta_tiempo;
    reg [19:0] ancho_pulso;

    always @(*) begin
        if (servo_pos == 1'b1) ancho_pulso = PULSO_ABIERTO;
        else ancho_pulso = PULSO_CERRADO;
    end

    always @(posedge clk_fpga or posedge rst) begin
        if (rst) begin
            cuenta_tiempo <= 0;
            pwm_out       <= 1'b0;
        end else begin
            if (cuenta_tiempo >= PERIODO_20MS - 1) cuenta_tiempo <= 0;
            else cuenta_tiempo <= cuenta_tiempo + 1;

            if (cuenta_tiempo < ancho_pulso) pwm_out <= 1'b1;
            else pwm_out <= 1'b0;
        end
    end
endmodule