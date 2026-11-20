-- ============================================================================
-- SOSNET · Pruebas SQL · 01 Objetos y datos iniciales
-- Ejecutar con psql -v ON_ERROR_STOP=1 -f 01_objects.sql
-- ============================================================================
\set ON_ERROR_STOP on

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.schemata
    WHERE schema_name IN ('public', 'auditoria', 'reportes');
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'Se esperaban 3 esquemas, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM pg_tables
    WHERE schemaname IN ('public', 'auditoria')
      AND tablename IN (
          'usuarios', 'tipos_emergencia', 'dispositivos',
          'configuracion_central', 'solicitudes_sos',
          'registros_comunicacion', 'historial_estados', 'actividad'
      );
    IF v_count <> 8 THEN
        RAISE EXCEPTION 'Se esperaban 8 tablas, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM information_schema.views
    WHERE table_schema = 'reportes';
    IF v_count <> 6 THEN
        RAISE EXCEPTION 'Se esperaban 6 vistas, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM information_schema.routines
    WHERE routine_schema IN ('public', 'reportes');
    IF v_count <> 28 THEN
        RAISE EXCEPTION 'Se esperaban 28 rutinas, hay %', v_count;
    END IF;

    SELECT count(DISTINCT trigger_name) INTO v_count
    FROM information_schema.triggers
    WHERE trigger_schema IN ('public', 'auditoria');
    IF v_count < 5 THEN
        RAISE EXCEPTION 'Se esperaban al menos 5 triggers, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public', 'auditoria')
      AND c.relkind = 'r'
      AND c.relrowsecurity;
    IF v_count <> 8 THEN
        RAISE EXCEPTION 'RLS debe estar activo en 8 tablas, está en %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM pg_policies
    WHERE schemaname IN ('public', 'auditoria');
    IF v_count <> 28 THEN
        RAISE EXCEPTION 'Se esperaban 28 políticas, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'usuarios'
      AND column_name = 'token_version';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Falta la columna usuarios.token_version';
    END IF;

    IF has_column_privilege('sosnet_api', 'public.usuarios', 'contrasena', 'SELECT') THEN
        RAISE EXCEPTION 'sosnet_api no debe poder leer usuarios.contrasena';
    END IF;

    IF has_column_privilege('authenticated', 'public.usuarios', 'contrasena', 'SELECT') THEN
        RAISE EXCEPTION 'authenticated no debe poder leer usuarios.contrasena';
    END IF;

    IF NOT has_function_privilege(
        'sosnet_reporte', 'reportes.fn_historial_solicitud(integer)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'sosnet_reporte debe poder ejecutar fn_historial_solicitud';
    END IF;

    SELECT count(*) INTO v_count FROM pg_roles
    WHERE rolname IN ('sosnet_api', 'sosnet_reporte', 'anon', 'authenticated');
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'Faltan roles de PostgreSQL: %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM public.tipos_emergencia;
    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Se esperaban 5 tipos de emergencia, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM public.dispositivos;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Se esperaba 1 dispositivo, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM public.usuarios;
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'Se esperaban 3 usuarios, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM public.configuracion_central;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'La configuración debe tener una fila, hay %', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM public.solicitudes_sos;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'La base de pruebas debe iniciar sin solicitudes, hay %', v_count;
    END IF;

    RAISE NOTICE '01_objects: OK (esquemas, tablas, vistas, rutinas, triggers, RLS, seed)';
END;
$$;
