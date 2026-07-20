# Diseño e Implementación de un Dispensador de Alimentos Automatizado en FPGA

**Universidad Nacional de Colombia – Sede Bogotá**  
**Facultad de Ingeniería**  
**Curso:** Electrónica Digital I  
**Autor:** Samuel Tovar Vásquez  
**Fecha:** Julio de 2026

---

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
* **Servomotor (ej. SG90 o MG995):** Actuador físico para la compuerta del dispensador.
* **Cables Jumper y Protoboard:** Para el enrutamiento de señales entre los periféricos y los puertos GPIO de la FPGA.
* **Software:** Intel Quartus Prime para la síntesis, ruteo y programación.

## 4. Arquitectura del Hardware y Módulos
El diseño del hardware se fundamenta en un esquema jerárquico Top-Down. El módulo superior `top_dispensador` interconecta los flujos de datos entre la lectura del reloj, la interfaz de usuario y la lógica de accionamiento[cite: 8].

### 4.1. Controlador del Reloj de Tiempo Real (I2C)
El módulo `controlador_rtc_ds3231` establece comunicación con el sensor externo[cite: 1].
* **Divisor de Reloj:** A partir del reloj de 50 MHz de la FPGA, se genera un tick a 400 kHz para asegurar las 4 fases necesarias del estándar I2C a 100 kHz[cite: 1].
* **Máquina de Estados:** Una FSM de 17 estados (incluyendo START, WRITE_ADDR, ACK, READ, NACK y STOP) gestiona la lectura de los registros del RTC, obteniendo los datos de segundos, minutos y horas en formato BCD de manera síncrona[cite: 1].

### 4.2. Escáner de Teclado y Anti-Rebote
El ingreso de datos requiere lidiar con el ruido mecánico de los interruptores. El módulo `controlador_teclado` soluciona esto[cite: 2]:
* Emplea un divisor de frecuencia que genera un tick cada 1 ms (50,000 ciclos de reloj)[cite: 2].
* Una FSM realiza el escaneo continuo de las filas (cambiando los ceros lógicos) y, al detectar una interrupción en las columnas, inicia un contador de *debounce* de 10 ms para validar la pulsación[cite: 2].
* Proporciona la emulación de un botón físico de guardado al detectar la tecla '#'[cite: 2].

### 4.3. Gestión del Tiempo y Alarma
El módulo `reloj_alarma` se encarga de procesar la lógica de temporización[cite: 7]:
* Un divisor de frecuencia principal reduce los 50 MHz a 1 Hz exacto (contador hasta 24,999,999) para los procesos internos[cite: 7].
* Dispone de un comparador continuo que evalúa si la hora actual (traducida a binario) coincide con la hora configurada por el usuario; si esto ocurre, levanta la bandera `alerta_hora`[cite: 7].

### 4.4. Máquina de Estados de Dispensado y PWM
Una vez la bandera de alerta está en alto, el control pasa al actuador:
* **FSM Principal (`fsm_principal`):** Controlada por el reloj de 1 Hz, transiciona del estado de ESPERA al estado de ABRIR. Luego, ingresa al estado PLATO, donde permanece retenida durante exactamente 4 segundos para permitir la caída del alimento, finalizando en el estado CERRAR[cite: 5].
* **Modulación por Ancho de Pulso (`control_pwm`):** Un contador genera un período fijo de 20 ms (frecuencia de 50 Hz, estándar para servomotores). Dependiendo de la señal enviada por la FSM principal, el ancho del pulso varía entre la posición de cerrado y la de abierto (90 grados)[cite: 4].

### 4.5. Visualización de Datos (LCD 16x2)
Para mostrar la información, el módulo `LCD1602_controller` inicializa el display a través de una FSM y memorias internas[cite: 6]. 
* Dado que el display requiere datos en formato de texto, se emplea el módulo combinacional `bin_to_ascii`, el cual utiliza un algoritmo de restas sucesivas para convertir valores binarios (0-59) en decenas y unidades, sumando el valor hexadecimal `8'h30` para obtener el carácter ASCII correspondiente[cite: 3].

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
* Hoja de datos (Datasheet) del sensor RTC DS3231. Maxim Integrated.
* Hoja de datos (Datasheet) del controlador HD44780 para LCD.
