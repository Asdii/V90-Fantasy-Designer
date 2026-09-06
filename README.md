# Fantasy Cutting Designer

Etapa actual: Pattern Designer 2D independiente, Pattern Placement sobre faceta y base visual optica de gema en Gem Preview.

## Stack elegido

- Vite + React + TypeScript para una aplicacion web local rapida de desarrollar.
- Three.js como renderer 3D inicial.
- Modelo geometrico propio en `src/geometry`, independiente de Three.js.

La decision evita acoplar el dominio a `THREE.Mesh`. Los datos importantes viven en tipos como `GemGeometry`, `Plane`, `Facet` y `CoordinateSystem`; `GemRenderer` solo adapta esos datos a buffers visuales de Three.js.

## Unidades y precision

- La unidad interna del proyecto es milimetro: `1 unit = 1 mm`.
- Los datos de dominio usan `number` de JavaScript, que es double precision.
- El render WebGL usa buffers `Float32Array` porque esa es la representacion esperada por GPU. Esa conversion queda aislada dentro del adaptador de rendering.

## Estructura

```text
src/
  app/
  geometry/
  rendering/
  interaction/
  patterns/
  grooves/
  materials/
  project/
  ui/
```

## Funcionalidad actual

- Viewport 3D con camara.
- Controles orbitales con rotacion, pan y zoom.
- Grid, ejes XYZ y origen.
- Geometria placeholder low-poly tipo gema.
- Importacion STL ASCII y binaria.
- Vertex welding con tolerancia `1e-6 mm`.
- Normales geometricas recalculadas desde vertices; no se confia en normales STL.
- Bounding box, dimensiones, centro, edges, facetas y advertencias geometricas.
- Deteccion de facetas mediante componentes conectados coplanares.
- Adjacency por edges para evitar comparaciones triangulo contra triangulo.
- Tolerancia angular de facetas: `0.1 deg`.
- Tolerancia de plano de facetas: `1e-5 mm`.
- Deteccion de open edges, non-manifold edges e inconsistencias potenciales de winding.
- Reset camera y vistas Top, Bottom, Front, Back, Left, Right.
- Modo Perspective y Orthographic.
- Fit to model sin escalar ni recentrar coordenadas geometricas.
- Cambio de fondo: Black, Dark gray, Light gray, White.
- Wireframe opcional sobre render solido.
- Boundaries de facetas opcionales, mostrando solo bordes externos de cada faceta.
- Colores debug opcionales por faceta.
- Seleccion interactiva de facetas completas mediante raycast.
- Hover sutil de faceta y seleccion persistente por click.
- Highlight, boundary destacado, marcador de centroide y flecha de normal para la faceta seleccionada.
- Panel numerico de faceta seleccionada.
- Sistema local fisico por faceta seleccionada: `FacetFrame` con U/V/N en milimetros.
- Transformaciones `localToWorld` y `worldToLocal`.
- Boundary convertido a coordenadas locales y bounds U/V.
- Helper visual U/V/N y workplane local opcional con grid en escala mm.
- Dos espacios principales mediante tabs: `Pattern Designer` y `Gem Preview`.
- Pattern Designer 2D independiente del STL, con SVG, grid, ejes X/Y, origen, zoom, pan y coordenadas del cursor en mm.
- Viewport 2D full-size con `ResizeObserver`, origen inicial centrado y transformacion centralizada `worldToScreen` / `screenToWorld`.
- Pan en pixeles de pantalla y zoom hacia el cursor, conservando el punto world bajo el mouse.
- Fit Pattern y Reset View para ajustar o restaurar la camara 2D sin modificar geometria.
- Modelo matematico nuevo para primitives: line, polyline, circle y arc.
- Construction geometry separada de Pattern geometry.
- Conversion `patternToCutPaths()` que excluye construction geometry.
- `normalizePattern()` para obtener una representacion centrada/escalada sin mutar el diseno original.
- Snap del editor 2D a grid, endpoints, intersections y centros.
- Herramientas 2D: Select, Line, Polyline, Circle, Arc y Regular Polygon contextual.
- Seleccion simple y multiple con Shift+click.
- Copy, paste, duplicate y delete para primitives seleccionadas.
- Move por drag y transform contextual con translate, rotation y scale.
- Mirror X/Y y Radial Duplicate como operaciones sobre seleccion.
- Simetria radial contextual mientras se dibuja.
- Panel colapsable `Pattern Data` para inspeccionar primitives matematicas.
- Gem Preview conserva STL, camara, seleccion de facetas y controles visuales basicos, sin generadores de patron alrededor del viewport.
- Pattern Placement conecta el `DesignPattern` global con la faceta seleccionada mediante `PatternPlacement`, sin modificar el patron original.
- Preview 3D del patron sobre la faceta seleccionada con offset normal visual y clipping inside/outside contra el boundary local.
- Preparacion de `WorldCutPath[]` desde `patternToCutPaths()` -> placement -> clipping -> `FacetFrame.localToWorld()`.
- Presets de material de gema: Quartz, Sapphire, Topaz, Spinel, Cubic Zirconia y Custom.
- Material optico inicial basado en `THREE.MeshPhysicalMaterial` con `transmission`, `ior`, `roughness`, flat shading y environment procedural.
- Lighting presets: Studio Light, Dark Studio y Neutral.
- Status bar con posicion de camara, target, objetos y FPS.

## Seleccion de facetas

El render mesh mantiene el mismo orden que `GemGeometry.triangles`: cada triangulo de dominio se expande como una cara no indexada consecutiva. Por eso `THREE.Intersection.faceIndex` se interpreta como indice de triangulo de dominio y luego se resuelve con `triangleToFacet`, una tabla `Int32Array` O(1).

La seleccion es estado de interaccion (`selectedFacetId`, `hoveredFacetId`). No modifica `GemGeometry`.

## Frame local de faceta

`FacetFrame.origin` usa el centroide de la faceta. `normal` usa la normal detectada. `uAxis` se elige de forma deterministica desde el boundary edge exterior mas largo; en empates se usa una clave lexicografica de coordenadas de endpoints y la direccion va del endpoint lexicograficamente menor al mayor. Si no hay boundary util, se proyecta sobre el plano el eje global menos paralelo a la normal.

La base se reconstruye como `V = normalize(N x U)` y `U = normalize(V x N)`, garantizando `U x V = N` dentro de tolerancia numerica.

## Pattern Designer 2D

El patron principal vive como `DesignPattern` en `src/patterns/model/PatternModel.ts`. No requiere STL, faceta ni `GemGeometry`.

Las primitives son geometria matematica:

- `LinePrimitive`: segmento A -> B.
- `PolylinePrimitive`: path piecewise abierto o cerrado.
- `CirclePrimitive`: centro + radio.
- `ArcPrimitive`: centro + radio + angulos.

SVG se usa solamente como superficie de interaccion/render 2D. La fuente de verdad no es SVG ni pixels.

El viewport 2D usa `PatternViewportState` en `src/patterns/editor/PatternViewport.ts`:

- `zoom`: pixeles por milimetro.
- `panX` / `panY`: desplazamiento visual en pixeles.
- `width` / `height`: tamano real del SVG observado.

Todas las herramientas convierten primero `clientX/clientY` a coordenadas locales del SVG usando `getBoundingClientRect()` y luego llaman a `screenToWorld()`. Esto evita depender de la posicion DOM del editor dentro de tabs, toolbars o paneles.

La prioridad de snap es: endpoints, intersections, centers, grid, raw cursor. Las tolerancias de hit testing y snap se derivan de pixeles mediante `pixelTolerance / zoom`.

La salida futura hacia cortes se prepara mediante `patternToCutPaths(pattern)`, que devuelve solo paths finales de Pattern geometry y excluye construction geometry.

## Pattern Placement

`PatternPlacement` vive en `src/patterns/placement/PatternPlacement.ts` y contiene:

- `facetId`
- `offsetX`
- `offsetY`
- `rotationDeg`
- `scale`

Los puntos del patron se transforman a coordenadas locales de faceta en el momento de preview/export de paths. El patron matematico original no cambia al centrar, rotar, escalar o ajustar a la faceta.

`patternPlacementToWorldCutPaths()` prepara la salida de la proxima etapa: paths 3D recortados a la faceta, todavia sin generar ranuras ni booleanas.

## Gem Material

`GemMaterial` vive en `src/materials/GemMaterial.ts`. El renderer usa `MeshPhysicalMaterial` con `ior` real del preset seleccionado. Esto produce una aproximacion interactiva de transparencia, refraccion y Fresnel del shader de Three.js, pero no sustituye un ray tracer fisico ni modela Total Internal Reflection con precision de fabricacion.

## Fuera de alcance en esta etapa

No se implementa V-grooves, ancho fisico de corte, profundidad, boolean subtraction, ray-traced final render, dispersion espectral fisicamente precisa ni exportacion CNC.

## Comandos

```bash
npm install
npm test
npm run build
npm run dev
```

`npm run dev` compila y sirve el build local en:

```text
http://127.0.0.1:3000/
```

Nota: el modo HMR nativo de Vite no se usa en esta etapa porque el optimizador de dependencias de Vite/esbuild falla bajo el sandbox actual de Windows al intentar leer rutas superiores restringidas. El build y preview local estan verificados.
# Publicación en GitHub Pages

El proyecto incluye un workflow en `.github/workflows/deploy-pages.yml`. Cada
push a la rama `main` ejecuta los tests, construye la aplicación y publica el
contenido de `dist` en GitHub Pages.

1. Crea un repositorio en GitHub y sube este proyecto a la rama `main`.
2. En GitHub abre `Settings > Pages`.
3. En `Build and deployment`, selecciona `GitHub Actions` como fuente.
4. Abre `Actions` y ejecuta `Deploy Fantasy Cutting Designer to GitHub Pages`,
   o realiza un nuevo push a `main`.

El build usa rutas relativas. Funciona tanto en
`https://usuario.github.io/repositorio/` como en un repositorio especial
`usuario.github.io` publicado desde la raíz.

Para verificar localmente la misma compilación:

```bash
npm ci
npm test
npm run build
npm run build:pages
npm run preview
```
