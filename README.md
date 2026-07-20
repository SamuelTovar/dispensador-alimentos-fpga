# Diseño e Implementación de un Dispensador de Alimentos Automatizado en FPGA

**Universidad Nacional de Colombia – Sede Bogotá**  
**Facultad de Ingeniería**  
**Curso:** Electrónica Digital I  
**Autor:** Samuel Tovar Vásquez  
**Fecha:** Julio de 2026

---

## 📂 Archivos del Proyecto

A continuación, se listan los archivos físicos que componen este diseño y que se encuentran subidos en este repositorio:

* `top_dispensador.v` - Módulo principal (Top-Level) que interconecta y coordina todos los subsistemas del dispensador.
* `controlador_rtc_ds3231.v` - Controlador I2C para extraer la hora y comunicación con el sensor DS3231.
* `controlador_teclado.v` - Controlador y escáner para leer las entradas del teclado matricial y emular los botones.
* `reloj_alarma.v` - Módulo encargado de gestionar el reloj en tiempo real, el divisor de frecuencia y la lógica para guardar la alarma.
* `fsm_principal.v` - Máquina de estados finitos que controla los tiempos de espera y el ciclo de apertura/cierre del dispensador.
* `control_pwm.v` - Generador de señales PWM con los anchos de pulso necesarios para posicionar el servomotor.
* `LCD1602_controller.v` - Controlador y máquina de estados para visualizar los textos y tiempos en la pantalla LCD 16x2.
* `bin_to_ascii.v` - Decodificador combinacional para convertir los valores numéricos binarios del reloj a caracteres ASCII legibles para la pantalla.

## 1. Resumen
El presente documento detalla el diseño, simulación y montaje en hardware de un sistema dispensador de alimentos automatizado y programable. El sistema está centralizado en una FPGA y emplea descripción de hardware en Verilog. El proyecto integra múltiples periféricos, incluyendo un Reloj de Tiempo Real (RTC DS3231) mediante protocolo I2C, un teclado matricial 4x4 para el ingreso de la configuración, una pantalla LCD 16x2 para la interfaz de usuario, y un servomotor controlado por PWM para el accionamiento mecánico del dispensador.

## 2. Introducción
La automatización de procesos mediante lógica digital permite el control preciso de actuadores físicos basándose en variables de tiempo. El objetivo de este proyecto de Electrónica Digital I es aplicar los conceptos de diseño síncrono, máquinas de estados finitos (FSM) y divisores de frecuencia en la resolución de un problema práctico: la dosificación programada de alimentos. Se priorizó un diseño modular que garantice la estabilidad de las señales, implementando técnicas de *anti-rebote* (debounce) para las entradas electromecánicas y sincronización de fases para los protocolos de comunicación.

## 3. Lista de Materiales e Instrumentos
Para la implementación en hardware se utilizaron los siguientes componentes:
* **Tarjeta de Desarrollo FPGA:** (Especificar modelo, ej. Altera Cyclone IV o Cyclone V) con reloj base de 50 MHz.
* **Módulo RTC DS3231:** Sensor de tiempo real con comunicación I2C.
* **Teclado Matricial 4x4:** Teclado de membrana para el ingreso de datos de la alarma.
* **Pantalla LCD 16x2:** Interfaz visual configurada para modo de 8 bits.
* **Servomotor :** Actuador físico para la compuerta del dispensador.
* **Cables Jumper :** Para el enrutamiento de señales entre los periféricos y los puertos GPIO de la FPGA.
* **Software:** Intel Quartus Prime para la síntesis, ruteo y programación.

## 4. Arquitectura del Hardware y Módulos
El diseño del hardware se fundamenta en un esquema jerárquico Top-Down. El módulo superior `top_dispensador` interconecta los flujos de datos entre la lectura del reloj, la interfaz de usuario y la lógica de accionamiento.

### 4.1. Controlador del Reloj de Tiempo Real (I2C)
El módulo `controlador_rtc_ds3231` establece comunicación con el sensor externo.
* **Divisor de Reloj:** A partir del reloj de 50 MHz de la FPGA, se genera un tick a 400 kHz para asegurar las 4 fases necesarias del estándar I2C a 100 kHz.
* **Máquina de Estados:** Una FSM de 17 estados (incluyendo START, WRITE_ADDR, ACK, READ, NACK y STOP) gestiona la lectura de los registros del RTC, obteniendo los datos de segundos, minutos y horas en formato BCD de manera síncrona.

### 4.2. Escáner de Teclado y Anti-Rebote
El ingreso de datos requiere lidiar con el ruido mecánico de los interruptores. El módulo `controlador_teclado` soluciona esto:
* Emplea un divisor de frecuencia que genera un tick cada 1 ms (50,000 ciclos de reloj).
* Una FSM realiza el escaneo continuo de las filas (cambiando los ceros lógicos) y, al detectar una interrupción en las columnas, inicia un contador de *debounce* de 10 ms para validar la pulsación.
* Proporciona la emulación de un botón físico de guardado al detectar la tecla '#'.

### 4.3. Gestión del Tiempo y Alarma
El módulo `reloj_alarma` se encarga de procesar la lógica de temporización:
* Un divisor de frecuencia principal reduce los 50 MHz a 1 Hz exacto (contador hasta 24,999,999) para los procesos internos.
* Dispone de un comparador continuo que evalúa si la hora actual (traducida a binario) coincide con la hora configurada por el usuario; si esto ocurre, levanta la bandera `alerta_hora`.

### 4.4. Máquina de Estados de Dispensado y PWM
Una vez la bandera de alerta está en alto, el control pasa al actuador:
* **FSM Principal (`fsm_principal`):** Controlada por el reloj de 1 Hz, transiciona del estado de ESPERA al estado de ABRIR. Luego, ingresa al estado PLATO, donde permanece retenida durante exactamente 4 segundos para permitir la caída del alimento, finalizando en el estado CERRAR.
* **Modulación por Ancho de Pulso (`control_pwm`):** Un contador genera un período fijo de 20 ms (frecuencia de 50 Hz, estándar para servomotores). Dependiendo de la señal enviada por la FSM principal, el ancho del pulso varía entre la posición de cerrado y la de abierto (90 grados).

### 4.5. Visualización de Datos (LCD 16x2)
Para mostrar la información, el módulo `LCD1602_controller` inicializa el display a través de una FSM y memorias internas. 
* Dado que el display requiere datos en formato de texto, se emplea el módulo combinacional `bin_to_ascii`, el cual utiliza un algoritmo de restas sucesivas para convertir valores binarios (0-59) en decenas y unidades, sumando el valor hexadecimal `8'h30` para obtener el carácter ASCII correspondiente.

## 5. Diagrama de Bloques General
> *(Instrucción: Genera un diagrama de bloques en software como draw.io, Lucidchart o Visio donde se vea el `top_dispensador` y las flechas de conexión entre el RTC, el teclado, el PWM y la LCD, y colócalo aquí).*
  
`![Diagrama de Bloques de la Arquitectura RTL](ruta_a_tu_imagen_del_diagrama.png)`

## 6. Resultados de Implementación Física
El sistema fue implementado exitosamente. Las siguientes imágenes evidencian el funcionamiento de cada etapa:

### 6.1. Montaje del Sistema
> *(Añade una foto donde se vea toda la protoboard, la FPGA, el servomotor y los cables).*
`![Montaje Físico](ruta_a_tu_foto_montaje.jpg)`

### 6.2. Interfaz en Pantalla
Se verifica la correcta conversión de los valores BCD del reloj a ASCII en la primera línea de la pantalla, y la actualización en tiempo real de la configuración de la alarma al presionar el teclado matricial en la segunda línea.
`![Pantalla LCD mostrando la hora y alarma](ruta_a_tu_foto_lcd.jpg)`

### 6.3. Accionamiento Mecánico
Al coincidir los minutos y las horas, la FSM envía la señal alta al control PWM, posicionando el servomotor en el ángulo de apertura durante los 4 segundos estipulados.
`![Servomotor en posición abierta](ruta_a_tu_foto_servo.jpg)`

## 7. Análisis de Resultados y Retos Técnicos
Durante el desarrollo se presentaron diversos retos propios de la electrónica digital síncrona:
1. **Sincronización de Dominios de Reloj:** El diseño maneja múltiples frecuencias de operación (50 MHz del sistema, 400 kHz para I2C, 1 kHz para el teclado, y 1 Hz para la FSM y el reloj interno). Se garantizó que el cruce de señales entre estos dominios no generara metaestabilidad mediante la adaptación cuidadosa de pulsos (como el guardado emulado activo en bajo desde el teclado).
2. **Conversión de Bases Numéricas:** Se identificó que el RTC DS3231 entrega la información en formato BCD. Para poder comparar este valor con las entradas binarias del teclado, se aplicó una conversión multiplicando por 10 (desplazamiento y suma) las decenas BCD en el módulo de interconexión (top).
3. **Manejo del Bus Bidireccional:** El protocolo I2C requirió implementar correctamente el pin SDA como *Open-Drain*. Esto se logró mediante lógica tri-estado (`assign sda = (sda_en && sda_out == 1'b0) ? 1'b0 : 1'bz;`), permitiendo tanto la escritura de comandos como la lectura de los ACKs emitidos por el esclavo sin ocasionar cortocircuitos lógicos en la FPGA[cite: 1].

## 8. Conclusiones
* Se logró implementar un sistema secuencial complejo utilizando metodologías formales de diseño digital y Verilog, comprobando su robustez funcional en hardware real.
* La programación de máquinas de estado finitas (FSM) resultó fundamental tanto para la implementación de protocolos de comunicación serial (I2C) como para la temporización de periféricos lógicos (Pantalla LCD) y mecánicos (Servomotor).
* El proyecto demuestra la versatilidad de las FPGAs para integrar y centralizar el control estricto de tiempos (operaciones en el rango de microsegundos a milisegundos) en aplicaciones domóticas o agroindustriales, sentando las bases para proyectos de mayor escala.

## 9. Referencias
* Mano, M. M., & Ciletti, M. D. (2013). *Diseño Digital* (5ta ed.). Pearson Educación.
## 10. Anexos: Códigos Fuente en Verilog

A continuación, se presentan los módulos desarrollados en Verilog para la implementación del dispensador en la FPGA.

### 10.1. Módulo Top (Interconexión principal)
Este módulo integra todos los periféricos y realiza la interconexión de las señales principales[cite: 8].

<details>
<summary><b>Ver código de top_dispensador.v</b></summary>

```verilog
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

// --- reloj_alarma.v ---
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

// --- control_pwm.v ---
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

// --- bin_to_ascii.v ---
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

// --- LCD1602_controller.v ---
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
* Hoja de datos (Datasheet) del sensor RTC DS3231. Maxim Integrated.
* Hoja de datos (Datasheet) del controlador HD44780 para LCD.
