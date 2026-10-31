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

1. El ESP32 crea la red MicroFantasy-XXXXXX con password **fantasy123**.
   Esta version reemplaza la clave aleatoria anterior y conserva el Wi-Fi de casa.
   Si el celular recuerda la clave vieja, olvida esa red y vuelve a conectarte.
   BOOT durante 3 segundos despues de arrancar reabre la configuracion.
2. Instala la nueva versión de MicroFantasy. En **Configuración → Máquina →
   Configurar Wi-Fi de la máquina**, abre los ajustes Wi-Fi y conéctate a esa red.
   Acepta permanecer conectado aunque Android avise que no hay Internet. En iOS,
   abre Ajustes → Wi-Fi manualmente y regresa a la app.
3. Toca **Ya estoy conectado: comprobar**. La máquina busca redes y la app muestra
   sus nombres: elige tu Wi-Fi, introduce su contraseña y pulsa **Guardar Wi-Fi en
   la máquina**. Si tu router usa un único nombre para varias bandas, elige ese
   mismo nombre. No hace falta separar bandas ni entrar al router. **Escribir
   nombre** permite configurar una red oculta.
4. La máquina busca la señal compatible y realiza hasta tres intentos automáticos
   de 25 s, con pausas entre ellos. La app muestra el progreso y tolera las pausas
   del AP al cambiar de canal. Solo guarda cuando obtiene una IP en la red elegida.
   Si falla, la red de configuración permanece disponible para reintentar; las
   credenciales anteriores se conservan.
5. Tras la confirmación, vuelve al Wi-Fi de casa y pulsa **Terminar**. La app guarda
   la IP confirmada, usa puerto 81 y sale de simulación. El AP se cierra 60 s
   después de conectar. No es necesario usarlo en cada encendido.

El dispositivo anuncia `fantasy-machine.local` y `_fantasy-machine._tcp:81`.
Si el router cambia la IP, usa **Buscar máquina**, el hostname, o una reserva DHCP.
Después de 60 s sin red, abre de nuevo su AP protegido, pero sigue intentando
reconectar. BOOT (3 s después del arranque) también reabre el asistente sin borrar
la configuración ni resetear el contador. Solo un dispositivo debería utilizar
ese hostname en la misma LAN en esta primera versión.

**Esta mejora requiere actualizar firmware y app.** La app sigue permitiendo
introducir el nombre manualmente con firmware anterior, pero no puede añadirle
las capacidades de búsqueda/reintento por sí sola.

El firmware usa escaneo asíncrono, selección por señal, dos intentos dirigidos a
los AP de 2.4 GHz encontrados y un último intento sin fijar BSSID. En redes WPA3
habilita SAE H2E y hunting-and-pecking (`WPA3_SAE_PWE_BOTH`); conserva PMF opcional
y el mínimo WPA2 para redes protegidas. No modifica ninguna configuración del
router. El C3 no puede conectarse a una red exclusivamente 5/6 GHz, ni este
asistente de contraseña configura redes Enterprise. Los nombres listados son
redes personales/abiertas visibles para su radio. La compatibilidad con un
router concreto debe verificarse con hardware; los reintentos no garantizan que
un AP que rechaza clientes vaya a aceptarlos.

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
- `POST /api/v1/setup/networks`: inicia búsqueda asíncrona; responde `202`.
  `GET` al mismo endpoint devuelve `device`, `schemaVersion`, `scanning`, `error`
  y `networks: [{"ssid":"Casa","rssi":-43,"secured":true}]` (máximo 24 nombres).
  Las credenciales y los BSSID no aparecen en esta respuesta.
- El estado añade `scan_supported`, `phase`, `attempt`, `max_attempts` y
  `reason_code` sin romper clientes v1. Fases: `preparing`, `scanning`, `retrying`,
  `connecting`, `getting_address`, `connected`, `failed`.
- Los fallos distinguen `network_not_found`, `authentication_failed`,
  `association_failed`, `address_timeout`, `signal_lost`, `connection_timeout`
  y `storage_error`. Un fallo de autenticación no demuestra por sí solo que la
  contraseña sea incorrecta. Serial registra el motivo numérico/nombre del SDK;
  no es necesario interpretar estos códigos para utilizar la app.
- `400`: campos inválidos; `403`: fuera del AP; `409`: otro intento en curso.
- Nunca devuelve ni registra la contraseña doméstica. La app no la persiste.

El AP usa WPA2 con la clave compartida fantasy123. La configuración HTTP viaja sobre ese
enlace; WebSocket usa la LAN de confianza sin autenticación adicional/TLS.
No exponer puertos 80/81 a Internet. NVS no está cifrada en esta primera versión.

## Pruebas

El workflow `Check MicroFantasy firmware` compila para el XIAO y ejecuta pruebas
de matemática del contador y recuperación de configuración Wi-Fi. En Linux/macOS:

```sh
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/position_test.cpp -o /tmp/position-test
/tmp/position-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/wifi_setup_test.cpp -o /tmp/wifi-setup-test
/tmp/wifi-setup-test
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
7. Con un SSID unificado, selecciona la red desde la lista, espera confirmación,
   reinicia el ESP32 y comprueba la reconexión. Verifica también interrupción
   temporal del AP, reintentos, fallo DHCP y conservación de la red anterior.

La velocidad máxima real y la pérdida de pulsos bajo carga deben medirse con
hardware. Esta implementación por ISR no promete los 650 mm/s máximos del chip.

## Fuentes

- [AS5311 datasheet rev. 1.13](https://look.ams-osram.com/m/27ea8328172c5288/original/AS5311-DS000200.pdf)
- [XIAO ESP32-C3](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/)
- [PlatformIO XIAO ESP32-C3](https://docs.platformio.org/en/latest/boards/espressif32/seeed_xiao_esp32c3.html)
- [Espressif Wi-Fi API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html)
- [WPA3 / SAE en ESP-IDF 4.4.8](https://docs.espressif.com/projects/esp-idf/en/v4.4.8/esp32c3/api-guides/wifi-security.html)
- [arduinoWebSockets](https://github.com/Links2004/arduinoWebSockets)


## Descubrimiento del telefono desde V90

GET http://fantasy-machine.local/api/v1/apps devuelve los clientes WebSocket
conectados como candidatos en el puerto 8787. V90 verifica cada receptor antes
de ofrecerlo. Buscar no envia trabajos. La app debe estar abierta, conectada al
ESP32 (sin simulacion) y con Recibir por Wi-Fi activo. El navegador debe resolver
el hostname y permitir red local. La IP manual sigue disponible sin ESP32.
No se requiere codigo de emparejamiento.
