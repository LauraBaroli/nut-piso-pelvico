# NUT Piso Pélvico

App de seguimiento del programa de piso pélvico de la **Lic. Laura Baroli** (NUT Kinesiología). Basada en evidencia (Bø 2023, reportes ICS/IUGA, revisiones Cochrane).

Dos roles en una misma app:

- **Paciente** (móvil): rutina del día con guía por círculo (sonido/vibración), diario de síntomas, diario vesical, cuestionarios validados, progreso y consejos personalizados.
- **Lic. Laura** (panel): dashboard de pacientes con alertas, ficha clínica por paciente (evaluación → diagnósticos → evidencia referenciada → tratamiento → seguimiento), programas a medida, mensajería e impresión de ficha.

---

## Arquitectura

- **Front**: una sola página HTML/CSS/JS (`index.html`), sin build, instalable como PWA.
- **Backend**: **Supabase** (Postgres + Auth + RLS). Cada paciente ve solo sus datos; Laura ve y gestiona a sus pacientes.
- **Hosting**: GitHub Pages (estático) usando el cliente JS de Supabase por CDN.

```
Paciente / Laura  ──►  index.html (GitHub Pages)  ──►  Supabase (Auth + Postgres con RLS)
```

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | La aplicación completa (renombrar desde `app_nut.html`). |
| `supabase_schema.sql` | Esquema de la base + Row Level Security + seed de catálogos. |
| `README.md` | Este documento. |

---

## Puesta en marcha

### 1. Supabase
1. Crear un proyecto en [supabase.com](https://supabase.com) (o dejá que lo cree el asistente con el conector).
2. En **SQL Editor**, pegar y ejecutar `supabase_schema.sql`. Crea las tablas, las políticas RLS y carga las 9 patologías.
3. En **Authentication → Providers**, habilitar **Email** (clave). (Opcional: desactivar "Confirm email" para altas internas.)
4. Crear el usuario de Laura (Authentication → Users) e insertar su fila de clínica:
   ```sql
   insert into clinicians (auth_id, name, license)
   values ('<auth_uid_de_laura>', 'Lic. Laura Baroli', 'M.N 13.433');
   ```
5. Copiar de **Project Settings → API**: `Project URL` y `anon public key`.

### 2. Configurar la app
En `index.html`, completar el bloque de configuración con tu `Project URL` y tu `anon key`:
```js
const SUPABASE_URL = "https://TUPROYECTO.supabase.co";
const SUPABASE_ANON_KEY = "TU_ANON_KEY";
```
> La integración de datos (lectura/escritura contra Supabase) se está cableando entidad por entidad; mientras tanto la app corre con datos de demo en memoria.

### 3. GitHub + hosting
```bash
git init
git add .
git commit -m "NUT Piso Pélvico — primera versión"
git branch -M main
git remote add origin https://github.com/<tu-usuario>/nut-piso-pelvico.git
git push -u origin main
```
Luego en **Settings → Pages**: Source = `main` / root. Queda publicada en
`https://<tu-usuario>.github.io/nut-piso-pelvico/`.

---

## Modelo de datos (resumen)

`clinicians`, `patients` (perfil + datos clínicos), `patient_diagnoses` (uno o varios), `patient_antecedents` (catálogo o a medida), `evaluations` (piso pélvico ICS 2021), `session_logs` (matriz día×entrenamiento → adherencia), `encounters`, `questionnaire_results` (ICIQ, POP‑SS, Wexner…), `bladder_diary`, `diary_entries`, `messages`, y `programs` / `program_levels` / `program_blocks` (default + a medida). Todo con RLS.

## Hoja de ruta de migración

1. ✅ Esquema + RLS (`supabase_schema.sql`).
2. ⏳ Crear proyecto + aplicar esquema + datos de demo.
3. ⏳ Auth real (Laura super‑usuaria; pacientes que ella da de alta).
4. ⏳ Persistencia: reemplazar el estado en memoria por Supabase, entidad por entidad.
5. ⏳ GitHub Pages.

---

*Borrador clínico para validación de la Lic. Laura Baroli · NUT Kinesiología.*
