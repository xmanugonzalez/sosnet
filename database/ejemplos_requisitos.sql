-- ============================================================================
-- SOSNET · Ejemplos SQL de los ocho requisitos académicos
--
-- Archivo de consulta/demostración. Las operaciones de escritura están dentro
-- de transacciones con ROLLBACK para no dejar datos de prueba.
-- Ejecutar con psql o Supabase SQL Editor, sección por sección.
-- ============================================================================

-- ============================================================================
-- 1. BASE DE DATOS
-- ============================================================================
-- Tablas, claves y relaciones
SELECT n.nspname AS esquema, c.relname AS tabla
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname IN ('public', 'auditoria')
ORDER BY 1, 2;

SELECT tc.table_schema, tc.table_name, tc.constraint_type, tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema IN ('public', 'auditoria')
ORDER BY 1, 2, 3;

-- Índices
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname IN ('public', 'auditoria')
ORDER BY 1, 2, 3;

-- ============================================================================
-- 2. PROCEDIMIENTOS ALMACENADOS
-- ============================================================================
-- Alta completa de una solicitud (tipo + dispositivo + comunicación).
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-EJEMPLO-001'::text,
    'María González'::text,
    'Inundación'::text,
    'FORMULARIO-SOS'::text,
    'Barrio San Francisco'::text,
    3,
    'El agua sube'::text,
    'alta'::text,
    now()::timestamptz,
    NULL
);
SELECT id_solicitud, codigo_mensaje, estado
FROM public.solicitudes_sos
WHERE codigo_mensaje = 'SOS-EJEMPLO-001';
ROLLBACK;

-- Cambio de estado (el trigger registra historial y auditoría).
BEGIN;
CALL public.sp_actualizar_estado(1, 'in_progress', 1, 'Operador en camino');
SELECT * FROM auditoria.historial_estados WHERE id_solicitud = 1;
ROLLBACK;

-- ============================================================================
-- 3. TRIGGERS
-- ============================================================================
BEGIN;
-- Trigger de historial/actividad por cambio de estado.
CALL public.sp_actualizar_estado(1, 'resolved', 2, 'Cierre de prueba');

-- Trigger de auditoría de cuentas.
INSERT INTO public.usuarios (nombre, usuario, correo, contrasena, rol)
VALUES ('Temporal EJEMPLO', 'temp_ejemplo', 'temp_ejemplo@sosnet.local', 'x', 'operador');
UPDATE public.usuarios SET nombre = 'Temporal EJEMPLO 2' WHERE usuario = 'temp_ejemplo';
DELETE FROM public.usuarios WHERE usuario = 'temp_ejemplo';

SELECT accion, descripcion FROM auditoria.actividad
WHERE descripcion LIKE '%Temporal EJEMPLO%' OR accion = 'emergency_status'
ORDER BY id_actividad;
ROLLBACK;

-- ============================================================================
-- 4. VISTAS
-- ============================================================================
SELECT * FROM reportes.vw_solicitudes_detalladas;
SELECT * FROM reportes.vw_solicitudes_por_tipo;
SELECT * FROM reportes.vw_historial_solicitudes;
SELECT * FROM reportes.vw_actividad_usuarios;
SELECT * FROM reportes.vw_estadisticas_emergencias;
SELECT * FROM reportes.vw_resumen_dispositivos;

-- ============================================================================
-- 5. FUNCIONES ESCALARES Y DE TABLA
-- ============================================================================
-- Escalares: devuelven un único valor.
SELECT reportes.fn_total_solicitudes() AS total,
       reportes.fn_solicitudes_pendientes() AS pendientes,
       reportes.fn_dispositivos_activos() AS dispositivos_activos,
       reportes.fn_solicitudes_periodo(now() - interval '7 days', now()) AS ultima_semana;

-- Table-valued: devuelven un conjunto de filas.
SELECT * FROM reportes.fn_solicitudes_por_estado('pending');
SELECT * FROM reportes.fn_historial_solicitud(1);
SELECT * FROM reportes.fn_solicitudes_entre_fechas(
    now() - interval '365 days', now() + interval '1 day'
);
SELECT * FROM reportes.fn_estadisticas_por_tipo();

-- ============================================================================
-- 6. ESQUEMAS
-- ============================================================================
SELECT n.nspname AS esquema, c.relname AS objeto,
       CASE c.relkind
           WHEN 'r' THEN 'tabla'
           WHEN 'v' THEN 'vista'
           WHEN 'p' THEN 'tabla particionada'
           ELSE c.relkind::text
       END AS tipo
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'auditoria', 'reportes')
  AND c.relkind IN ('r', 'v', 'p')
ORDER BY 1, 2;

-- Permisos por rol
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('sosnet_api', 'sosnet_reporte', 'anon', 'authenticated')
  AND table_schema IN ('public', 'auditoria', 'reportes')
ORDER BY 1, 2, 3, 4;

-- ============================================================================
-- 7. TRANSACCIONES
-- ============================================================================
-- COMMIT: la solicitud queda guardada.
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-EJEMPLO-COMMIT'::text, 'Commit'::text, 'Otra'::text,
    'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
    'Confirmada'::text, 'media'::text, now()::timestamptz, NULL
);
COMMIT;

SELECT count(*) AS debe_existir
FROM public.solicitudes_sos
WHERE codigo_mensaje = 'SOS-EJEMPLO-COMMIT';

-- ROLLBACK: no queda rastro.
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-EJEMPLO-ROLLBACK'::text, 'Rollback'::text, 'Otra'::text,
    'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
    'No debe persistir'::text, 'media'::text, now()::timestamptz, NULL
);
ROLLBACK;

SELECT count(*) AS debe_ser_cero
FROM public.solicitudes_sos
WHERE codigo_mensaje = 'SOS-EJEMPLO-ROLLBACK';

-- Limpieza de la fila confirmada por el ejemplo.
DELETE FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-EJEMPLO-COMMIT';

-- ============================================================================
-- 8. SEGURIDAD: ROLES, USUARIOS, LOGIN Y RLS
-- ============================================================================
-- Roles PostgreSQL
SELECT rolname, rolsuper, rolbypassrls, rolcanlogin
FROM pg_roles
WHERE rolname IN ('anon', 'authenticated', 'sosnet_api', 'sosnet_reporte')
ORDER BY rolname;

-- Roles funcionales (tabla usuarios)
SELECT usuario, correo, rol, activo, token_version
FROM public.usuarios ORDER BY id_usuario;

-- anon no puede leer ni crear solicitudes.
BEGIN;
SET LOCAL ROLE anon;
SELECT count(*) AS anon_ve_solicitudes FROM public.solicitudes_sos;
ROLLBACK;

-- Operador autenticado: lectura de su cuenta, historial completo y sin hashes.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"operador"}}',
  true
);
SELECT usuario, rol FROM public.usuarios; -- según mapping/RLS
SELECT * FROM reportes.fn_historial_solicitud(1);
SELECT contrasena FROM public.usuarios LIMIT 1; -- debe fallar por permisos de columna
ROLLBACK;

-- sosnet_reporte: agregados e historial, sin usuarios.
SET ROLE sosnet_reporte;
SELECT total_solicitudes FROM reportes.vw_estadisticas_emergencias;
SELECT * FROM reportes.fn_historial_solicitud(1);
RESET ROLE;

-- Logout: invalida los JWT anteriores.
BEGIN;
CALL public.sp_logout_usuario(1);
SELECT token_version FROM public.usuarios WHERE id_usuario = 1;
ROLLBACK;
