-- ============================================================
-- NUT Piso Pélvico — Esquema Supabase (v2)
-- Clínica con una kinesióloga (super-usuaria) y sus pacientes.
-- Incluye Row Level Security (RLS): cada paciente ve solo lo suyo;
-- la kinesióloga ve y gestiona a sus pacientes.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- Catálogos (contenido clínico estático) ----------
create table if not exists pathologies (
  key       text primary key,
  name      text not null,
  category  text                       -- fortalecimiento / relajacion / coordinacion
);

create table if not exists antecedents (
  key   text primary key,
  label text not null,
  grp   text
);

-- ---------- Clínicos ----------
create table if not exists clinicians (
  id         uuid primary key default gen_random_uuid(),
  auth_id    uuid unique references auth.users(id) on delete cascade,
  name       text not null,
  license    text,
  created_at timestamptz default now()
);

-- ---------- Programas (por defecto + a medida) ----------
create table if not exists programs (
  id            uuid primary key default gen_random_uuid(),
  key           text unique not null,
  name          text not null,
  category      text,
  is_custom     boolean default false,
  clinician_id  uuid references clinicians(id) on delete cascade,
  base_pathology text references pathologies(key),
  created_at    timestamptz default now()
);

create table if not exists program_levels (
  id         uuid primary key default gen_random_uuid(),
  program_id uuid references programs(id) on delete cascade,
  level_no   int not null,
  name       text,
  unique (program_id, level_no)
);

create table if not exists program_blocks (
  id        uuid primary key default gen_random_uuid(),
  level_id  uuid references program_levels(id) on delete cascade,
  ord       int default 0,
  name      text,
  onset     text,       -- 'ramp' | 'instant'
  ramp_up   numeric,
  hold      numeric,
  offset_kind text,     -- 'ramp' | 'instant'
  ramp_down numeric,
  relax     numeric,
  reps      int,
  space     numeric
);

-- ---------- Pacientes ----------
create table if not exists patients (
  id             uuid primary key default gen_random_uuid(),
  auth_id        uuid unique references auth.users(id) on delete set null,
  clinician_id   uuid not null references clinicians(id) on delete cascade,
  username       text unique,
  first_name     text,
  last_name      text,
  dob            date,
  phone          text,
  email          text,
  coverage       text,           -- obra social/prepaga o 'No'
  member_no      text,           -- nro de afiliada
  referring_doctor text,
  doctor_contact text,
  path_key       text references pathologies(key),   -- diagnóstico principal
  prog_key       text,           -- programa asignado (ejercicios); null = default del diagnóstico
  level          int default 1,
  level_locked   boolean default false,
  max_level      int default 3,
  plan_per_day   int default 3,
  plan_days      int default 7,
  start_date     date default current_date,
  phase          text default 'tratamiento',         -- tratamiento / mantenimiento / alta
  enc_total      int default 8,
  control_date   date,
  private_note   text,           -- notas solo de Laura
  shared_note    text,           -- notas compartidas con la paciente
  status         text default 'active',
  consent_at     timestamptz,
  created_at     timestamptz default now()
);

-- ---------- Diagnósticos (uno o varios) ----------
create table if not exists patient_diagnoses (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  dx_key     text references pathologies(key),
  is_primary boolean default false,
  ord        int default 0
);

-- ---------- Antecedentes (de catálogo o a medida) ----------
create table if not exists patient_antecedents (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid references patients(id) on delete cascade,
  antecedent_key text,           -- antecedents.key o 'cust_*'
  custom_label  text,
  custom_note   text,
  is_custom     boolean default false
);

-- ---------- Evaluación del piso pélvico (ICS 2021), histórica ----------
create table if not exists evaluations (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid references patients(id) on delete cascade,
  eval_date   date default current_date,
  tono        text,
  contraction text,
  relaxation  text,
  oxford      int,
  endurance   int,
  notes       text
);

-- ---------- Sesiones domiciliarias (matriz día × entrenamiento) ----------
create table if not exists session_logs (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid references patients(id) on delete cascade,
  log_date      date not null,
  workout_index int default 0,
  done          boolean default true,
  recorded_at   timestamptz default now()
);
create index if not exists idx_session_logs_patient_date on session_logs (patient_id, log_date);

-- ---------- Encuentros (citas presenciales) ----------
create table if not exists encounters (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  n          int,
  enc_date   date,
  note       text
);

-- ---------- Cuestionarios validados (PROMs) ----------
create table if not exists questionnaire_results (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid references patients(id) on delete cascade,
  instrument      text,           -- iciq / popss / wexner / ccs / pain / func
  score           int,
  max_score       int,
  band            text,
  result_date     date default current_date,
  administered_by text default 'patient'   -- patient / clinician
);

-- ---------- Diario vesical (frecuencia-volumen) ----------
create table if not exists bladder_diary (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  entry_date date,
  entry_time text,
  is_night   boolean default false,
  volume_ml  int,
  urgency    boolean default false,
  leak       boolean default false
);

-- ---------- Diario de síntomas ----------
create table if not exists diary_entries (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  entry_date date default current_date,
  eva        int,
  leaks      int,
  urgency    int,
  pads       int,
  nocturia   int,
  bowel      text,
  note       text
);

-- ---------- Mensajes ----------
create table if not exists messages (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  from_role  text,           -- 'clinician' | 'patient'
  body       text,
  scope      text,           -- una / grupo / todas (registro del envío)
  sent_at    timestamptz default now()
);
create index if not exists idx_messages_patient on messages (patient_id, sent_at);

-- ============================================================
-- Helpers de identidad para RLS
-- ============================================================
create or replace function my_clinician_id() returns uuid
  language sql stable as $$ select id from clinicians where auth_id = auth.uid() $$;

create or replace function my_patient_id() returns uuid
  language sql stable as $$ select id from patients where auth_id = auth.uid() $$;

-- ¿el paciente pid pertenece a la clínica logueada?
create or replace function owns_patient(pid uuid) returns boolean
  language sql stable as $$
    select exists (select 1 from patients p where p.id = pid and p.clinician_id = my_clinician_id())
  $$;

-- ============================================================
-- Row Level Security
-- ============================================================

-- Catálogos: lectura para cualquier usuario autenticado
alter table pathologies enable row level security;
alter table antecedents enable row level security;
create policy cat_read_path on pathologies for select to authenticated using (true);
create policy cat_read_ant  on antecedents for select to authenticated using (true);

-- Clínicos: cada quien ve su propia fila
alter table clinicians enable row level security;
create policy clin_self on clinicians
  using (auth_id = auth.uid()) with check (auth_id = auth.uid());

-- Programas: la clínica gestiona los suyos; los default (clinician_id null) se leen
alter table programs enable row level security;
create policy prog_read on programs for select to authenticated
  using (is_custom = false or clinician_id = my_clinician_id());
create policy prog_write on programs for all to authenticated
  using (clinician_id = my_clinician_id()) with check (clinician_id = my_clinician_id());

alter table program_levels enable row level security;
create policy plev_all on program_levels for all to authenticated
  using (program_id in (select id from programs where clinician_id = my_clinician_id() or is_custom = false))
  with check (program_id in (select id from programs where clinician_id = my_clinician_id()));

alter table program_blocks enable row level security;
create policy pblk_all on program_blocks for all to authenticated
  using (level_id in (select pl.id from program_levels pl join programs p on p.id = pl.program_id
                      where p.clinician_id = my_clinician_id() or p.is_custom = false))
  with check (level_id in (select pl.id from program_levels pl join programs p on p.id = pl.program_id
                      where p.clinician_id = my_clinician_id()));

-- Pacientes: Laura ve/gestiona a los suyos; la paciente ve/edita su propia fila
alter table patients enable row level security;
create policy pat_clin on patients for all to authenticated
  using (clinician_id = my_clinician_id()) with check (clinician_id = my_clinician_id());
create policy pat_self on patients for all to authenticated
  using (auth_id = auth.uid()) with check (auth_id = auth.uid());

-- Tablas por-paciente: política doble (clínica dueña + paciente dueña)
-- Se aplica el mismo patrón a todas.
do $$
declare t text;
begin
  foreach t in array array[
    'patient_diagnoses','patient_antecedents','evaluations','session_logs',
    'encounters','questionnaire_results','bladder_diary','diary_entries','messages'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format($p$create policy %I on %I for all to authenticated
        using (owns_patient(patient_id) or patient_id = my_patient_id())
        with check (owns_patient(patient_id) or patient_id = my_patient_id());$p$,
        t||'_access', t);
  end loop;
end $$;

-- ============================================================
-- Seed de catálogos (las 9 patologías y los antecedentes)
-- (El contenido clínico —evidencia, tips, protocolos, cuestionarios—
--  vive en la app como constantes; acá van solo las claves de referencia.)
-- ============================================================
insert into pathologies(key,name,category) values
 ('iu_esfuerzo','Incontinencia de esfuerzo','fortalecimiento'),
 ('iu_urgencia','Incontinencia de urgencia','coordinacion'),
 ('iu_mixta','Incontinencia mixta','fortalecimiento'),
 ('posparto','Posparto','fortalecimiento'),
 ('prolapso','Prolapso','fortalecimiento'),
 ('hipertonia','Hipertonía / dolor','relajacion'),
 ('incont_fecal','Incontinencia fecal','fortalecimiento'),
 ('constipacion','Constipación / disinergia','coordinacion'),
 ('diastasis','Diástasis abdominal','fortalecimiento')
on conflict (key) do nothing;


-- ============================================================
-- Actualización v3 — sincroniza el esquema con lo que usa index.html
-- La app guarda el estado de cada paciente en un blob JSON (patients.state)
-- y usa columnas de acceso (username/email/clave transitoria/blanqueo).
-- Ejecutá este bloque una sola vez sobre el esquema anterior.
-- ============================================================

alter table patients add column if not exists state                jsonb  default '{}'::jsonb;
alter table patients add column if not exists must_change           boolean default true;   -- fuerza cambio de clave en el 1er ingreso
alter table patients add column if not exists temp_pw               text;                   -- clave transitoria (se limpia al cambiarla)
alter table patients add column if not exists pw_reset_requested    boolean default false;  -- la paciente pidió blanqueo
alter table patients add column if not exists dni                   text;                   -- para el blanqueo por DNI
create index if not exists idx_patients_dni on patients (dni);

-- ------------------------------------------------------------
-- RPC 1: la paciente pide blanqueo con su DNI.
-- SECURITY DEFINER + respuesta uniforme (void): nunca revela si el DNI existe.
-- ------------------------------------------------------------
create or replace function request_pw_reset(dni text)
  returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  update patients set pw_reset_requested = true
   where patients.dni = request_pw_reset.dni;
  -- No devolvemos nada: exista o no el DNI, la respuesta es idéntica (anti-enumeración).
end;
$$;
revoke all on function request_pw_reset(text) from public;
grant execute on function request_pw_reset(text) to anon, authenticated;

-- ------------------------------------------------------------
-- RPC 2 y 3: crear el login de una paciente y blanquear su clave.
-- Crear/actualizar usuarios en auth.users NO se puede hacer desde SQL con la
-- anon key: requiere la Admin API de Supabase Auth (service_role). Implementalas
-- como *Edge Functions* con el service_role, verificando que quien llama sea la
-- kinesióloga dueña de la paciente. Firmas esperadas por la app:
--
--   clinician_create_login(pid uuid)              -> crea el usuario auth de la paciente
--                                                    (email = username@pacientes..., temp_pw)
--   clinician_reset_patient_pw(pid uuid, newpw text) -> setea una clave nueva y must_change=true
--
-- Referencia: https://supabase.com/docs/guides/functions +
--             supabase.auth.admin.createUser / updateUserById
-- ------------------------------------------------------------
