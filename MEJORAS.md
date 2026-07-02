# Mejoras aplicadas — NUT Piso Pélvico

Resumen de la curación de la app. Nada de la lógica clínica ni el diseño cambió; se corrigieron seguridad, bugs y accesibilidad, y se reorganizó el código.

## Seguridad (crítico — maneja datos de salud)

- **Anti-XSS en toda la app.** Se agregó `esc()` y se aplicó en los ~30 puntos donde texto de la paciente o de Laura se mostraba sin escapar (nota del diario, mensajes, nombres, antecedentes, datos de perfil, ficha impresa…). Antes, una nota del diario con código HTML se ejecutaba **en la sesión de Laura** al abrir la ficha.
- **Login obligatorio, sin demo abierto.** Se quitó el selector "DEMO Paciente/Laura" y las credenciales de ejemplo (`sofia.m` / `123456`) que venían escritas en el HTML. Si Supabase no carga, la app muestra un aviso y nunca el contenido (antes el panel clínico quedaba accesible si fallaba el CDN).
- **Blanqueo de clave sin filtrar DNIs.** "Olvidé mi clave" ahora responde siempre lo mismo, exista o no el DNI (antes se podía averiguar qué DNIs son pacientes reales). Además usa una ventana accesible en vez del `prompt()` del navegador.
- **Claves transitorias fuertes** con `crypto.getRandomValues` (antes `NUT` + 4 dígitos = 10.000 combinaciones).

## Bugs corregidos

- **El dolor ahora llega a Laura.** El botón "Enviar a Laura" del reproductor no guardaba el valor de la escala EVA ni el momento; ahora sí se registran.
- **Se respeta el candado de nivel.** Si Laura fija el nivel ("lock"), la app ya no sube ni baja de nivel sola. Antes el candado no hacía nada.
- **Asignación de programa por clave, no por posición.** Cambiar el programa de una paciente usaba el índice del menú; tras borrar/crear programas podía asignar el equivocado.
- **Errores de servidor visibles.** Borrar una paciente ya no la saca de la vista si el servidor rechaza la operación; y guardar diario/cuestionario/micción fuerza el guardado inmediato (antes se esperaba hasta 6 s y podía perderse al cerrar).

## Accesibilidad (público: mujeres adultas y mayores)

- **Zoom habilitado** (se quitó `maximum-scale=1`).
- **Botones reales por teclado y lector de pantalla**: los controles que eran `<div>` ahora tienen `role="button"` y responden a Enter/Espacio; los modales cierran con Escape y devuelven el foco.
- **Mejor contraste** en textos secundarios y se agrandó la tipografía más chica.
- Campos de login a 16px (evita el zoom automático molesto en iPhone).

## PWA real (instalable + offline)

- Se agregaron `manifest.webmanifest`, `sw.js` (Service Worker) e iconos. El README prometía "instalable" pero no existía nada de esto. El Service Worker cachea el cascarón de la app; **nunca** cachea llamadas a Supabase (datos de salud siempre a la red).

## Código

- Se separó el `index.html` de 265 KB en `index.html` + `css/styles.css` + 8 archivos JS por responsabilidad. Sigue sin build; GitHub Pages lo sirve igual.
- Se corrigieron los acentos de los cuestionarios clínicos (se veían "Con que frecuencia se le escapa la orina?").
- Se sincronizó `supabase_schema.sql` con lo que la app realmente usa (columnas `state`, `must_change`, `temp_pw`, `pw_reset_requested`, `dni` y la función `request_pw_reset`).

## Pendientes recomendados (requieren decisiones/backend)

- Implementar como **Edge Functions** (service_role) las RPC `clinician_create_login` y `clinician_reset_patient_pw`: crear/actualizar usuarios de Auth no se puede desde el cliente.
- Verificar en el panel de Supabase que las **políticas RLS** estén activas antes de cargar pacientes reales.
- Confirmar que el índice de "poliuria nocturna" se calcule sobre 24 h reales (hoy usa lo que la paciente haya cargado).
