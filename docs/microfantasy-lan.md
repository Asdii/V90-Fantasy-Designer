# V90 → MicroFantasy: trabajo y Cut Helper por LAN

## Uso

1. Instala el APK actualizado de `microfantasy/build/app/outputs/flutter-apk/app-release.apk`.
2. Conecta ordenador y móvil a la misma red. Mantén MicroFantasy abierta.
3. En el móvil: **Configuración → V90 Fantasy Designer → Recibir por Wi-Fi**. Copia la dirección y el código de enlace.
4. En V90, realiza los cortes con **Create Cuts**. **Send to MicroFantasy** aparece en la cabecera y dentro del Cut Helper. Envía las operaciones ya creadas, en el mismo orden del ayudante.
5. Introduce la dirección del móvil y el código. Si el sensor no marca cero en el centro de referencia, introduce su lectura en **X at the facet center (mm)**.
6. Pulsa **Send Cut Helper**. Acepta **Abrir** en MicroFantasy; el trabajo anterior no se reemplaza sin esa acción.
7. En Corte, **Abrir Cut Helper** muestra el visor completo. Anterior/Siguiente, Horizontal/Vertical y Volver a 0° funcionan también en el móvil.

Al enviar desde el propio Cut Helper se conservan el paso, la dirección y la orientación actuales. Desde la cabecera se inicia en el primer paso, horizontal, orientado al corte. El progreso posterior y la vista se guardan en el móvil.

La dirección se recuerda en el navegador; el código no se guarda. Al desactivar el receptor o poner la app en segundo plano se invalida el enlace. Reactiva la recepción para obtener otro código.

## Navegador y red

El envío usa HTTP local autenticado con un código temporal, sin servidor de nube. El navegador no puede buscar libremente dispositivos mediante mDNS: introduce la dirección mostrada por el móvil. Redes de invitados, aislamiento Wi-Fi, VPN y cortafuegos pueden impedir la conexión.

Chrome/Edge actuales pueden pedir permiso de **red local** al conectar desde una página HTTPS, incluida GitHub Pages. El cliente declara `targetAddressSpace` y el receptor responde a CORS/preflight. El permiso y las restricciones de contenido mixto dependen del navegador; no se desactivan protecciones del equipo. Véase la [documentación de Local Network Access](https://developer.chrome.com/docs/modern-web-guidance/guides/security/local-network-access).

Si el navegador bloquea la LAN, **Download JSON** genera exactamente el mismo trabajo con todo el Cut Helper. Transfiere el archivo e impórtalo desde Configuración en MicroFantasy. La recepción por red requiere la app nativa Android/iOS, no la versión web de simulación.

## Coordenadas compartidas

La secuencia se calcula una sola vez mediante `buildCutHelperSequence`. Todas las operaciones se expresan en la faceta de referencia inicial, conservando su origen; no se recentran usando el bounding box.

- Coordenadas locales en mm: +U derecha, +V arriba.
- Ángulo R: el mismo ángulo 0–360° del Cut Helper de V90.
- Distancia visible: distancia perpendicular **absoluta** al centro, igual que V90.
- Posición X: conserva el **lado** del corte. Para una línea orientada A→B, `signedDistance = (A.u * dv - A.v * du) / length`.
- `step.x = machineCenterXmm + signedDistanceMm`. MicroFantasy aplica después `offsetX(R)` de su calibración, una única vez.

El visor móvil conserva la geometría local, la escala relativa, el contorno, los segmentos visibles, el ancho de ranura, la rueda con 0° abajo, los cortes anteriores, la flecha actual y las animaciones de orientación. Es un visor 2D nativo Flutter, no una gema 3D ni una imagen estática. La tipografía y los controles se adaptan al teléfono.

## Contrato v1

Ejemplo completo compartido por las pruebas TypeScript y Dart: [v90-cut-helper.json](../microfantasy/examples/v90-cut-helper.json).

Se mantienen los campos básicos `jobId`, `name`, `units: "mm"`, `steps: [{index, angleR, x, depth}]`. Se añade:

```text
cutHelper:
  version: 1
  coordinateSystem: "facet-local-mm-y-up"
  referenceFacetId
  boundary: [{u, v}, ...]
  viewport: {extent, wheelRadius, hairline}
  initialView: {stepIndex, direction, orientation}
  machineCenterXmm
  steps:
    [{index, operationId, operationNumber,
      distanceFromCenterMm, signedDistanceMm, grooveWidthMm,
      segment: {start: {u,v}, end: {u,v}},
      visibleSegments: [{start: {u,v}, end: {u,v}}, ...]}]
```

`stepIndex` es cero-based; `index` es uno-based y coincide en ambos arreglos. `direction`: horizontal/vertical. `orientation`: cut/zero. `segment` conserva la trayectoria orientada; `visibleSegments` conserva los tramos que V90 muestra sobre la faceta. El receptor verifica posiciones finitas, correspondencia de pasos, ángulos y distancias. No acepta una versión incompatible ni sustituye silenciosamente el visor por otro esquema.

### Recepción

`GET /api/v1/status` anuncia `service: "microfantasy"`, `api_version: 1`, `accepting_jobs: true`, `cut_helper_versions: [1]` y `max_job_bytes` (por defecto 1 MiB). Una app antigua necesita actualizarse antes de aceptar el envío completo.

`POST /api/v1/jobs` recibe el JSON con `Content-Type: application/json` y `Authorization: Bearer <código>`. Respuesta 202: `{"status":"pending","job_id":"...","cut_helper_version":1,"pending_count":1}`. Esto confirma recepción, no reemplazo del trabajo abierto.

La app usa `LocalReceiverService(allowBrowserPairing: true)`: permite comprobar disponibilidad desde un origen HTTP(S), pero solamente un envío autenticado y válido vincula ese origen a la sesión. Otro origen requiere reactivar el receptor. Sin esa opción, el servicio continúa aceptando únicamente orígenes explícitos mediante `allowedOrigins`.

## Verificación

- Tests V90: exportación exacta, dos operaciones con distintos orígenes, distancias con signo, capacidades, autenticación y manejo de fallos.
- Tests MicroFantasy: deserialización del mismo fixture, recepción HTTP real en loopback, CORS, rechazo de datos inconsistentes, controles del visor y recuperación de progreso.
- Prueba manual: crear un corte desde V90, enviarlo desde el navegador y recibirlo con el mismo servicio nativo (`dart run tool/receiver_probe.dart`, sólo loopback). El resultado se guarda en `microfantasy/build/qa/browser-received-job.json`.
- Captura móvil opcional: `flutter test --update-goldens tool/visual_check_test.dart`.

La prueba en un teléfono físico sobre Wi-Fi y el permiso de acceso LAN desde GitHub Pages deben verificarse en los dispositivos del usuario. La compilación iOS requiere macOS/Xcode.
