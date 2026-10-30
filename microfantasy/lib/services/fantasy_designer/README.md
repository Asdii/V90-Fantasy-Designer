# Recepcion V90 por LAN

LocalReceiverService(port: 8787, allowBrowserAccess: true) escucha en primer plano.
No necesita token ni codigo de enlace.

- GET /api/v1/status: capacidades y pairing_required: false.
- POST /api/v1/jobs: JSON con Content-Type application/json, sin Authorization.
  Responde 202 y deja el trabajo pendiente sin reemplazar el actual.
- OPTIONS: preflight CORS y acceso a red privada.
- allowBrowserAccess: false limita los origenes a allowedOrigins.
- Limites: 1 MiB, 10 propuestas y 10 segundos para recibir el cuerpo.

La interfaz separa ciclo de vida, endpoints y cola de la UI. Al salir de primer
plano se cierra el receptor. V90 descubre candidatos mediante el ESP32 y verifica
su servicio; IP manual sigue disponible sin hardware.

Ver [contrato y uso](../../../../../docs/microfantasy-lan.md).
