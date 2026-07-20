# Diseño e Implementación de un Dispensador de Alimentos Automatizado basado en FPGA

**Autor:** Samuel Tovar Vásquez  
**Institución:** Universidad Nacional de Colombia – Sede Bogotá  
**Curso:** Electrónica Digital I  

## 1. Introducción
Este proyecto documenta el diseño, simulación e implementación en hardware de un dispensador de alimentos automatizado. El sistema centralizado en una FPGA permite al usuario configurar una alarma mediante un teclado matricial para accionar un servomotor en una hora específica, visualizando la información en tiempo real a través de una pantalla LCD.

## 2. Arquitectura del Sistema
El hardware fue descrito en Verilog utilizando una arquitectura modular, donde el módulo `top_dispensador` se encarga de interconectar todos los periféricos y la lógica de control[cite: 8]. El sistema se divide en los siguientes bloques funcionales:

* **Controlador de Tiempo Real (RTC):** Se implementó un módulo I2C (`controlador_rtc_ds3231`) con un generador de ticks a 400 kHz y una máquina de estados para leer los segundos, minutos y horas directamente de un sensor físico DS3231[cite: 1].
* **Interfaz de Usuario (Teclado):** El módulo `controlador_teclado` incluye un escáner con lógica anti-rebote (debounce de 10 ms) que emula switches y pulsadores a partir de las entradas de un teclado matricial[cite: 2].
* **Control de Actuador (PWM y FSM):** El movimiento del dispensador se controla mediante una Máquina de Estados Finitos (`fsm_principal`) que, al recibir la alerta de tiempo, transiciona entre estados de espera, apertura, retención para dejar caer la comida (durante 4 segundos) y cierre[cite: 5]. El actuador es un servomotor controlado por el módulo `control_pwm`, el cual genera pulsos de 20 ms[cite: 4].
* **Gestión de Alarmas:** El módulo `reloj_alarma` compara continuamente la hora actual con la hora guardada por el usuario, activando una bandera de alerta cuando los minutos y horas coinciden exactamente[cite: 7].
* **Visualización (LCD):** Los datos en formato binario son convertidos mediante el módulo `bin_to_ascii` utilizando lógica de restas sucesivas[cite: 3]. Esta información es enviada a un controlador `LCD1602_controller` que inicializa la pantalla de 16x2 y muestra texto estático junto con la hora actual y la hora de la alarma[cite: 6].

## 3. Resultados Físicos e Implementación
El diseño fue sintetizado y descargado en la placa FPGA. A continuación se evidencian los resultados del montaje:

> *(Nota: Sube tus fotos al repositorio y reemplaza las URLs de abajo con los enlaces de tus imágenes)*

* **Montaje General:** 
  `![Montaje General del Proyecto](ruta/a/tu/foto_montaje.jpg)`
* **Visualización en LCD:** 
  `![Datos en la pantalla LCD](ruta/a/tu/foto_lcd.jpg)`
* **Mecanismo de Dispensado (Servomotor):** 
  `![Servomotor accionado](ruta/a/tu/foto_servo.jpg)`

## 4. Conclusiones
* Se logró integrar exitosamente un protocolo de comunicación I2C desde cero para interactuar con hardware externo (RTC) en tiempo real.
* La máquina de estados principal demostró ser robusta para manejar los tiempos de apertura del servomotor sin bloquear la actualización visual de la pantalla.
