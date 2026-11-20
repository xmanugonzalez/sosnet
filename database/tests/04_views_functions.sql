-- ============================================================================
-- SOSNET · Pruebas SQL · 04 Vistas y funciones
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_solicitud_a integer;
    v_solicitud_b integer;
    v_operador integer;
    v_count integer;
    v_total bigint;
    v_pendientes bigint;
    v_activos bigint;
    v_periodo bigint;
    v_estado_views integer;
    v_nueva_a integer;
    v_nueva_b integer;
BEGIN
    SELECT id_usuario INTO v_operador FROM public.usuarios WHERE usuario = 'operador';

    CALL public.sp_registrar_solicitud(
        'SOS-FUNC-A'::text, 'Persona A'::text, 'Inundación'::text,
        'FORMULARIO-SOS'::text, 'Asunción'::text, 2,
        'Casa inundada'::text, 'alta'::text, now()::timestamptz, v_nueva_a
    );
    CALL public.sp_registrar_solicitud(
        'SOS-FUNC-B'::text, 'Persona B'::text, 'Asistencia médica'::text,
        'FORMULARIO-SOS'::text, 'Luque'::text, 1,
        'Persona descompensada'::text, 'media'::text, now()::timestamptz, v_nueva_b
    );

    SELECT id_solicitud INTO v_solicitud_a
    FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-FUNC-A';
    SELECT id_solicitud INTO v_solicitud_b
    FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-FUNC-B';

    CALL public.sp_actualizar_estado(v_solicitud_b, 'in_progress', v_operador, NULL);

    -- Funciones escalares.
    SELECT reportes.fn_total_solicitudes() INTO v_total;
    IF v_total <> 2 THEN
        RAISE EXCEPTION 'fn_total_solicitudes devolvió %', v_total;
    END IF;

    SELECT reportes.fn_solicitudes_pendientes() INTO v_pendientes;
    IF v_pendientes <> 1 THEN
        RAISE EXCEPTION 'fn_solicitudes_pendientes devolvió %', v_pendientes;
    END IF;

    SELECT reportes.fn_dispositivos_activos() INTO v_activos;
    IF v_activos <> 4 THEN
        RAISE EXCEPTION 'fn_dispositivos_activos devolvió %', v_activos;
    END IF;

    SELECT reportes.fn_solicitudes_periodo(
        now() - interval '1 hour', now() + interval '1 hour'
    ) INTO v_periodo;
    IF v_periodo <> 2 THEN
        RAISE EXCEPTION 'fn_solicitudes_periodo devolvió %', v_periodo;
    END IF;

    BEGIN
        PERFORM reportes.fn_solicitudes_periodo(now(), now() - interval '1 hour');
        RAISE EXCEPTION 'fn_solicitudes_periodo aceptó un rango invertido';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Funciones que retornan tablas.
    SELECT count(*) INTO v_count
    FROM reportes.fn_solicitudes_por_estado('pending');
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'fn_solicitudes_por_estado(pending) devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM reportes.fn_historial_solicitud(v_solicitud_b);
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'fn_historial_solicitud devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM reportes.fn_solicitudes_entre_fechas(
        now() - interval '1 hour', now() + interval '1 hour'
    );
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'fn_solicitudes_entre_fechas devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM reportes.fn_estadisticas_por_tipo();
    IF v_count <> 5 THEN
        RAISE EXCEPTION 'fn_estadisticas_por_tipo devolvió % filas', v_count;
    END IF;

    SELECT total INTO v_total
    FROM reportes.fn_estadisticas_por_tipo()
    WHERE tipo = 'Asistencia médica';
    IF v_total <> 1 THEN
        RAISE EXCEPTION 'fn_estadisticas_por_tipo no agrupó correctamente';
    END IF;

    BEGIN
        PERFORM * FROM reportes.fn_solicitudes_por_estado('inventado');
        RAISE EXCEPTION 'fn_solicitudes_por_estado aceptó un estado inválido';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Vistas.
    SELECT count(*) INTO v_count FROM reportes.vw_solicitudes_detalladas;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'vw_solicitudes_detalladas devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM reportes.vw_solicitudes_por_tipo;
    IF v_count <> 5 THEN
        RAISE EXCEPTION 'vw_solicitudes_por_tipo devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM reportes.vw_historial_solicitudes;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'vw_historial_solicitudes devolvió % filas', v_count;
    END IF;

    SELECT count(*) INTO v_count FROM reportes.vw_actividad_usuarios;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'vw_actividad_usuarios no devolvió la auditoría';
    END IF;

    SELECT total_solicitudes, pendientes
    INTO v_total, v_pendientes
    FROM reportes.vw_estadisticas_emergencias;
    IF v_total <> 2 OR v_pendientes <> 1 THEN
        RAISE EXCEPTION 'vw_estadisticas_emergencias devolvió % / %', v_total, v_pendientes;
    END IF;

    SELECT count(*) INTO v_count FROM reportes.vw_resumen_dispositivos;
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'vw_resumen_dispositivos devolvió % filas', v_count;
    END IF;

    SELECT total_solicitudes INTO v_count
    FROM reportes.vw_resumen_dispositivos
    WHERE codigo = 'FORMULARIO-SOS';
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'vw_resumen_dispositivos no contó las solicitudes';
    END IF;

    RAISE NOTICE '04_views_functions: OK (4 escalares, 4 de tabla, 6 vistas)';
END;
$$;

ROLLBACK;
