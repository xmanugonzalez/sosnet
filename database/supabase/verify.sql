-- ============================================================================
-- SOSNET · Verificación para Supabase SQL Editor (solo lectura)
-- Ejecutar después de 00_schemas.sql … 09_seed.sql y de configurar sosnet_api.
-- ============================================================================

-- 1. Esquemas y tablas
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname IN ('public', 'auditoria')
ORDER BY schemaname, tablename;

-- 2. RLS activo
SELECT n.nspname AS schema, c.relname AS tabla, c.relrowsecurity AS rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname IN ('public', 'auditoria')
ORDER BY 1, 2;

-- 3. Políticas
SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname IN ('public', 'auditoria')
ORDER BY schemaname, tablename, policyname;

-- 4. Rutinas (procedimientos y funciones)
SELECT n.nspname AS schema, p.proname,
       CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS tipo,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       pg_get_function_result(p.oid) AS retorno
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'reportes')
ORDER BY n.nspname, p.prokind DESC, p.proname;

-- 5. Vistas
SELECT table_schema, table_name
FROM information_schema.views
WHERE table_schema = 'reportes'
ORDER BY 2;

-- 6. Protección de hashes
SELECT
    has_column_privilege('sosnet_api', 'public.usuarios', 'contrasena', 'SELECT')
        AS api_puede_leer_hash,
    has_column_privilege('authenticated', 'public.usuarios', 'contrasena', 'SELECT')
        AS authenticated_puede_leer_hash;

-- 7. RPC pública cerrada y reportes habilitados
SELECT
    has_function_privilege(
        'anon',
        'public.sp_registrar_solicitud(text,text,text,text,text,integer,text,text,timestamptz)',
        'EXECUTE'
    ) AS anon_puede_crear_sos,
    has_function_privilege(
        'sosnet_reporte',
        'reportes.fn_historial_solicitud(integer)',
        'EXECUTE'
    ) AS reporte_puede_ver_historial;

-- 8. Datos iniciales
SELECT
    (SELECT count(*) FROM public.usuarios) AS usuarios,
    (SELECT count(*) FROM public.tipos_emergencia) AS tipos,
    (SELECT count(*) FROM public.dispositivos) AS dispositivos,
    (SELECT count(*) FROM public.configuracion_central) AS configuracion,
    (SELECT count(*) FROM public.solicitudes_sos) AS solicitudes;

-- 9. Funciones escalares
SELECT reportes.fn_total_solicitudes(),
       reportes.fn_solicitudes_pendientes(),
       reportes.fn_dispositivos_activos(),
       reportes.fn_solicitudes_periodo(now() - interval '365 days', now());

-- 10. Función de tabla y vista
SELECT * FROM reportes.fn_estadisticas_por_tipo();
SELECT * FROM reportes.vw_estadisticas_emergencias;

-- 11. Historial como rol de reportes (solo lectura)
SET ROLE sosnet_reporte;
SELECT * FROM reportes.fn_historial_solicitud(1);
RESET ROLE;
