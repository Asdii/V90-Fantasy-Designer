# MicroFantasy

Guía móvil de corte manual para lapidarios. El usuario gira R, mueve X hasta la zona de tolerancia y realiza el corte manualmente. La app **no controla motores**. Sólo X se mide y compensa; la pantalla de corte muestra R como orientación manual. La profundidad se conserva en el trabajo recibido, pero no se muestra como indicador.

Aplicación Flutter independiente de V90, con proyectos Android, iOS y una vista web de simulación. Tres secciones: **Corte · Calibración · Configuración**. Interfaz clara en español.

## Ejecutar

Requiere Flutter estable y las herramientas de la plataforma. Desarrollada y verificada con **Flutter 3.47.9 / Dart 3.13.7**. Las dependencias están fijadas en `pubspec.lock`.

Desde la raíz del repositorio:

```sh
cd microfantasy
flutter pub get
flutter run
```

En este workspace también hay un SDK local, excluido de Git:

```powershell
cd microfantasy
..\outputs\toolchains\flutter\bin\flutter.bat run
```

Android:

```sh
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk

flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Las compilaciones locales sin variables de firma usan la clave de desarrollo de
este equipo. GitHub Actions exige la misma identidad guardada como secretos y
publica un APK por push a `main`. La app incluye **Configuración → Datos → Actualizaciones**.
Consulta la [configuración inicial y guía de actualización](../docs/microfantasy-updates.md).
No cambies el identificador ni la firma de una app ya distribuida sin planificar la migración.

iOS requiere **macOS y Xcode**, un equipo de firma propio y permiso de red local. Abre `ios/Runner.xcworkspace` o ejecuta `flutter run` en el Mac. En Windows no se puede validar la compilación iOS. El proyecto incluye las declaraciones Bonjour y de red local.

Vista de simulación en navegador:

```sh
flutter run -d chrome
```

En web funcionan las pantallas y la simulación. La recepción HTTP y la conexión real al ESP32 son funciones nativas; no se ejecuta un servidor LAN dentro del navegador.

## Probar sin hardware

El primer inicio abre **Hexágono de práctica**, con Modo simulación activado.

1. Recorre el diseño con Anterior/Siguiente.
2. En Configuración → Opciones avanzadas, mueve X simulado o toca **Ir al objetivo**.
3. **Animar lectura** vuelve a generar posiciones ficticias.
4. En Calibración, centra una posición y toca **Establecer referencia**.
5. Repite para otros ángulos; cada punto queda guardado inmediatamente.
6. Regresa a Corte: con dos o más puntos se activa la compensación.
7. Cierra y vuelve a abrir: se recuperan trabajo, paso, preferencias, calibración y último trabajo pendiente.

La simulación conserva la lectura manual y continúa publicándola; no caduca por dejar quieto el slider. El icono de simulación del encabezado identifica este modo.

## Vista de corte y apariencia

Corte adapta el tamaño del dibujo al alto disponible; la regla X y los botones de paso permanecen visibles sin desplazar la pantalla. El Cut Helper tiene fondo transparente y puede ampliarse con el botón de la esquina del diagrama.

La regla muestra posiciones X absolutas: la etiqueta central es siempre el **objetivo corregido** del paso. Su rango permanece fijo en **±12,5 mm** (25 mm de extremo a extremo), sin cambiar de magnitud al acercarse ni al cambiar de paso. La línea del sensor mantiene su animación suave. Las cifras, el estado de tolerancia y la calibración siguen utilizando la lectura original, sin suavizado. Al acercarse aparece una lupa con conectores al intervalo exacto de la regla principal; la lupa no modifica la escala de esta última.

Configuración se organiza como Máquina, V90 Fantasy Designer, Preferencias, Temas, Datos y Opciones avanzadas. Los temas aparecen en este orden: **Claro, Oscuro, Midnight, Solarized Light, Nord, Catppuccin Latte, Dracula, Gruvbox Light y Nord Light**. Claro es el predeterminado en instalaciones nuevas. Oscuro combina fondo negro puro con texto y controles blancos. Las preferencias existentes se conservan. [Fuentes de las paletas y compatibilidad](docs/theme-palettes.md). El verde continúa reservado para confirmar la posición.

## Calibración y coordenadas

Todos los datos se almacenan en **mm**. La opción cm sólo modifica las etiquetas.

- Referencia: X centrado obligatoriamente en 0°. La pantalla abre en 0° y no permite avanzar sin establecer esa referencia.
- Offset: X medido menos X de referencia.
- Rehacer el punto 0° actualiza también la referencia; los otros valores medidos se conservan.
- Ángulos por defecto: 0, 30, …, 330°. Configurables en Preferencias.
- Se conservan sólo puntos realmente medidos. Una calibración vacía o con un único punto de referencia aún no activa la compensación del trabajo.
- Con dos o más puntos se interpola linealmente entre vecinos, incluido el intervalo que cruza 360°/0°. No se extrapola una tendencia fuera de esos vecinos.
- El mapa representa **offset X frente a R**. Cada punto se desplaza sólo horizontalmente desde su marca ideal; al completar todos los ángulos, se unen con segmentos en una silueta de offset X, sin calcular una desviación Y.
- Hay una única calibración, aplicada y guardada al capturar cada punto. Al actualizar se conserva la antigua calibración activa; si había varios perfiles se archivan localmente antes de consolidar. La inversión de X de instalaciones anteriores se respeta, sin selector en la interfaz.
- El suavizado afecta exclusivamente al marcador visual; guardar calibración, comprobar tolerancia y calcular objetivos utiliza lecturas originales, sin filtrar.
- Una lectura ausente, desconectada o caducada no da confirmación de posición.

Única fuente de objetivos en `AppController`:

```dart
double getXOffsetForAngle(double angle);
double getCorrectedTargetX(CuttingStep step);
// step.x + getXOffsetForAngle(step.angleR)
```

`CalibrationService` contiene la interpolación circular independiente de la interfaz.

## Formato de trabajo V90

El receptor Wi-Fi acepta el objeto JSON completo siguiente. `units` debe ser `mm`, los índices deben ser únicos y el orden del arreglo es el orden de corte. X puede ser negativo; profundidad debe ser finita y no negativa; R entre 0° y 360°.

```json
{
  "jobId": "example-001",
  "name": "Fantasy Pattern 01",
  "units": "mm",
  "steps": [
    { "index": 1, "angleR": 0.0, "x": 12.50, "depth": 0.30 },
    { "index": 2, "angleR": 30.0, "x": 13.10, "depth": 0.42 }
  ],
  "preview": {
    "segments": [
      {
        "stepIndex": 1,
        "start": { "x": 0.1, "y": 0.3 },
        "end": { "x": 0.9, "y": 0.3 }
      },
      {
        "stepIndex": 2,
        "start": { "x": 0.15, "y": 0.8 },
        "end": { "x": 0.85, "y": 0.2 }
      }
    ]
  }
}
```

`preview` es opcional. Sus coordenadas normalizadas están entre 0 y 1, origen arriba a la izquierda. Varios segmentos pueden compartir `stepIndex` para representar una polilínea; todos se resaltan juntos. Estos datos son exclusivamente visuales y nunca se usan para calcular X. Sin trazado se muestra un esquema de direcciones identificado como tal.

Ejemplo del contrato: [examples/fantasy-pattern.json](examples/fantasy-pattern.json).

V90 también envía `cutHelper` v1 con el contorno de referencia, segmentos en mm,
ancho de las ranuras, rueda, distancias con signo y vista inicial. **Abrir Cut Helper**
muestra el visor completo con navegación, Horizontal/Vertical y Volver a 0°.
Ejemplo: [examples/v90-cut-helper.json](examples/v90-cut-helper.json).
Contrato y coordenadas: [guía V90 → MicroFantasy](../docs/microfantasy-lan.md).

## Recepcion local desde V90

La recepción Wi-Fi se activa automáticamente al abrir la app y al volver al
primer plano. Mantén la app abierta. En V90 usa Send to MicroFantasy > Find phone, o introduce la IP del movil.
No hay codigo de enlace. POST /api/v1/jobs acepta JSON sin Authorization y responde
202 para un trabajo pendiente: el usuario decide abrirlo o reemplazar el actual.

Find phone utiliza el ESP32 actualizado como puente. Para descubrir el movil debe
estar conectado al ESP32 (sin simulacion) y con el receptor activo. IP manual
funciona sin ESP32. Chrome/Edge pueden pedir permiso de red local.
El receptor solo escucha en primer plano. Ya no se muestra un botón de importación
de trabajos JSON; los archivos de calibración siguen teniendo importación/exportación.

Limites: 1 MiB por trabajo, 10 propuestas pendientes y timeout de cuerpo de 10 s.
JSON invalido se rechaza antes de modificar el trabajo actual.
Contrato detallado: [receptor](lib/services/fantasy_designer/README.md).

## ESP32

Configuración predeterminada: `ws://fantasy-machine.local:81/ws`.

- Activar/desactivar Simulación selecciona el servicio sin cambiar widgets.
- Búsqueda DNS-SD/mDNS de `_fantasy-machine._tcp`; hostname o IP manual como respaldo.
- Puerto y timeout en Opciones avanzadas.
- Reconexión con espera creciente, ping y detección de telemetría caducada.
- No es necesario cambiar el Wi-Fi del teléfono si ambos equipos están en la misma red.

Mensajes ESP32 → app:

```json
{"type":"position","x_mm":16.104,"timestamp":12345678}
{"type":"status","connected":true}
```

La marca temporal remota es opcional; la frescura se decide con el tiempo local de recepción. También se admite `{"type":"status","status":"ready"}`.

Único comando de aplicación preparado:

```json
{"type":"zero_x"}
```

Requiere construir el servicio con `allowZeroX: true` y llamar explícitamente a `zeroX()`. La UI inicial no envía comandos al hardware.

Para conectar hardware: implementa ese WebSocket en el firmware, anuncia el servicio mDNS o introduce IP y puerto, y desactiva Simulación. `MockEsp32Service` y `WebSocketEsp32Service` implementan el mismo contrato.

### Configuración del Wi-Fi de casa

En **Configuración → Máquina → Configurar Wi-Fi de la máquina**, conecta el
teléfono a `MicroFantasy-…` (contraseña `fantasy123`) y comprueba la conexión.
Envía el nombre y contraseña del Wi-Fi doméstico de 2.4 GHz. El ESP32 guarda
las credenciales en NVS únicamente cuando la conexión funciona; permanecen
guardadas después de apagarlo. Espera la confirmación y vuelve al Wi-Fi de casa.

La petición usa JSON UTF-8 con `Content-Length` en bytes explícito. El
[WebServer de Arduino-ESP32 2.0.17](https://github.com/espressif/arduino-esp32/blob/2.0.17/libraries/WebServer/src/Parsing.cpp)
necesita esa longitud para leer el cuerpo y no decodifica peticiones chunked.
Sin establecerla, [HttpClientRequest](https://api.dart.dev/dart-io/HttpClientRequest/contentLength.html)
usa longitud desconocida, y la versión anterior de la app podía comprobar la
máquina pero fallar al enviar las credenciales. Se corrige actualizando la app;
no requiere cambiar el firmware ni borrar la memoria del ESP32.

Los rechazos HTTP 400 (datos), 403 (fuera de la red de configuración) y 409
(intento en curso) se distinguen de los fallos de transporte. La confirmación
final sigue dependiendo del estado enviado por el firmware; un `storage_error`
no se presenta como guardado correcto. Las contraseñas no aparecen en los
mensajes de error ni se envían a una dirección de redirección.

## Arquitectura

- `lib/models/`: trabajos, pasos, preview, perfiles, preferencias y progreso.
- `lib/app/`: controlador de estado y tema.
- `lib/services/esp32/`: interfaz, mock, WebSocket, protocolo y descubrimiento.
- `lib/services/fantasy_designer/`: interfaz, receptor HTTP nativo y variante web.
- `lib/services/calibration/`: interpolación y compensación.
- `lib/repositories/`: trabajos, preferencias, calibraciones y almacenamiento desacoplado.
- `lib/screens/`: Corte, Calibración, Configuración.
- `lib/widgets/`: barra X, plano 2D, Cut Helper de V90 y mapa circular.

`SharedPreferencesAsync` guarda JSON versionado; repositorios serializan operaciones para evitar perder cambios concurrentes. `MemoryStore` permite pruebas sin plugins. El progreso incluye una copia independiente del trabajo abierto, por lo que recibir otro con el mismo ID no modifica el trabajo en curso antes de aceptarlo.

## Verificar

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
dart analyze lib test tool
flutter test
flutter build apk --debug
```

Las pruebas cubren interpolación, wrap, compensación, pasos, JSON, persistencia, recepción HTTP real en loopback, reconexión WebSocket, mock y navegación en teléfono pequeño.

Capturas opcionales: `flutter test --update-goldens tool/visual_check_test.dart`. Se escriben en `build/qa/`; las variables `MICROFANTASY_QA_FONT` y `MICROFANTASY_QA_ICONS` aceptan archivos de fuente locales para la verificación visual.

El hardware ESP32 y la distribución iOS requieren validación en dispositivos físicos. La app no verifica físicamente R ni profundidad: dependen del ajuste manual.

Referencias de implementación: [red en Flutter](https://docs.flutter.dev/data-and-backend/networking), [DNS-SD con nsd](https://pub.dev/packages/nsd), [configuración iOS](https://docs.flutter.dev/platform-integration/ios/setup).


## Apariencia y guía X

Los temas se guardan localmente. El encabezado y los iconos Android/iOS usan el
mismo dibujo vectorial de micromotor con gema.
Para regenerar los tamaños del icono: `flutter test tool/generate_app_icons.dart`.

La barra principal conserva su rango de ±12,5 mm. Una lupa centrada sobre ella
aparece cerca del objetivo sin mover ni reescalar la barra principal. El marcador
se anima independientemente de la frecuencia de telemetría. La lupa y el suavizado
son sólo visuales: las lecturas, la calibración y la comprobación de tolerancia
siempre usan el dato real.

Modo simulación está en Configuración > Opciones avanzadas.
