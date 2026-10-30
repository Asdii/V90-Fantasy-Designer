# Actualizaciones de MicroFantasy desde GitHub

## Uso diario

Un **push a `main`** activa `Publish MicroFantasy Android`. Un commit que permanece
sólo en tu ordenador no activa GitHub Actions. Si un push contiene varios commits,
el APK incluye el estado final de ese push.

```bat
git add .
git commit -m "Describe los cambios"
git push origin main
```

Cuando el workflow termina correctamente, publica una Release con:

- `microfantasy.apk`, compilado en modo release y firmado;
- `microfantasy-update.json`, con versión, enlace, SHA-256 y certificado de firma.

MicroFantasy consulta el manifiesto público, sin token del usuario. Busca como
máximo una vez al día al abrir/regresar a la app. **Configuración → Actualizaciones
→ Buscar actualizaciones** comprueba inmediatamente. El aviso permite Actualizar
o Más tarde. Se puede desactivar la búsqueda automática.

**Actualizar** abre la descarga oficial en el navegador del teléfono. Abre el APK
descargado y confirma **Actualizar** en Android; puede pedir permiso para instalar
desde ese navegador. No se instala en silencio y no es necesario desinstalar la
app. Los trabajos y calibraciones permanecen en su almacenamiento habitual.

La búsqueda necesita internet, no conexión con ESP32 ni estar en la misma LAN.
Los errores de red no bloquean el corte. Las actualizaciones APK sólo aplican a
Android; iOS necesita su propio canal de distribución (no instala APK).

## Primera instalación con actualizador

El APK anterior no conoce esta función. Instala una vez el APK nuevo generado en:

`microfantasy/build/app/outputs/flutter-apk/app-release.apk`

Esta versión inicial usa `1.0.0+2`; su código es superior al APK anterior (`+1`).
Después puede detectar las versiones publicadas automáticamente.

## Configurar la firma una sola vez

Android exige mantener el identificador y la firma para actualizar la misma
instalación. El proyecto conserva `app.microfantasy.microfantasy`.
Los APK de pruebas ya generados usan la clave local de desarrollo de este equipo.
El script puede guardar **esa misma clave**, cifrada como secreto de GitHub Actions,
para conservar la compatibilidad. No la añade al repositorio ni la publica.

Desde la raíz del proyecto, en PowerShell:

```powershell
# Sólo comprobar: no cambia secretos.
.\microfantasy\tool\setup-github-updates.ps1 -CheckOnly

# Con autorización del propietario, configura los secretos cifrados.
.\microfantasy\tool\setup-github-updates.ps1
```

El script usa GitHub CLI instalado o la copia local en `outputs/toolchains/gh/bin`.
Puede utilizar la sesión existente de Git HTTPS en memoria. Si no hay sesión:

```powershell
winget install --id GitHub.cli --exact
gh auth login --hostname github.com --web
```

El destino es únicamente `Asdii/V90-Fantasy-Designer`, con acceso de escritura y
Releases públicas. Se crean cuatro secretos de Actions:

```text
MICROFANTASY_KEYSTORE_BASE64
MICROFANTASY_STORE_PASSWORD
MICROFANTASY_KEY_PASSWORD
MICROFANTASY_KEY_ALIAS
```

Y una variable pública `MICROFANTASY_SIGNING_SHA256` con la huella del certificado.
El script comprueba la clave antes de subirla y se niega a reemplazar una identidad
de firma distinta ya registrada. Conserva además una copia segura de tu keystore:
los secretos de GitHub no permiten descargar su valor posteriormente.

Para una clave propia existente, admite `-Keystore` y `-KeyAlias`, con contraseñas
en `MICROFANTASY_SETUP_STORE_PASSWORD` / `MICROFANTASY_SETUP_KEY_PASSWORD`.
**No generes una clave distinta para actualizar los APK ya instalados.** La clave
local de pruebas se conserva aquí por compatibilidad; una distribución futura por
tienda requerirá planificar la firma adecuada, sin cambiarla improvisadamente.

## Publicación y verificaciones

El workflow prueba Dart/Flutter y los metadatos, construye un APK universal y
comprueba con las herramientas Android que:

- no sea depurable;
- el identificador y la versión coincidan;
- la firma sea válida y coincida con la huella configurada.

La Release se crea primero como borrador. Se adjuntan ambos archivos antes de
marcarla publicada/latest. Si la compilación o validación falla, la versión anterior
sigue disponible. No se sustituyen ni borran APK publicados anteriormente.

`versionCode` usa segundos desde 2020, dentro del rango Android, para aumentar
incluso tras un rebase o un cambio del contador del workflow. La versión visible
es `1.0.<número de ejecución>`. No necesitas editar `pubspec.yaml` en cada commit.
La app compara el código numérico, evita downgrades y rechaza ofertas con otra firma.

El SHA-256 del APK se publica para verificación manual; la app entrega la descarga
al navegador y Android verifica su firma durante la instalación. La app no afirma
haber calculado el hash del APK descargado por otra aplicación.

Sin los secretos y la huella, el workflow falla explícitamente antes de compilar;
nunca publica un APK firmado con una nueva clave aleatoria del runner.

## Pruebas locales

```powershell
cd microfantasy
dart analyze lib test tool
flutter test
python -m unittest discover -s tool -p '*_test.py'
flutter build apk --release
```

No hay un teléfono físico conectado en este entorno; queda verificar en Android
el permiso de instalación del navegador y la actualización desde una Release real
después del primer push y la configuración autorizada de firma.

Documentación oficial: [firma Android](https://developer.android.com/studio/publish/app-signing),
[publicación Flutter](https://docs.flutter.dev/deployment/android),
[secretos con GitHub CLI](https://cli.github.com/manual/gh_secret_set).
