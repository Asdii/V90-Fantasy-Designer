# MicroFantasy

Guía móvil de corte manual para lapidarios. El usuario gira R, mueve X hasta la zona de tolerancia y realiza el corte manualmente. La app **no controla motores**. Sólo X se mide y compensa; R y la profundidad son indicaciones para el operador.

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
publica un APK por push a `main`. La app incluye **Configuración → Actualizaciones**.
Consulta la [configuración inicial y guía de actualización](../docs/microfantasy-updates.md).
No cambies el identificador ni la firma de una app ya distribuida sin planificar la migración.

iOS requiere **macOS y Xcode**, un equipo de firma propio y permiso de red local. Abre `ios/Runner.xcworkspace` o ejecuta `flutter run` en el Mac. En Windows no se puede validar la compilación iOS. El proyecto incluye las declaraciones Bonjour y de red local.

Vista de simulación en navegador:

```sh
flutter run -d chrome
```

En web funcionan las pantallas, la simulación y la importación JSON. La recepción HTTP y la conexión real al ESP32 son funciones nativas; no se ejecuta un servidor LAN dentro del navegador.

## Probar sin hardware

El primer inicio abre **Hexágono de práctica**, con Modo simulación activado.

1. Recorre el diseño con Anterior/Siguiente.
2. En Configuración → Opciones avanzadas, mueve X simulado o toca **Ir al objetivo**.
3. **Animar lectura** vuelve a generar posiciones ficticias.
4. En Calibración, centra una posición y toca **Establecer referencia**.
5. Repite para otros ángulos; cada punto queda guardado inmediatamente.
6. Regresa a Corte: con dos o más puntos se activa la compensación.
7. Cierra y vuelve a abrir: se recuperan trabajo, paso, preferencias, perfiles y último trabajo pendiente.

La simulación conserva la lectura manual y continúa publicándola; no caduca por dejar quieto el slider. La etiqueta Simulación permanece visible en Corte.

## Calibración y coordenadas

Todos los datos se almacenan en **mm**. La opción cm sólo modifica las etiquetas.

- Referencia: X centrado en el primer ángulo medido, normalmente 0°.
- Offset: X medido menos X de referencia.
- Rehacer el punto 0° actualiza también la referencia; los otros valores medidos se conservan.
- Ángulos por defecto: 0, 30, …, 330°. Configurables en Preferencias.
- Se conservan sólo puntos realmente medidos. Un perfil vacío o con un único punto de referencia aún no activa la compensación del trabajo.
- Con dos o más puntos se interpola linealmente entre vecinos, incluido el intervalo que cruza 360°/0°. No se extrapola una tendencia fuera de esos vecinos.
- El mapa es un gráfico radial del **offset X frente a R**. No representa una posición XY. Los valores positivos salen del círculo ideal; los negativos entran.
- Cambiar Dirección X invierte la lectura y las mediciones del perfil, manteniendo su convención coherente. No invierte X nominal del patrón.
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

Importar archivo JSON acepta el objeto completo siguiente. `units` debe ser `mm`, los índices deben ser únicos y el orden del arreglo es el orden de corte. X puede ser negativo; profundidad debe ser finita y no negativa; R entre 0° y 360°.

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

Archivo listo para importar: [examples/fantasy-pattern.json](examples/fantasy-pattern.json).

V90 también envía `cutHelper` v1 con el contorno de referencia, segmentos en mm,
ancho de las ranuras, rueda, distancias con signo y vista inicial. **Abrir Cut Helper**
muestra el visor completo con navegación, Horizontal/Vertical y Volver a 0°.
Ejemplo: [examples/v90-cut-helper.json](examples/v90-cut-helper.json).
Contrato y coordenadas: [guía V90 → MicroFantasy](../docs/microfantasy-lan.md).

## Recepcion local desde V90

Activa Configuracion > V90 Fantasy Designer > Recibir por Wi-Fi y manten la app
abierta. En V90 usa Send to MicroFantasy > Find phone, o introduce la IP del movil.
No hay codigo de enlace. POST /api/v1/jobs acepta JSON sin Authorization y responde
202 para un trabajo pendiente: el usuario decide abrirlo o reemplazar el actual.

Find phone utiliza el ESP32 actualizado como puente. Para descubrir el movil debe
estar conectado al ESP32 (sin simulacion) y con el receptor activo. IP manual
funciona sin ESP32. Chrome/Edge pueden pedir permiso de red local.
Si la red no permite conectar, Download JSON e Importar archivo JSON conservan
el mismo Cut Helper. El receptor solo escucha en primer plano.

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
