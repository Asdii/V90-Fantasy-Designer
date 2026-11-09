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

La referencia X descrita aquí requiere **actualizar firmware y app**. La app
debe comprobar `capabilities: ["set_x_reference"]`; una versión antigua del
firmware no puede confirmar el anclaje manual. Actualizar/reiniciar el ESP32
conserva Wi-Fi y dirección, pero requiere volver a referenciar X físicamente.

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
x_mm = signo * ((contador - cuenta_ancla) / 512.0 + offset_mm)
signo = inverted ? -1 : 1
al anclar: cuenta_ancla = contador_actual; offset_mm = signo * x_solicitado
```

No multiplicar nuevamente por cuatro. Resolución nominal: 0.001953125 mm por
cuenta. El bit absoluto SSI de 0.000488 mm no es la resolución A/B.
Se aplica el signo también al offset. El contador físico nunca se modifica al
anclar ni al poner cero. Se permiten coordenadas entre cuentas, sin redondearlas
al pulso más cercano. El anclaje se pierde al reiniciar; el sensor es incremental,
no conserva el recorrido absoluto apagado.

Los saltos inválidos (cambian A y B a la vez) se cuentan en diagnóstico y no se
convierten en desplazamientos inventados. No se añade debounce temporal que
pueda suprimir movimiento legítimo. Quietud no genera alarma. SSI no se lee, por
lo que **no puede confirmarse presencia del sensor ni calidad del campo**:
`sensor: unverified` es deliberado, no un error por estar quieto.
`transition_warning` indica que hubo saltos ilegales desde el arranque.

## Centro calibrado y referencia después de cada arranque

1. Calibra el **centro físico** en la app y guarda las coordenadas de los topes
   negativo y positivo respecto de ese centro. Los recorridos pueden ser
   asimétricos (por ejemplo, -37.25 mm y +83 mm); no se calcula el centro como
   promedio de los topes. La app conserva esa calibración y su `reference_id`.
2. En cada arranque real del ESP32, `boot_id` cambia, `reference_id` es `null` y
   `reference_revision` vale 0. Las posiciones iniciales son provisionales;
   **conectar Wi-Fi no equivale a tener X referenciada**.
3. Lleva manualmente el carro al tope elegido y pulsa explícitamente en la app
   el botón de confirmar que estás en ese tope. La app envía su coordenada
   guardada, el `reference_id` de calibración, el `boot_id` vigente y un
   `request_id` nuevo. También se admite anclar en 0 al confirmar el centro.
4. La app valida el ACK y las muestras con la misma identidad de arranque,
   referencia y revisión antes de usar la coordenada. No envía anclajes ni
   reintentos automáticos al iniciar, reconectar o vencer un timeout. Si no
   conoce el resultado, consulta la telemetría y requiere una nueva acción
   manual en el tope para repetir con un ID nuevo.

Perder Wi-Fi, cambiar de IP, reabrir el AP o reconectar WebSocket **no** cambia
`boot_id`, la referencia, su revisión, el offset ni el contador. El sensor sigue
contando durante la desconexión. La referencia y los recibos de comandos viven
solo en RAM: no se escriben coordenadas, pulsos ni revisiones continuamente en
NVS. Los topes guardados por la app son puntos de referencia, no límites de
movimiento impuestos por este medidor. No hay comandos de motor.

## WebSocket

`ws://fantasy-machine.local:81/ws`, o `ws://IP:81/ws`.
Aproximadamente 29 frames/s (intervalo de 34 ms), incluso sin movimiento;
diagnóstico Serial una vez por segundo. Al conectar se envían identidad y una
lectura inmediatamente, tomadas de una misma instantánea. Cada respuesta de
referencia y cada comando legado aceptado publica status y posición de inmediato.

```json
{"type":"position","x_mm":-16.103515625,"timestamp":12345,"boot_id":"fd5e876ef5270419ee7d641f744934d8","reference_id":"calibracion-1","reference_revision":1}
```

`timestamp` es uptime en ms (uint32; vuelve a cero cada ~49 días). La app usa
su hora de recepción para detectar datos obsoletos. No se suaviza el dato real.
Al conectar y una vez por segundo:

```json
{"type":"status","connected":true,"service":"microfantasy-machine","api_version":1,"device_id":"microfantasy-aabbccddeeff","hostname":"fantasy-machine.local","ip":"192.168.1.82","ws_port":81,"ws_path":"/ws","status":"incremental_ready","sensor":"unverified","wifi":"ok","inverted":false,"counts_per_mm":512,"boot_id":"fd5e876ef5270419ee7d641f744934d8","reference_id":"calibracion-1","reference_revision":1,"capabilities":["set_x_reference"]}
```

El estado anuncia además `capabilities: ["set_x_reference", "ack_boot"]` y
`boot_notice_pending: true` después de cada encendido o reinicio. Se repite en
los estados periódicos y en cada nueva conexión hasta recibir:

```json
{"type":"ack_boot","boot_id":"fd5e876ef5270419ee7d641f744934d8"}
```

La app confirma solamente después de guardar el aviso localmente; lo muestra con
acceso a Calibración X. No importa si se abre mucho después de encender la placa.
El ESP32 responde con un estado con `boot_notice_pending: false`. Se exige el
`boot_id` vigente; el ACK es idempotente y no cambia contador, cero ni referencia.
La marca permanece en RAM durante todo el arranque; no se escribe flash por cada
mensaje. Al reiniciar se crea otro aviso. Una reconexión Wi-Fi no lo reinicia.

`boot_id` es un identificador aleatorio de 128 bits generado una vez por arranque,
representado como 32 caracteres ASCII hexadecimales (contrato: máximo 80).
Todos los mensajes `position`, la identidad HTTP/UDP y todos los `status`, incluso
los errores, llevan `boot_id`, `reference_id` y `reference_revision`. La revisión
es un entero no negativo que aumenta con cada anclaje nuevo aceptado, `zero_x` y
cambio efectivo de dirección. Mover el carro no aumenta la revisión.

`connected` confirma disponibilidad del transporte, no la presencia física del
AS5311 ni una referencia válida. Comando de anclaje:

```json
{"type":"set_x_reference","request_id":"anclaje-1","boot_id":"fd5e876ef5270419ee7d641f744934d8","reference_id":"calibracion-1","x_mm":-37.25}
```

Se exige un objeto JSON con exactamente esos cinco campos. Los tres IDs siguen
`^[A-Za-z0-9_.:-]{1,80}$`, igual que la app: ASCII portable, no vacío, máximo 80
caracteres. `boot_id` debe coincidir con el arranque vigente. `x_mm` es un número
JSON finito, con `abs(x_mm) <= 10000`; no se convierten cadenas, booleanos o null
a números. Se rechazan claves duplicadas, campos extra, datos después del objeto
y mensajes mayores de 2048 bytes. Ese tamaño admite tres IDs de 80 caracteres
aun usando escapes JSON completos.

Solo el cliente que inició el comando recibe el ACK, **antes** de difundir status
y posición a todos los clientes. Ejemplo de aceptación:

```json
{"type":"reference_ack","request_id":"anclaje-1","accepted":true,"boot_id":"fd5e876ef5270419ee7d641f744934d8","reference_id":"calibracion-1","reference_revision":1,"x_mm":-37.25}
```

En una aceptación nueva, `x_mm` es la coordenada solicitada en el conteo capturado
al anclar, aunque el carro se mueva mientras se transmite. La salida numérica
conserva precisión muy superior a 1e-6 mm dentro del rango admitido. Status y
posición inmediatos comparten la misma instantánea. Cada frame periódico usa
una captura coherente de coordenada/referencia/revisión.

Un rechazo lleva `accepted: false`, `error` y la referencia/revisión/coordenada
actuales; no modifica el estado. Errores: `invalid_request_id`, `invalid_boot_id`,
`invalid_reference_id`, `invalid_x_mm`, `unsupported_x`, `wrong_boot`,
`request_id_conflict`, `invalid_command`, `invalid_json`, `payload_too_large`.
Si no puede recuperarse un ID válido (incluido JSON malformado), el ACK usa
`request_id: ""`. Después del rechazo también se difunden status y posición.

Se conservan en RAM los **últimos 16 anclajes exitosos**, en orden de aceptación,
durante el mismo arranque. Repetir su `request_id` con el mismo contenido devuelve
exactamente el ACK original, sin volver a anclar, incrementar la revisión ni
reescribir NVS. Cambiar la coordenada o el `reference_id` con un ID almacenado
devuelve `request_id_conflict`; un arranque distinto devuelve `wrong_boot`.
Ni `zero_x` ni un cambio de dirección borran estos recibos. Un ACK duplicado
puede describir una revisión antigua: la difusión posterior describe el estado
actual. Los recibos más antiguos se expulsan; la app nunca debe reintentarlos
automáticamente ni reutilizar IDs para acciones manuales nuevas.

Comandos legados:

```json
{"type":"zero_x"}
{"type":"set_direction","inverted":true}
```

`zero_x` ajusta únicamente el origen RAM, invalida `reference_id` (null) e
incrementa la revisión, incluso si ya se estaba en cero. La dirección se persiste
solo si cambia; un cambio exitoso niega toda la coordenada, invalida la referencia
e incrementa la revisión. Repetir la misma dirección no modifica esos campos ni
escribe NVS. Si falla la persistencia, se restaura la dirección y se conserva la
referencia/revisión; se devuelve status `storage_error`. Comandos desconocidos
se rechazan con status `invalid_command`. JSON inválido no ejecuta ninguna acción.

MicroFantasy ya invierte X en la app mediante su ajuste de dirección. **Mantén
la dirección del firmware normal si usas ese ajuste**, para no invertir dos veces.
`x_mm` del comando siempre está expresado en el sistema de coordenadas de la
telemetría del firmware; la app debe convertir cualquier inversión propia antes
de enviar una coordenada de tope.
El servicio Dart permite `zero_x` con `allowZeroX: true`; la UI no lo envía
automáticamente porque cambiar el cero invalida la referencia de calibración.

## Dirección e identidad de la máquina

La IP puede cambiar por DHCP; `device_id` se deriva de la MAC de la placa y se
mantiene al reiniciar o cambiar de red. La app recuerda esa identidad y verifica
la dirección antes de usarla, en lugar de reconectar indefinidamente a una IP vieja.

- `GET /api/v1/info` devuelve los campos de identidad del mensaje anterior,
  incluidos referencia, revisión, arranque y `capabilities`, sin credenciales y
  con `Cache-Control: no-store`, en LAN o en el AP.
- DNS-SD anuncia `_fantasy-machine._tcp` en el puerto 81, con TXT `id`, `path`
  y `api_version`. Se renueva el anuncio si cambia la IP.
- Respaldo UDP local: puerto **42190**. Petición
  `{"type":"discover","api_version":1,"nonce":"token-de-la-busqueda"}`.
  Respuesta unicast con `type: "discovery"`, el mismo `nonce` y los campos de
  identidad. Máximo 256 bytes por petición y diez respuestas por segundo.
- El móvil usa la dirección del emisor verificada por HTTP, no el campo `ip`:
  durante la configuración la IP de la interfaz AP puede ser diferente de la LAN.
- Después del HTTP, el primer status WebSocket confirma la misma identidad.
  No requiere código de emparejamiento. Es identificación de equipos en una LAN
  de confianza, no autenticación criptográfica.

Ante una desconexión Wi-Fi confirmada se reintenta tras 1 s, luego 2, 4 y hasta
8 s entre fallos. Una asociación en curso conserva hasta 15 s; DHCP dispone de
hasta 25 s desde el intento. Estos tiempos evitan reiniciar continuamente una
negociación válida. El flujo de configuración inicial conserva sus tres intentos.
La búsqueda del móvil se repite en cada reconexión y al volver del segundo plano;
una lectura desconectada se invalida hasta recibir otra nueva. Ni la búsqueda ni
la reconexión ponen X a cero ni escriben repetidamente credenciales en NVS.

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
de matemática del contador, estado/protocolo de referencia X, recuperación Wi-Fi
y confirmación del aviso de arranque.
Las pruebas de estado son C++11 puro; las del protocolo usan los headers de la
misma versión ArduinoJson que instala la compilación PlatformIO. En Linux/macOS,
desde la raíz del repositorio (compila antes el firmware para obtener esos headers):

```sh
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/position_test.cpp -o /tmp/position-test
/tmp/position-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/x_reference_test.cpp -o /tmp/x-reference-test
/tmp/x-reference-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include -Ifirmware/microfantasy-xiao/.pio/libdeps/xiao_esp32c3/ArduinoJson/src firmware/microfantasy-xiao/test/x_reference_protocol_test.cpp -o /tmp/x-reference-protocol-test
/tmp/x-reference-protocol-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include -Ifirmware/microfantasy-xiao/.pio/libdeps/xiao_esp32c3/ArduinoJson/src firmware/microfantasy-xiao/test/boot_notice_test.cpp -o /tmp/boot-notice-test
/tmp/boot-notice-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/wifi_setup_test.cpp -o /tmp/wifi-setup-test
/tmp/wifi-setup-test
c++ -std=c++11 -Wall -Wextra -Werror -Ifirmware/microfantasy-xiao/include firmware/microfantasy-xiao/test/wifi_reconnect_test.cpp -o /tmp/wifi-reconnect-test
/tmp/wifi-reconnect-test
```

La suite X cubre topes negativos/positivos, centro cero, recorrido asimétrico,
ambas inversiones, anclajes fraccionarios y cuentas grandes, validación estricta,
arranque incorrecto, ACK idempotente tras movimiento u otros comandos, conflictos
de payload, caché acotada, invalidación legada, reset frente a continuidad Wi-Fi,
serialización numérica, IDs máximos/escapados y metadatos coherentes.

Las pruebas móviles cubren validación de credenciales, HTTP real contra un
servidor de prueba, confirmación de conexión, bloqueo de redirects, compatibilidad
de telemetría y reconexión WebSocket. No sustituyen la prueba eléctrica:

1. Mueve 2 mm conocidos: debe cambiar 1024 cuentas; vuelve al origen.
2. Prueba ambos sentidos, cero e inversión.
3. Comprueba `invalid: 0` con la máxima velocidad manual prevista y Wi-Fi activo.
4. Déjalo quieto: llegan datos a aproximadamente 29 Hz sin error por inactividad.
5. Apaga/enciende: recupera Wi-Fi y dirección; cambia `boot_id`, vuelve a revisión
   0 y `reference_id: null`. Confirma manualmente un tope para recuperar el marco
   calibrado. Repite en ambos topes, incluido un rango asimétrico.
6. Prueba contraseña incorrecta, recuperación de red y reconexión de la app.
7. Con un SSID unificado, selecciona la red desde la lista, espera confirmación,
   reinicia el ESP32 y comprueba la reconexión. Verifica también interrupción
   temporal del AP, reintentos, fallo DHCP y conservación de la red anterior.
8. Comprueba que la IP mostrada en la app coincide con Serial. Después de un
   cambio de IP o de red del teléfono, debe recuperar la misma placa sin escribir
   la nueva dirección. Cierra/abre la app y comprueba que conserva paso y calibración.
9. Referencia X y corta solo Wi-Fi; mueve el carro y reconecta: conserva arranque,
   referencia y revisión, e incorpora el movimiento durante el corte. Con dos
   clientes, confirma que solo el iniciador recibe ACK y ambos reciben status y
   posición. Repite el mismo comando tras mover: el ACK original no debe reanclar.
10. Enciende la placa con la app cerrada: al abrirla debe aparecer el aviso de
    arranque con acceso a Calibración X. Ciérrala sin descartar el aviso y vuelve
    a abrirla: permanece visible. Descártalo, desconecta/reconecta Wi-Fi: no debe
    reaparecer. Reinicia la placa: aparece uno nuevo sin cambiar automáticamente X.

La velocidad máxima real y la pérdida de pulsos bajo carga deben medirse con
hardware. Esta implementación por ISR no promete los 650 mm/s máximos del chip.

## Fuentes

- [AS5311 datasheet rev. 1.13](https://look.ams-osram.com/m/27ea8328172c5288/original/AS5311-DS000200.pdf)
- [XIAO ESP32-C3](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/)
- [PlatformIO XIAO ESP32-C3](https://docs.platformio.org/en/latest/boards/espressif32/seeed_xiao_esp32c3.html)
- [Espressif Wi-Fi API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html)
- [WPA3 / SAE en ESP-IDF 4.4.8](https://docs.espressif.com/projects/esp-idf/en/v4.4.8/esp32c3/api-guides/wifi-security.html)
- [arduinoWebSockets](https://github.com/Links2004/arduinoWebSockets)
- [ESPHome mDNS](https://esphome.io/components/mdns/)
- [Reconexión y descubrimiento de ESPHome](https://github.com/esphome/aioesphomeapi/blob/main/aioesphomeapi/reconnect_logic.py)
- [Android Network Service Discovery](https://developer.android.com/develop/connectivity/wifi/use-nsd)


## Descubrimiento del telefono desde V90

GET http://fantasy-machine.local/api/v1/apps devuelve los clientes WebSocket
conectados como candidatos en el puerto 8787. V90 verifica cada receptor antes
de ofrecerlo. Buscar no envia trabajos. La app debe estar abierta, conectada al
ESP32 (sin simulacion) y con Recibir por Wi-Fi activo. El navegador debe resolver
el hostname y permitir red local. La IP manual sigue disponible sin ESP32.
No se requiere codigo de emparejamiento.
