module bin_to_ascii (
    input [5:0] bin_val,       // Valor en binario (0 a 59)
    output [7:0] ascii_dec,    // Carácter ASCII de las Decenas
    output [7:0] ascii_uni     // Carácter ASCII de las Unidades
);

    reg [3:0] dec;
    reg [3:0] uni;

    // Lógica combinacional por restas sucesivas
    always @(*) begin
        dec = 4'd0;
        uni = 4'd0;

        if (bin_val >= 50) begin 
            dec = 4'd5; 
            uni = bin_val - 6'd50; 
        end else if (bin_val >= 40) begin 
            dec = 4'd4; 
            uni = bin_val - 6'd40; 
        end else if (bin_val >= 30) begin 
            dec = 4'd3; 
            uni = bin_val - 6'd30; 
        end else if (bin_val >= 20) begin 
            dec = 4'd2; 
            uni = bin_val - 6'd20; 
        end else if (bin_val >= 10) begin 
            dec = 4'd1; 
            uni = bin_val - 6'd10; 
        end else begin 
            dec = 4'd0; 
            uni = bin_val[3:0]; 
        end
    end

    // Conversión final sumando el cero (8'h30) de la tabla ASCII
    assign ascii_dec = 8'h30 + dec;
    assign ascii_uni = 8'h30 + uni;

endmodule