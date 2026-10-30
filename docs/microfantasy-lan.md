# V90 → MicroFantasy: trabajo y Cut Helper por LAN

## Uso

1. Actualiza firmware, app y V90. Conecta ordenador y movil a la misma LAN.
2. En MicroFantasy activa Configuracion > V90 Fantasy Designer > Recibir por Wi-Fi.
3. Crea cortes en V90 y abre Send to MicroFantasy.
4. Usa Find phone o introduce la IP del movil. No se necesita codigo.
5. Si X no marca cero en el centro de referencia, introduce esa lectura en
   X at the facet center (mm). Envia y pulsa Abrir en el movil.

La direccion se recuerda. Los trabajos llegan pendientes, sin reemplazar el actual.
El receptor se pausa en segundo plano. El Cut Helper conserva geometria, pasos y
orientacion al enviarlo desde su ventana.

## Navegador y red

Find phone consulta http://fantasy-machine.local/api/v1/apps en el ESP32 y
verifica los receptores candidatos. Tambien prueba la direccion recordada.
Si hay varios telefonos permite elegir uno. Buscar no envia trabajos.
Para descubrir el movil debe estar abierto, conectado al ESP32 (sin simulacion)
y recibiendo por Wi-Fi. La IP manual funciona tambien sin ESP32.
El navegador no explora mDNS libremente ni se escanea toda la LAN: se utiliza
el ESP32 como puente. Requiere resolver su hostname y permiso de red local.

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

POST /api/v1/jobs recibe JSON con Content-Type: application/json sin Authorization.
Responde 202 con status pending: confirma recepcion, no reemplazo del trabajo.
La app utiliza LocalReceiverService(allowBrowserAccess: true), permite origenes
HTTP(S) sin vincularlos a sesiones y anuncia pairing_required: false.
El constructor mantiene el modo restringido por defecto mediante allowedOrigins.
Se conservan limites, validacion y la cola de trabajos pendientes.

## Verificación

- Tests V90: exportación exacta, dos operaciones con distintos orígenes, distancias con signo, capacidades, descubrimiento y manejo de fallos.
- Tests MicroFantasy: deserialización del mismo fixture, recepción HTTP real en loopback, CORS, rechazo de datos inconsistentes, controles del visor y recuperación de progreso.
- Prueba manual: crear un corte desde V90, enviarlo desde el navegador y recibirlo con el mismo servicio nativo (`dart run tool/receiver_probe.dart`, sólo loopback). El resultado se guarda en `microfantasy/build/qa/browser-received-job.json`.
- Captura móvil opcional: `flutter test --update-goldens tool/visual_check_test.dart`.

La prueba en un teléfono físico sobre Wi-Fi y el permiso de acceso LAN desde GitHub Pages deben verificarse en los dispositivos del usuario. La compilación iOS requiere macOS/Xcode.
