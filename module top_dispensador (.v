module top_dispensador (
    input clk_50Mhz,            
    input rst_n,                
    
    // Conexiones físicas del Teclado Matricial
    input [3:0] key_cols,       // Columnas físicas (Conectadas a pines de la FPGA con pull-up)
    output [3:0] key_rows,      // Filas físicas
    
    output rtc_scl,             
    inout rtc_sda,              
    
    output pin_servo,           
    output lcd_rs,              
    output lcd_rw,              
    output lcd_e,               
    output [7:0] lcd_data       
);

    // Adaptación de Resets
    wire rst_para_logica = !rst_n; 
    wire rst_para_lcd    = rst_n;  

    // Cables virtuales que interconectan el teclado con tu lógica de reloj original
    wire [6:0] sw_pins_datos;
    wire sw_pin_selector;
    wire btn_save_emulado; // Reemplaza al botón físico btn_save_n

    // ==========================================
    // INSTANCIACIÓN DEL NUEVO CONTROLADOR DE TECLADO
    // ==========================================
    controlador_teclado modulo_teclado (
        .clk_50Mhz(clk_50Mhz),
        .rst(rst_para_logica),
        .cols(key_cols),
        .rows(key_rows),
        .sw_datos(sw_pins_datos),
        .sw_selector(sw_pin_selector),
        .btn_guardar_emulado(btn_save_emulado) // Aquí se genera el flanco de bajada al presionar '#'
    );

    // ==========================================
    // 1. INSTANCIACIÓN DEL SENSOR DE RELOJ RTC (Módulo I2C)
    // ==========================================
    wire [7:0] rtc_segundos_bcd;
    wire [7:0] rtc_minutos_bcd;
    wire [7:0] rtc_horas_bcd;

    controlador_rtc_ds3231 modulo_sensor_rtc (
        .clk_50Mhz(clk_50Mhz),
        .rst(rst_para_logica),   
        .scl(rtc_scl),
        .sda(rtc_sda),
        .segundos(rtc_segundos_bcd),
        .minutos(rtc_minutos_bcd),
        .horas(rtc_horas_bcd)
    );

    // ==========================================
    // 2. INSTANCIACIÓN DE TU RELOJ Y ALARMA ORIGINAL
    // ==========================================
    wire [4:0] reloj_interno_hrs;
    wire [5:0] reloj_interno_mins;
    wire [4:0] alrm_hrs;
    wire [5:0] alrm_mins;
    wire [4:0] cfg_hrs;
    wire [5:0] cfg_mins;
    wire clk_1hz;
    wire alerta_hora_interna;

    reloj_alarma modulo_reloj (
        .clk_fpga(clk_50Mhz),
        .rst(rst_para_logica),
        .btn_guardar(btn_save_emulado), // Conectamos el botón emulado desde el teclado (#)
        .sw_datos(sw_pins_datos),       
        .sw_selector(sw_pin_selector),   
        .curr_hrs(reloj_interno_hrs),   
        .curr_mins(reloj_interno_mins), 
        .alrm_hrs(alrm_hrs),
        .alrm_mins(alrm_mins),
        .cfg_hrs(cfg_hrs),
        .cfg_mins(cfg_mins),
        .clk_1hz(clk_1hz),
        .alerta_hora(alerta_hora_interna) 
    );

    // ==========================================
    // CONVERSIÓN DE BCD (DEL RTC) A BINARIO (Para la comparación)
    // ==========================================
    wire [4:0] rtc_horas_bin   = (rtc_horas_bcd[7:4] * 4'd10) + rtc_horas_bcd[3:0];
    wire [5:0] rtc_minutos_bin = (rtc_minutos_bcd[7:4] * 4'd10) + rtc_minutos_bcd[3:0];

    wire alerta_hora_real = ((rtc_horas_bin == alrm_hrs) && (rtc_minutos_bin == alrm_mins)) ? 1'b1 : 1'b0;

    // ==========================================
    // 3. INSTANCIACIÓN DE TU FSM PRINCIPAL ORIGINAL
    // ==========================================
    wire servo_pos;

    fsm_principal modulo_fsm (
        .clk_1hz(clk_1hz),
        .rst(rst_para_logica),
        .alerta_hora(alerta_hora_real), 
        .servo_pos(servo_pos)
    );

    // ==========================================
    // 4. INSTANCIACIÓN DE TU CONTROL PWM ORIGINAL
    // ==========================================
    control_pwm modulo_pwm (
        .clk_fpga(clk_50Mhz),
        .rst(rst_para_logica),
        .servo_pos(servo_pos),
        .pwm_out(pin_servo)
    );

    // ==========================================
    // 5. CONVERSIÓN A ASCII USANDO TUS MÓDULOS BIN_TO_ASCII
    // ==========================================
    wire [7:0] ascii_ch_t = {4'h3, rtc_horas_bcd[7:4]};    
    wire [7:0] ascii_ch_u = {4'h3, rtc_horas_bcd[3:0]};    
    wire [7:0] ascii_cm_t = {4'h3, rtc_minutos_bcd[7:4]};  
    wire [7:0] ascii_cm_u = {4'h3, rtc_minutos_bcd[3:0]};  

    wire [7:0] ascii_ah_t, ascii_ah_u;
    wire [7:0] ascii_am_t, ascii_am_u;

    bin_to_ascii dec_alrm_hrs (
        .bin_val({1'b0, cfg_hrs}), 
        .ascii_dec(ascii_ah_t), 
        .ascii_uni(ascii_ah_u)
    );
    
    bin_to_ascii dec_alrm_mins (
        .bin_val(cfg_mins), 
        .ascii_dec(ascii_am_t), 
        .ascii_uni(ascii_am_u)
    );

    // ==========================================
    // 6. INSTANCIACIÓN DE TU CONTROLADOR LCD ORIGINAL
    // ==========================================
    LCD1602_controller #(
        .NUM_COMMANDS(4),
        .NUM_DATA_ALL(32),
        .NUM_DATA_PERLINE(16),
        .DATA_BITS(8),
        .COUNT_MAX(2000000) 
    ) modulo_lcd (
        .clk(clk_50Mhz),
        .reset(rst_para_lcd),        
        .ready_i(1'b1),        
        
        .c_hrs_t(ascii_ch_t), .c_hrs_u(ascii_ch_u),
        .c_min_t(ascii_cm_t), .c_min_u(ascii_cm_u),
        .a_hrs_t(ascii_ah_t), .a_hrs_u(ascii_ah_u),
        .a_min_t(ascii_am_t), .a_min_u(ascii_am_u),
        
        .rs(lcd_rs),
        .rw(lcd_rw),
        .enable(lcd_e),
        .data(lcd_data)
    );

endmodule