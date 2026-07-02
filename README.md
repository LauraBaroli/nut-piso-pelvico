# NUT Piso Pélvico

App de seguimiento del programa de piso pélvico de la **Lic. Laura Baroli** (NUT Kinesiología). Basada en evidencia (Bø 2023, reportes ICS/IUGA, revisiones Cochrane).

Dos roles en una misma app:

- **Paciente** (móvil): rutina del día con guía por círculo (sonido/vibración), diario de síntomas, diario vesical, cuestionarios validados, progreso y consejos personalizados.
- **Lic. Laura** (panel): dashboard de pacientes con alertas, ficha clínica por paciente (evaluación → diagnósticos → evidencia referenciada → tratamiento → seguimiento), programas a medida, mensajería e impresión de ficha.

---

## Arquitectura

- **Front**: HTML + CSS + JS sin build, instalable como **PWA** (funciona offline el "cascarón" de la app; los datos siempre van a la red).
- **Backend**: **Supabase** (Postgres + Auth + RLS). Cada paciente ve solo sus datos; Laura ve y gestiona a sus pacientes.
- **Hosting**: GitHub Pages (estático) + cliente JS de Supabase por CDN.

```
Paciente / Laura ──► index.html (GitHub Pages) ──► Supabase (Auth + Postgres con RLS)
```

### Estructura de archivos

| Archivo | Qué es |
|---|---|
| `index.html` | Documento principal: markup + carga de estilos y scripts. |
| `css/styles.css` | Todos los estilos. |
| `js/config.js` | URL y clave pública de Supabase + init del cliente. |
| `js/core.js` | Utilidades compartidas: `esc()` (escape anti-XSS), modal, toast, accesibilidad por teclado. |
| `js/data.js` | Datos clínicos: programas, tips, antecedentes. |
| `js/engine.js` | Motor clínico: adherencia, alertas, fases, PROMs, evidencia. |
| `js/patient.js` | App de la paciente (módulo `D`). |
| `js/clinic.js` | Panel de Laura (módulo `L`). |
| `js/auth.js` | Login real contra Supabase + persistencia (autosave). |
| `js/pwa.js` | Registro del Service Worker. |
| `manifest.webmanifest` | Metadatos de la PWA (nombre, iconos, colores). |
| `sw.js` | Service Worker (cachea el cascarón; nunca cachea datos de salud). |
| `icons/` | Iconos de la app (192, 512, maskable). |
| `supabase_schema.sql` | Esquema de la base + RLS + seed + **actualización v3** (columnas y RPC que usa la app). |

> Antes todo vivía en un único `index.html` de ~265 KB. Ahora está separado por responsabilidad: más fácil de leer, mantener y revisar. Como GitHub Pages sirve archivos estáticos, no hace falta ningún paso de build.

---

## Puesta en marcha

### 1. Supabase
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, pegar y ejecutar `supabase_schema.sql` (incluye la actualización v3 al final).
3. En **Authentication → Providers**, habilitar **Email**. (Opcional: desactivar "Confirm email" para altas internas.)
4. Crear el usuario de Laura (Authentication → Users) e insertar su fila:
   ```sql
   insert into clinicians (auth_id, name, license)
   values ('<auth_uid_de_laura>', 'Lic. Laura Baroli', 'M.N 13.433');
   ```
5. Copiar de **Project Settings → API**: `Project URL` y `anon public key`.

### 2. Configurar la app
En `js/config.js`, completar con tus valores:
```js
var SB_URL = "https://TUPROYECTO.supabase.co";
var SB_KEY = "TU_ANON_KEY";
```
> La `anon key` es pública por diseño (va en el cliente). **Toda la seguridad real la dan las políticas RLS**: revisá que estén activas antes de cargar datos reales de pacientes.

### 3. Funciones de acceso (blanqueo / alta de logins)
La app llama tres RPC:
- `request_pw_reset(dni)` — incluida en el `.sql` (respuesta uniforme, no revela si el DNI existe).
- `clinician_create_login(pid)` y `clinician_reset_patient_pw(pid, newpw)` — crean/actualizan usuarios de Auth y **requieren la Admin API** (service_role); implementalas como **Edge Functions**. Ver la nota en el `.sql`.

### 4. GitHub + hosting
```bash
git add .
git commit -m "NUT Piso Pélvico — versión curada"
git push
```
En **Settings → Pages**: Source = `main` / root. Queda en `https://<usuario>.github.io/nut-piso-pelvico/`.

---

## Dos accesos separados

- **Pacientes** → enlace normal + usuario y clave:
  `https://laurabaroli.github.io/nut-piso-pelvico/`
- **Laura (panel clínico)** → enlace con el *slug* secreto:
  `https://laurabaroli.github.io/nut-piso-pelvico/#Lauchita1986`

El panel solo se habilita si la URL incluye el slug (definido en `js/config.js` → `PANEL_KEY`, o inline en `index.html`). Si la cuenta de Laura intenta entrar por el enlace de pacientes, la app la redirige a usar el enlace del panel. **Cambien el slug** por uno que solo Laura y ustedes conozcan.

> Nota honesta: el slug vive en el JS del cliente, así que alguien que lea el código fuente podría encontrarlo. Es una barrera contra el acceso casual, no un secreto criptográfico. La protección real la dan la **clave de Laura** + las **políticas RLS** de Supabase. Para una separación fuerte de verdad haría falta ruteo/auth del lado del servidor.

Desde el panel, Laura tiene **"Ver como paciente"** en la ficha para previsualizar la app tal como la ve esa paciente (sin guardar cambios).

---

## Seguridad y privacidad (datos de salud)

- **Login obligatorio**: no hay modo demo abierto. Si el backend no responde, la app muestra un aviso y **nunca** el contenido.
- **Anti-XSS**: todo texto de paciente/clínica se escapa con `esc()` antes de mostrarse (evita que una nota del diario ejecute código en la sesión de Laura).
- **Blanqueo de clave sin filtración**: la respuesta al pedir blanqueo por DNI es siempre la misma.
- **Claves transitorias fuertes**: generadas con `crypto.getRandomValues` (no `NUT+4 dígitos`).
- **Errores visibles**: si el servidor rechaza guardar/borrar, la app lo informa (no simula éxito).

---

*Borrador clínico para validación de la Lic. Laura Baroli · NUT Kinesiología.*
