# MicroFantasy · XIAO ESP32-C3 + AS5311

Medidor X para una máquina manual. No mueve motores. Firmware Arduino con
PlatformIO; el sensor sigue contando aunque el Wi-Fi esté desconectado.

## Conexiones

| XIAO ESP32-C3 | AS5311 |
| --- | --- |
| 3V3 | 18 VDD3V3 y 19 VDD5V |
| GND | 8 VSS y 9 PROG |
| D1 / GPIO3 | 4 A |
| D2 / GPIO4 | 5 B |
| D3 / GPIO5 | 12 DO |
| D4 / GPIO6 | 13 CLK |
| D5 / GPIO7 | 14 CSn |

100 nF entre alimentación y masa junto al sensor. Conectar la antena Wi-Fi del
XIAO. Usar una tira magnética de **1 mm por polo / 2 mm por par de polos**.
DO queda como entrada y CLK/CSn en LOW. Esta primera versión no lee SSI ni
programa OTP. PROG debe permanecer a masa.

## Compilar y grabar

Instala Python y PlatformIO (o la extensión PlatformIO de VS Code). Desde la raíz
del repositorio:

```powershell
python -m pip install platformio==6.2.0
python -m platformio run -d firmware/microfantasy-xiao -e xiao_esp32c3
python -m platformio device list
python -m platformio run -d firmware/microfantasy-xiao -e xiao_esp32c3 -t upload --upload-port COM5
python -m platformio device monitor --port COM5 --baud 115200
```

Reemplaza COM5 por tu puerto. Si no entra en modo descarga, mantén BOOT al
conectar USB, suéltalo y repite upload. Después pulsa RESET para ejecutar.
Nunca es necesario introducir SSID/contraseña en el código ni subirlos a Git.

En Windows usa una ruta corta para PlatformIO si el compilador informa
`CreateProcess: No such file or directory`: las listas de includes del SDK
pueden superar el límite de línea de comandos al instalarlo dentro de una ruta
muy larga. La ubicación predeterminada `C:\Users\tu_usuario\.platformio` sirve.

Dependencias fijadas: Espressif32 6.12.0 (Arduino ESP32 2.0.17),
arduinoWebSockets 2.7.1, ArduinoJson 7.4.2. No se usa OTA en esta primera versión.

## Primera conexión desde el celular

1. Abre Serial a 115200 y pulsa RESET. Aparecen la red `MicroFantasy-XXXXXX` y
   su **clave única**, generada aleatoriamente y conservada en NVS. Guarda esa
   clave en una etiqueta del dispositivo. No es la contraseña de tu casa.
   Si el mensaje inicial se perdió, mantén BOOT durante 3 segundos **después de
   arrancar** para mostrarla y reabrir la configuración.
2. Instala la nueva versión de MicroFantasy. En **Configuración → Máquina →
   Configurar Wi-Fi de la máquina**, abre los ajustes Wi-Fi y conéctate a esa red.
   Acepta permanecer conectado aunque Android avise que no hay Internet. En iOS,
   abre Ajustes → Wi-Fi manualmente y regresa a la app.
3. Toca **Ya estoy conectado: comprobar**, introduce SSID y contraseña de la red
   doméstica **2.4 GHz** y pulsa **Guardar Wi-Fi en la máquina**.
4. La máquina prueba la conexión durante hasta 20 s. Solo guarda las credenciales
   si se conecta. Si falla, la red de configuración permanece abierta para
   reintentar; las credenciales anteriores se conservan.
5. Tras la confirmación, vuelve al Wi-Fi de casa y pulsa **Terminar**. La app guarda
   la IP confirmada, usa puerto 81 y sale de simulación. El AP se cierra 15 s
   después de conectar. No es necesario usarlo en cada encendido.

El dispositivo anuncia `fantasy-machine.local` y `_fantasy-machine._tcp:81`.
Si el router cambia la IP, usa **Buscar máquina**, el hostname, o una reserva DHCP.
Después de 60 s sin red, abre de nuevo su AP protegido, pero sigue intentando
reconectar. BOOT (3 s después del arranque) también reabre el asistente sin borrar
la configuración ni resetear el contador. Solo un dispositivo debería utilizar
ese hostname en la misma LAN en esta primera versión.

## Medición

Se cuentan ambos flancos de A y B mediante interrupciones GPIO en IRAM y un
contador firmado de 64 bits. La instantánea GPIO toma A/B simultáneamente;
las lecturas compartidas se protegen con una sección crítica.

La hoja de datos AS5311 rev. 1.13, sección 7, especifica 256 ciclos/canal y
**1024 flancos por par de polos de 2 mm**, incluyendo cuadratura. Por eso:

```text
x_mm = (contador - cero) / 512.0
```

No multiplicar nuevamente por cuatro. Resolución nominal: 0.001953125 mm por
cuenta. El bit absoluto SSI de 0.000488 mm no es la resolución A/B.
Se aplica el signo invertido después de restar el cero. El cero se pierde al
reiniciar; el sensor es incremental, no conserva el recorrido absoluto apagado.

Los saltos inválidos (cambian A y B a la vez) se cuentan en diagnóstico y no se
convierten en desplazamientos inventados. No se añade debounce temporal que
pueda suprimir movimiento legítimo. Quietud no genera alarma. SSI no se lee, por
lo que **no puede confirmarse presencia del sensor ni calidad del campo**:
`sensor: unverified` es deliberado, no un error por estar quieto.
`transition_warning` indica que hubo saltos ilegales desde el arranque.

## WebSocket

`ws://fantasy-machine.local:81/ws`, o `ws://IP:81/ws`.
25 frames/s, incluso sin movimiento; diagnóstico Serial una vez por segundo.

```json
{"type":"position","x_mm":-16.103515625,"timestamp":12345}
```

`timestamp` es uptime en ms (uint32; vuelve a cero cada ~49 días). La app usa
su hora de recepción para detectar datos obsoletos. No se suaviza el dato real.
Al conectar y una vez por segundo:

```json
{"type":"status","connected":true,"status":"incremental_ready","sensor":"unverified","wifi":"ok","inverted":false,"counts_per_mm":512}
```

`connected` confirma disponibilidad del transporte, no la presencia física del
AS5311. Comandos aceptados:

```json
{"type":"zero_x"}
{"type":"set_direction","inverted":true}
```

La dirección se persiste solo si cambia. El cero solo modifica un offset RAM.
Comandos desconocidos se rechazan con status `invalid_command`; un fallo NVS
devuelve `storage_error`. JSON inválido se ignora; no ejecuta ninguna acción.
No existen comandos de movimiento.

MicroFantasy ya invierte X en la app mediante su ajuste de dirección. **Mantén
la dirección del firmware normal si usas ese ajuste**, para no invertir dos veces.
El servicio Dart permite `zero_x` con `allowZeroX: true`; la UI no lo envía
automáticamente porque cambiar el cero invalida la referencia de calibración.

## API de configuración

Disponible únicamente desde la interfaz AP, no desde la red doméstica:

- `GET http://192.168.4.1/api/v1/setup`: identificación, progreso, IP y error.
- `POST` al mismo endpoint: `{"ssid":"...","password":"..."}`. Responde
  `202 {"accepted":true}` antes de intentar conectar. La app consulta GET
  hasta confirmar `connected: true`, o informa el fallo.
- `400`: campos inválidos; `403`: fuera del AP; `409`: otro intento en curso.
- Nunca devuelve ni registra la contraseña doméstica. La app no la persiste.

El AP usa WPA2 con clave por dispositivo. La configuración HTTP viaja sobre ese
enlace; WebSocket usa la LAN de confianza sin autenticación adicional/TLS.
No exponer puertos 80/81 a Internet. NVS no está cifrada en esta primera versión.

## Pruebas

El workflow `Check MicroFantasy firmware` compila para el XIAO y ejecuta pruebas
de matemática del contador. En Linux/macOS:

```sh
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/position_test.cpp -o /tmp/position-test
/tmp/position-test
```

Las pruebas móviles cubren validación de credenciales, HTTP real contra un
servidor de prueba, confirmación de conexión, bloqueo de redirects, compatibilidad
de telemetría y reconexión WebSocket. No sustituyen la prueba eléctrica:

1. Mueve 2 mm conocidos: debe cambiar 1024 cuentas; vuelve al origen.
2. Prueba ambos sentidos, cero e inversión.
3. Comprueba `invalid: 0` con la máxima velocidad manual prevista y Wi-Fi activo.
4. Déjalo quieto: llegan datos a 25 Hz sin error por inactividad.
5. Apaga/enciende: recupera Wi-Fi y dirección; X vuelve a la referencia de arranque.
6. Prueba contraseña incorrecta, recuperación de red y reconexión de la app.

La velocidad máxima real y la pérdida de pulsos bajo carga deben medirse con
hardware. Esta implementación por ISR no promete los 650 mm/s máximos del chip.

## Fuentes

- [AS5311 datasheet rev. 1.13](https://look.ams-osram.com/m/27ea8328172c5288/original/AS5311-DS000200.pdf)
- [XIAO ESP32-C3](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/)
- [PlatformIO XIAO ESP32-C3](https://docs.platformio.org/en/latest/boards/espressif32/seeed_xiao_esp32c3.html)
- [Espressif Wi-Fi API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html)
- [arduinoWebSockets](https://github.com/Links2004/arduinoWebSockets)
