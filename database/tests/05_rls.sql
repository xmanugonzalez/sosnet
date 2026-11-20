-- ============================================================================
-- SOSNET · Pruebas SQL · 05 Row Level Security
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

-- IDs de prueba en GUCs de sesión, separados de app.current_user_id.
DO $$
DECLARE
    v_operador integer;
    v_admin integer;
    v_solicitud integer;
BEGIN
    SELECT id_usuario INTO v_operador FROM public.usuarios WHERE usuario = 'operador';
    SELECT id_usuario INTO v_admin FROM public.usuarios WHERE usuario = 'admin';

    PERFORM set_config('audit.operador_id', v_operador::text, true);
    PERFORM set_config('audit.admin_id', v_admin::text, true);

    CALL public.sp_registrar_solicitud(
        'SOS-RLS-BASE'::text, 'Solicitud base'::text, 'Inundación'::text,
        'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
        'Base para pruebas RLS'::text, 'media'::text, now()::timestamptz, v_solicitud
    );
    PERFORM set_config('audit.solicitud_id', v_solicitud::text, true);
END;
$$;

-- Dos cambios de estado por actores distintos.
SET LOCAL ROLE sosnet_api;
SELECT set_config('app.current_user_id', current_setting('audit.operador_id'), true),
       set_config('app.current_role', 'operador', true);
CALL public.sp_actualizar_estado(
    current_setting('audit.solicitud_id')::integer,
    'in_progress',
    current_setting('audit.operador_id')::integer,
    'Operador en camino'
);
RESET ROLE;

SET LOCAL ROLE sosnet_api;
SELECT set_config('app.current_user_id', current_setting('audit.admin_id'), true),
       set_config('app.current_role', 'admin', true);
CALL public.sp_actualizar_estado(
    current_setting('audit.solicitud_id')::integer,
    'resolved',
    current_setting('audit.admin_id')::integer,
    'Administrador cierra'
);
RESET ROLE;

-- Actividad y mapeo de Supabase Auth para las pruebas.
CALL public.sp_registrar_actividad(
    current_setting('audit.operador_id')::integer,
    'login', 'Actividad del operador'
);
CALL public.sp_registrar_actividad(
    current_setting('audit.admin_id')::integer,
    'login', 'Actividad del administrador'
);

UPDATE public.usuarios
SET supabase_uid = '11111111-1111-1111-1111-111111111111'
WHERE id_usuario = current_setting('audit.operador_id')::integer;

UPDATE public.usuarios
SET supabase_uid = '22222222-2222-2222-2222-222222222222'
WHERE id_usuario = current_setting('audit.admin_id')::integer;

-- ----------------------------------------------------------------------------
-- anon: no lee tablas y ya no puede ejecutar la RPC de alta.
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

DO $$
DECLARE
    v_count integer;
    v_nueva integer;
BEGIN
    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'anon pudo leer solicitudes';
    END IF;

    BEGIN
        SELECT count(*) INTO v_count FROM public.usuarios;
        IF v_count <> 0 THEN
            RAISE EXCEPTION 'anon pudo leer usuarios';
        END IF;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        )
        VALUES (
            'SOS-RLS-HACK', 1, 1, 'Hack', 1, 'alta', 'pending', now()
        );
        RAISE EXCEPTION 'anon pudo insertar directamente una solicitud';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        CALL public.sp_registrar_solicitud(
            'SOS-RLS-ANON'::text, 'Anónimo'::text, 'Evacuación'::text,
            'FORMULARIO-SOS'::text, 'San Lorenzo'::text, 1,
            'No debe entrar'::text, 'media'::text, now()::timestamptz, v_nueva
        );
        RAISE EXCEPTION 'anon pudo ejecutar sp_registrar_solicitud';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    RAISE NOTICE '05_rls anon: OK (sin lectura ni RPC directa)';
END;
$$;

RESET ROLE;

-- Verificación: solo existe la solicitud base.
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Se esperaba 1 solicitud base, hay %', v_count;
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- authenticated con rol operador
-- ----------------------------------------------------------------------------
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","app_metadata":{"role":"operador"}}',
    true
);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
    v_count integer;
    v_historial integer;
    v_operador integer;
    v_nueva integer;
    v_solicitud integer := current_setting('audit.solicitud_id')::integer;
BEGIN
    SELECT id_usuario INTO v_operador
    FROM public.usuarios WHERE usuario = 'operador';

    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'El operador no pudo leer solicitudes';
    END IF;

    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El operador debería ver solo su cuenta, ve %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad WHERE id_usuario = v_operador;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'El operador no pudo leer su propia actividad';
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad WHERE id_usuario <> v_operador;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'El operador pudo leer actividad ajena';
    END IF;

    -- El historial debe incluir cambios del operador y del administrador.
    SELECT count(*) INTO v_historial
    FROM reportes.fn_historial_solicitud(v_solicitud);
    IF v_historial <> 2 THEN
        RAISE EXCEPTION 'El operador debería ver 2 filas de historial, ve %', v_historial;
    END IF;

    BEGIN
        SELECT contrasena FROM public.usuarios LIMIT 1;
        RAISE EXCEPTION 'El operador pudo leer hashes';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        CALL public.sp_registrar_solicitud(
            'SOS-RLS-AUTH'::text, 'Autenticado'::text, 'Evacuación'::text,
            'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
            'No debe entrar'::text, 'media'::text, now()::timestamptz, v_nueva
        );
        RAISE EXCEPTION 'authenticated pudo ejecutar sp_registrar_solicitud';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    WITH actualizadas AS (
        UPDATE public.solicitudes_sos SET prioridad = 'baja' RETURNING 1
    )
    SELECT count(*) INTO v_count FROM actualizadas;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'El operador pudo actualizar solicitudes por tabla';
    END IF;

    RAISE NOTICE '05_rls authenticated/operador: OK (historial completo, sin hashes)';
END;
$$;

RESET ROLE;

-- ----------------------------------------------------------------------------
-- authenticated con rol administrador
-- ----------------------------------------------------------------------------
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","app_metadata":{"role":"admin"}}',
    true
);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'El administrador debería ver 3 usuarios, ve %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM auditoria.actividad;
    IF v_count < 2 THEN
        RAISE EXCEPTION 'El administrador no pudo leer toda la actividad';
    END IF;

    BEGIN
        SELECT contrasena FROM public.usuarios LIMIT 1;
        RAISE EXCEPTION 'El administrador pudo leer hashes';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        WITH actualizadas AS (
            UPDATE public.usuarios SET nombre = nombre RETURNING 1
        )
        SELECT count(*) INTO v_count FROM actualizadas;
        IF v_count <> 0 THEN
            RAISE EXCEPTION 'authenticated pudo actualizar usuarios sin política';
        END IF;
        RAISE EXCEPTION 'authenticated pudo actualizar usuarios';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    RAISE NOTICE '05_rls authenticated/admin: OK (lectura global sin hashes)';
END;
$$;

RESET ROLE;

-- ----------------------------------------------------------------------------
-- sosnet_api: contexto fijado por Flask
-- ----------------------------------------------------------------------------
SET LOCAL ROLE sosnet_api;

DO $$
DECLARE
    v_count integer;
    v_historial integer;
    v_solicitud integer := current_setting('audit.solicitud_id')::integer;
BEGIN
    -- Sin contexto no ve filas.
    PERFORM set_config('app.current_user_id', '', true);
    PERFORM set_config('app.current_role', '', true);

    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'sosnet_api vio solicitudes sin contexto';
    END IF;

    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'sosnet_api vio usuarios sin contexto';
    END IF;

    PERFORM set_config('app.current_user_id', current_setting('audit.operador_id'), true);
    PERFORM set_config('app.current_role', 'operador', true);

    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'sosnet_api con operador no pudo leer solicitudes';
    END IF;

    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sosnet_api con operador debería ver 1 usuario, ve %', v_count;
    END IF;

    SELECT count(*) INTO v_historial
    FROM reportes.fn_historial_solicitud(v_solicitud);
    IF v_historial <> 2 THEN
        RAISE EXCEPTION 'sosnet_api operador debería ver 2 historiales, ve %', v_historial;
    END IF;

    PERFORM set_config('app.current_user_id', current_setting('audit.admin_id'), true);
    PERFORM set_config('app.current_role', 'admin', true);

    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'sosnet_api con admin debería ver 3 usuarios, ve %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM auditoria.actividad;
    IF v_count < 2 THEN
        RAISE EXCEPTION 'sosnet_api con admin no pudo leer la auditoría';
    END IF;

    BEGIN
        SELECT contrasena FROM public.usuarios LIMIT 1;
        RAISE EXCEPTION 'sosnet_api pudo leer hashes';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        CREATE TABLE public.tabla_prohibida (id integer);
        RAISE EXCEPTION 'sosnet_api pudo crear una tabla';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    RAISE NOTICE '05_rls sosnet_api: OK (contexto GUC, sin hashes ni DDL)';
END;
$$;

RESET ROLE;

-- ----------------------------------------------------------------------------
-- sosnet_reporte: agregados e historial, sin usuarios.
-- ----------------------------------------------------------------------------
SET LOCAL ROLE sosnet_reporte;

DO $$
DECLARE
    v_total bigint;
    v_historial integer;
    v_solicitud integer := current_setting('audit.solicitud_id')::integer;
BEGIN
    SELECT total_solicitudes INTO v_total
    FROM reportes.vw_estadisticas_emergencias;
    IF v_total IS NULL OR v_total < 1 THEN
        RAISE EXCEPTION 'sosnet_reporte no pudo leer la vista agregada';
    END IF;

    SELECT count(*) INTO v_historial
    FROM reportes.fn_historial_solicitud(v_solicitud);
    IF v_historial <> 2 THEN
        RAISE EXCEPTION 'sosnet_reporte debería ver 2 historiales, ve %', v_historial;
    END IF;

    SELECT count(*) INTO v_total FROM reportes.fn_solicitudes_por_estado('resolved');
    IF v_total < 1 THEN
        RAISE EXCEPTION 'sosnet_reporte no pudo ejecutar fn_solicitudes_por_estado';
    END IF;

    BEGIN
        PERFORM count(*) FROM public.usuarios;
        RAISE EXCEPTION 'sosnet_reporte pudo leer usuarios';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    RAISE NOTICE '05_rls sosnet_reporte: OK (agregados e historial, sin usuarios ni hashes)';
END;
$$;

RESET ROLE;

ROLLBACK;
