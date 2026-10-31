# Paletas de MicroFantasy

Las paletas se adaptan a tarjetas, controles y texto de Material. No se añaden
dependencias ni recursos externos en tiempo de ejecución. Los colores base se
tomaron de las fuentes oficiales siguientes; los contenedores y bordes se derivan
localmente y el texto sobre los botones se elige según el contraste.

| Nombre visible | Identificador guardado | Base / superficie / acento | Fuente |
| --- | --- | --- | --- |
| Claro | `light` | `#F6F8FA` / `#FFFFFF` / `#0969DA` | Paleta neutra de la app |
| Oscuro | `dark` | `#000000` / `#0A0A0A` / `#FFFFFF` | Paleta monocroma de la app |
| Midnight | `midnight` | `#1A1B26` / `#24283B` / `#7AA2F7` | [Tokyo Night](https://github.com/folke/tokyonight.nvim), colores Night y Storm |
| Solarized Light | `atelier` | `#EEE8D5` / `#FDF6E3` / `#268BD2` | [Solarized](https://ethanschoonover.com/solarized/) |
| Nord | `lagoon` | `#2E3440` / `#3B4252` / `#88C0D0` | [Nord](https://www.nordtheme.com/docs/colors-and-palettes/) |
| Catppuccin Latte | `porcelain` | `#E6E9EF` / `#EFF1F5` / `#1E66F5` | [Catppuccin](https://catppuccin.com/palette/) |
| Dracula | `amethyst` | `#282A36` / `#44475A` / `#BD93F9` | [Dracula](https://draculatheme.com/contribute) |
| Gruvbox Light | `sunstone` | `#EBDBB2` / `#FBF1C7` / `#AF3A03` | [Gruvbox](https://github.com/morhetz/gruvbox), variante clara |
| Nord Light | `arctic` | `#E5E9F0` / `#ECEFF4` / `#4C566A` | [Nord](https://www.nordtheme.com/docs/colors-and-palettes/), Snow Storm y Polar Night |

Claro, Oscuro y Midnight son las tres primeras opciones. Claro es el valor inicial
cuando todavía no hay preferencia guardada. Se conservan los identificadores
anteriores para cargar configuraciones existentes, aunque cambie el nombre visible.

Oscuro usa negro puro en el fondo, blanco puro en textos principales y botones
primarios, con texto negro sobre estos botones. El resto de las paletas conserva
sus acentos originales. En Dracula el texto secundario usa Foreground en lugar
de Comment, para mantener contraste en las tarjetas.

El verde de confirmación y la línea negra del sensor siguen teniendo significado
funcional en todos los temas. La selección de tema no cambia las lecturas,
tolerancias ni objetivos de corte.
