module LCD1602_controller #(
    parameter NUM_COMMANDS = 4, 
              NUM_DATA_ALL = 32,  
              NUM_DATA_PERLINE = 16,
              DATA_BITS = 8,
              COUNT_MAX = 800000
)(
    input clk,            
    input reset,          
    input ready_i,   
    
    input [7:0] c_hrs_t, input [7:0] c_hrs_u,
    input [7:0] c_min_t, input [7:0] c_min_u,
    input [7:0] a_hrs_t, input [7:0] a_hrs_u,
    input [7:0] a_min_t, input [7:0] a_min_u,
    
    output reg rs,        
    output reg rw,        
    output enable,    
    output reg [DATA_BITS-1:0] data
);

    localparam IDLE = 3'b000;
    localparam CONFIG_CMD1 = 3'b001;
    localparam WR_STATIC_TEXT_1L = 3'b010;
    localparam CONFIG_CMD2 = 3'b011;
    localparam WR_STATIC_TEXT_2L = 3'b100;

    reg [2:0] fsm_state; reg [2:0] next_state; reg clk_16ms;
    localparam CLEAR_DISPLAY = 8'h01;
    localparam SHIFT_CURSOR_RIGHT = 8'h06;
    localparam DISPON_CURSOROFF = 8'h0C;
    localparam LINES2_MATRIX5x8_MODE8bit = 8'h38;
    localparam START_2LINE = 8'hC0;

    reg [$clog2(COUNT_MAX)-1:0] clk_counter;
    reg [$clog2(NUM_COMMANDS):0] command_counter;
    reg [$clog2(NUM_DATA_PERLINE):0] data_counter;

    reg [DATA_BITS-1:0] static_data_mem [0: NUM_DATA_ALL-1];
    reg [DATA_BITS-1:0] config_mem [0:NUM_COMMANDS-1]; 

    always @(posedge clk) begin
        static_data_mem[0]  <= "H"; static_data_mem[1]  <= "O"; static_data_mem[2]  <= "R"; static_data_mem[3]  <= "A";
        static_data_mem[4]  <= ":"; static_data_mem[5]  <= c_hrs_t; static_data_mem[6]  <= c_hrs_u; static_data_mem[7]  <= ":";
        static_data_mem[8]  <= c_min_t; static_data_mem[9]  <= c_min_u; static_data_mem[10] <= " "; static_data_mem[11] <= " ";
        static_data_mem[12] <= " "; static_data_mem[13] <= " "; static_data_mem[14] <= " "; static_data_mem[15] <= " ";

        static_data_mem[16] <= "A"; static_data_mem[17] <= "L"; static_data_mem[18] <= "R"; static_data_mem[19] <= "M";
        static_data_mem[20] <= ":"; static_data_mem[21] <= a_hrs_t; static_data_mem[22] <= a_hrs_u; static_data_mem[23] <= ":";
        static_data_mem[24] <= a_min_t; static_data_mem[25] <= a_min_u; static_data_mem[26] <= " "; static_data_mem[27] <= " ";
        static_data_mem[28] <= " "; static_data_mem[29] <= " "; static_data_mem[30] <= " "; static_data_mem[31] <= " ";
    end

    initial begin
        fsm_state <= IDLE; command_counter <= 'b0; data_counter <= 'b0;
        rs <= 1'b0; rw <= 1'b0; data <= 8'b0; clk_16ms <= 1'b0; clk_counter <= 'b0;
        config_mem[0] <= LINES2_MATRIX5x8_MODE8bit; config_mem[1] <= SHIFT_CURSOR_RIGHT;
        config_mem[2] <= DISPON_CURSOROFF; config_mem[3] <= CLEAR_DISPLAY;
    end

    always @(posedge clk) begin
        if (clk_counter == COUNT_MAX-1) begin clk_16ms <= ~clk_16ms; clk_counter <= 'b0; end
        else clk_counter <= clk_counter + 1;
    end

    always @(posedge clk_16ms) begin
        if (reset == 0) fsm_state <= IDLE;
        else fsm_state <= next_state;
    end

    always @(*) begin
        case(fsm_state)
            IDLE: next_state = (ready_i) ? CONFIG_CMD1 : IDLE;
            CONFIG_CMD1: next_state = (command_counter == NUM_COMMANDS) ? WR_STATIC_TEXT_1L : CONFIG_CMD1;
            WR_STATIC_TEXT_1L: next_state = (data_counter == NUM_DATA_PERLINE) ? CONFIG_CMD2 : WR_STATIC_TEXT_1L;
            CONFIG_CMD2: next_state = WR_STATIC_TEXT_2L;
            WR_STATIC_TEXT_2L: next_state = (data_counter == NUM_DATA_PERLINE) ? IDLE : WR_STATIC_TEXT_2L;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk_16ms) begin
        if (reset == 0) begin
            command_counter <= 'b0; data_counter <= 'b0; data <= 'b0; rw <= 1'b0;
        end else begin
            rw <= 1'b0;
            case (next_state)
                IDLE: begin command_counter <= 'b0; data_counter <= 'b0; rs <= 1'b0; data <= 'b0; end
                CONFIG_CMD1: begin rs <= 1'b0; command_counter <= command_counter + 1; data <= config_mem[command_counter]; end
                WR_STATIC_TEXT_1L: begin data_counter <= data_counter + 1; rs <= 1'b1; data <= static_data_mem[data_counter]; end
                CONFIG_CMD2: begin data_counter <= 'b0; rs <= 1'b0; data <= START_2LINE; end
                WR_STATIC_TEXT_2L: begin data_counter <= data_counter + 1; rs <= 1'b1; data <= static_data_mem[NUM_DATA_PERLINE + data_counter]; end
            endcase
        end
    end

    assign enable = clk_16ms;
endmodule