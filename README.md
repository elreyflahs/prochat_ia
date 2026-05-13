version actual: Version IA (ProChat IA) V1.0
Un addon para World of warcraft en Wrath of the lich king 3.3. que maneje los mensajes de los canales generales de manera sana y anote al jugador en el buscador de bandas con datos importantes (PESTAÑA LFG), que los lideres de raids puedan comenzar a armar su raid mas rápido y con datos puntuales y necesarios (pestaña LFM), donde una vez tengan armada la raid puedan monitorear la información de la raid que aparece en la ventana de chat como drops, tiempo de drops, reglas, anuncios, links, streams  (Pestaña RAID) y que quede registrado datos importantes del chat como por ejemplo: El Chat de la raid, mensajes del lider, mensajes de looteo, dados (pestaña REG). Todo lo necesario para que la jugabilidad mejore sin tener que dejar de usar el chat que es lo que a predominado durante décadas en 3.3.5
Actualmente en desarrollo


-------------------------------------------------------------
Versiones antiguas
------------------------------------------------------------


# ProChat IA 3.3.5 (v5.2.2)
**Filtro avanzado de chat y buscador de raids para WotLK.**

ProChat IA es una herramienta integral rediseñada desde cero para mejorar la experiencia de búsqueda de grupos (LFG/Raid) en servidores de World of Warcraft: Wrath of the Lich King (3.3.5a).

---

## 🚀 Características Principales

### 🔍 Filtro Avanzado de Chat
- Captura mensajes de canales: General, Comercio, Decir, Gritar, Hermandad y canales personalizados.
- Filtra por **mazmorras**: SR, ICC, TOC, ARCHA, ULDUAR, NAXX, SO, SEMANAL, VIAJEROS, FOSO.
- Filtra por **dificultades**: 10n, 10h, 25n, 25h, 10, 25.
- **Anti-spam**: Límite de tiempo configurable entre mensajes del mismo jugador (30s a 5min).
- **Búsqueda por texto** en tiempo real.
- Colorea mensajes según la mazmorra detectada.
- Muestra la clase del jugador con los colores oficiales de WoW.

### 🛡️ Buscador de Raids
- Panel lateral que agrupa jugadores por mazmorra.
- Listas colapsables/expandibles por mazmorra.
- Click en jugador para susurrar, Shift+Click para insertar nombre, Click derecho para menú contextual.
- Filtro combinado por dificultad y término de búsqueda.

### 🖥️ Interfaz Modular
- **Pestañas**: LFG (búsqueda de grupo), LFM (próximamente), Raid (lista de raids activas).
- **Ventana principal**: Redimensionable, arrastrable y minimizable.
- **Botón en el minimapa**: Arrastrable para reposicionar, acceso rápido a la ventana.
- **Controles**: Dropdowns para canales, mazmorras, tiempo de filtro e idioma.
- **Sliders**: Tamaño de fuente y opacidad de la ventana.
- Modo compacto (minimizado) que conserva el estado de la sesión.

### 💾 Persistencia y Configuración
- Guarda selección de **mazmorras y dificultades** entre sesiones.
- Recuerda posición, tamaño y estado (minimizado/maximizado) de la ventana.
- Guarda opacidad, tamaño de fuente y ángulo del botón del minimapa.
- **Reset completo** con `/pc reset` para restaurar valores predeterminados.

### 🌐 Soporte Multi-Idioma
- Español e Inglés completos.
- Cambio en caliente desde el dropdown de idioma.
- Detección automática del idioma del cliente al iniciar por primera vez.

### 🧠 Detección Inteligente
- Reconoce palabras clave de mazmorras con expresiones regulares (evita falsos positivos).
- Detecta dificultades en múltiples variantes (10n, 10normal, 10 heroico, etc.).
- Caché de clases por jugador para rendimiento optimizado.

### 🛡️ Seguridad en Combate
- Oculta automáticamente la ventana al entrar en combate para evitar distracciones.

---

## 🏗️ Arquitectura Modular

ProChat IA utiliza una estructura de módulos profesionales que mejora el rendimiento, la carga de memoria y la organización del código:

| Archivo | Descripción |
| :--- | :--- |
| `PC-Data.lua` | Gestión centralizada de keywords, colores de clase, dificultades y estado de sesión. |
| `PC-Locales.lua` | Sistema de traducción independiente con soporte dinámico (ES/EN). |
| `PC-Utils.lua` | Funciones lógicas de filtrado, formateo de tiempo, colores y caché de clases. |
| `PC-Frames.lua` | Fábrica de elementos visuales (ventanas, pestañas, botones, sliders). |
| `PC-Core.lua` | Cerebro del addon: inicialización, eventos, dropdowns y lógica de UI. |
| `ProChat IA.lua` | Punto de entrada principal. |

---

## 🛠️ Comandos de Chat

| Comando | Acción |
| :--- | :--- |
| `/pc` | Abre o cierra el panel principal de ProChat IA. |
| `/ProChat IA` | Alias del comando principal. |
| `/pc reset` | **Hard Reset:** Restablece ventanas, tamaños, posiciones y muestra el panel de bienvenida. |

---

## 📦 Instalación

1. Descarga el repositorio o la carpeta del addon.
2. Asegúrate de que la carpeta dentro de `Interface/AddOns/` se llame exactamente **`ProChat IA`**.
3. Estructura de archivos requerida:


---

## 👨‍💻 Créditos

- **Desarrollador:** [El Rey Flahs](https://github.com/elreyflahs)
- **Plataforma:** WoW WotLK 3.3.5a (API Blizzard Legacy)
- **Repositorio:** [github.com/elreyflahs/ProChat IA](https://github.com/elreyflahs/ProChat IA)

---

### 📝 Nota del Desarrollador
Esta versión **5.2.2** incluye una auditoría completa de código con mejoras significativas de rendimiento, eliminación de redundancias y corrección de bugs. Se recomienda usar `/pc reset` tras la instalación para asegurar que la base de datos funcione correctamente.


# ProChat IA 3.3.5 (v5.0.8)
**Filtro avanzado de chat y buscador de bandas para WotLK.**

ProChat IA es una herramienta integral rediseñada desde cero para mejorar la experiencia de búsqueda de grupos (LFG/Raid) en servidores de World of Warcraft: Wrath of the Lich King. 

---

## 🚀 Novedades en la Versión 5.0.1

### 🏗️ Nueva Arquitectura Modular
Se ha abandonado el sistema de archivo único para pasar a una **Estructura de Módulos Profesionales**. Esto mejora drásticamente el rendimiento, la carga de memoria y la organización del código:
* **`PC-Data.lua`**: Gestión centralizada de keywords, colores de clase y base de datos de sesión.
* **`PC-Locales.lua`**: Sistema de traducción independiente con soporte dinámico.
* **`PC-Utils.lua`**: Funciones lógicas de filtrado, formateo de tiempo y cache de clases.
* **`PC-Frames.lua`**: Fábrica de elementos visuales (MainWindow, Credits, Minimap).
* **`PC-Core.lua`**: Cerebro del addon, inicialización y gestión de eventos.


### 🔍 Buscador y Filtros Avanzados
* **Auto-Focus de Búsqueda:** El cuadro de texto captura el foco automáticamente para una experiencia más fluida.
* **Limpieza Rápida:** Soporte para la tecla `ENTER` para limpiar el término de búsqueda y liberar el teclado.
* **Filtro de Spam:** Algoritmo mejorado que evita la repetición de mensajes en un intervalo de tiempo configurable.

---

## 🛠️ Comandos de Chat

| Comando | Acción |
| :--- | :--- |
| `/pc` | Abre o cierra el panel principal de ProChat IA. |
| `/ProChat IA` | Alias del comando principal. |
| `/pc reset` | **Hard Reset:** Restablece ventanas, posiciones y muestra el panel de bienvenida. |

---

## 📦 Instalación

1.  Descarga el repositorio o la carpeta del addon.
2.  Asegúrate de que la carpeta dentro de `Interface/AddOns/` se llame exactamente **`ProChat IA`**.
3.  Estructura de archivos requerida:
    - `ProChat IA.toc`
    - `PC-Data.lua`
    - `PC-Locales.lua`
    - `PC-Utils.lua`
    - `PC-Frames.lua`
    - `PC-Core.lua`
    - `ProChat IA.lua`

---

## 👨‍💻 Créditos
* **Desarrollador:** [El Rey Flahs](https://github.com/elreyflahs)
* **Plataforma:** WoW WotLK 3.3.5a (API Blizzard Legacy)
* **Repositorio:** [github.com/elreyflahs/ProChat IA](https://github.com/elreyflahs/ProChat IA)

---

### 📝 Nota del Desarrollador
Esta versión **5.0.1** es una actualización crítica. Se recomienda usar `/pc reset` tras la instalación para limpiar residuos de versiones antiguas y asegurar que la nueva base de datos modular funcione correctamente.



223 El Ojo de la Eternidad 2
224 El Sagrario Obsidiana 2
227 Naxxramas 2
237 El Ojo de la Eternidad 2
238 El Sagrario Obsidiana 2
239 La Cámara de Archavon 2
240 La Cámara de Archavon 2
243 Ulduar 2
244 Ulduar 2
246 Prueba del Cruzado 2
247 Prueba del Gran Cruzado 2
248 Prueba del Cruzado 2
250 Prueba del Gran Cruzado 2
253 Foso de Saron 2
254 Foso de Saron 2
257 Guarida de Onyxia 2
279 Ciudadela de la Corona de Hielo 2
280 Ciudadela de la Corona de Hielo 2
293 El Sagrario Rubí 2
294 El Sagrario Rubí 2
