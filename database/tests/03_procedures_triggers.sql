-- ============================================================================
-- SOSNET · Pruebas SQL · 03 Procedimientos y triggers
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_solicitud integer;
    v_dispositivo integer;
    v_operador integer;
    v_admin integer;
    v_count integer;
    v_actualizado timestamptz;
    v_config_actualizado timestamptz;
    v_nueva integer;
    v_registro integer;
    v_extra integer;
    v_purgadas integer;
    v_token_antes integer;
    v_token_despues integer;
BEGIN
    SELECT id_usuario INTO v_operador FROM public.usuarios WHERE usuario = 'operador';
    SELECT id_usuario INTO v_admin FROM public.usuarios WHERE usuario = 'admin';

    -- Procedimiento principal: solicitud + comunicación + tipo/dispositivo.
    CALL public.sp_registrar_solicitud(
        'SOS-TEST-PROC'::text,
        'María González'::text,
        'Inundación'::text,
        'NODE-TEST'::text,
        'Barrio San Francisco'::text,
        3,
        'El agua sube'::text,
        'alta'::text,
        now()::timestamptz,
        v_nueva
    );

    SELECT id_solicitud INTO v_solicitud
    FROM public.solicitudes_sos
    WHERE codigo_mensaje = 'SOS-TEST-PROC';
    IF v_solicitud IS NULL THEN
        RAISE EXCEPTION 'sp_registrar_solicitud no creó la solicitud';
    END IF;

    SELECT count(*) INTO v_count
    FROM public.registros_comunicacion
    WHERE id_solicitud = v_solicitud;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Se esperaba 1 comunicación, hay %', v_count;
    END IF;

    SELECT id_dispositivo INTO v_dispositivo
    FROM public.dispositivos
    WHERE codigo = 'NODE-TEST';
    IF v_dispositivo IS NULL THEN
        RAISE EXCEPTION 'sp_registrar_solicitud no creó el dispositivo';
    END IF;

    -- Trigger de historial y auditoría al cambiar estado.
    CALL public.sp_actualizar_estado(
        v_solicitud,
        'in_progress',
        v_operador,
        'Operador en camino'
    );

    SELECT count(*) INTO v_count
    FROM auditoria.historial_estados
    WHERE id_solicitud = v_solicitud
      AND estado_anterior = 'pending'
      AND estado_nuevo = 'in_progress'
      AND id_usuario = v_operador
      AND observacion = 'Operador en camino';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger de historial no registró el cambio';
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'emergency_status'
      AND entidad = 'solicitud'
      AND entidad_id = v_solicitud
      AND id_usuario = v_operador;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger no registró la actividad del cambio';
    END IF;

    SELECT actualizado_en INTO v_actualizado
    FROM public.solicitudes_sos
    WHERE id_solicitud = v_solicitud;
    IF v_actualizado IS NULL THEN
        RAISE EXCEPTION 'El trigger no actualizó actualizado_en';
    END IF;

    -- Procedimiento de comunicación adicional (retransmisión/duplicado).
    CALL public.sp_registrar_comunicacion(
        v_solicitud,
        v_dispositivo,
        'duplicado',
        now()::timestamptz,
        v_registro
    );
    SELECT count(*) INTO v_count
    FROM public.registros_comunicacion
    WHERE id_solicitud = v_solicitud;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'sp_registrar_comunicacion no insertó el registro';
    END IF;

    -- Procedimiento de dispositivos.
    CALL public.sp_registrar_dispositivo(
        'NODE-EXTRA'::text,
        v_extra,
        'Nodo extra'::text,
        'emisor'::text,
        'activo'::text
    );
    SELECT count(*) INTO v_count
    FROM public.dispositivos
    WHERE codigo = 'NODE-EXTRA';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sp_registrar_dispositivo no creó el dispositivo';
    END IF;

    -- Login: último acceso + actividad.
    CALL public.sp_login_exitoso(v_operador);
    SELECT count(*) INTO v_count
    FROM public.usuarios
    WHERE id_usuario = v_operador
      AND ultimo_acceso IS NOT NULL;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sp_login_exitoso no actualizó ultimo_acceso';
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'login' AND id_usuario = v_operador;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sp_login_exitoso no registró la actividad';
    END IF;

    -- Logout: incrementa token_version e invalida JWT anteriores.
    SELECT token_version INTO v_token_antes
    FROM public.usuarios WHERE id_usuario = v_operador;

    CALL public.sp_logout_usuario(v_operador);

    SELECT token_version INTO v_token_despues
    FROM public.usuarios WHERE id_usuario = v_operador;
    IF v_token_despues <> v_token_antes + 1 THEN
        RAISE EXCEPTION 'sp_logout_usuario no incrementó token_version';
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'logout' AND id_usuario = v_operador;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sp_logout_usuario no registró la actividad';
    END IF;

    -- Auditoría genérica.
    CALL public.sp_registrar_actividad(
        v_operador,
        'test_event',
        'Evento de prueba',
        NULL,
        NULL
    );
    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'test_event' AND id_usuario = v_operador;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sp_registrar_actividad no registró el evento';
    END IF;

    -- Trigger de auditoría de cuentas.
    PERFORM set_config('app.current_user_id', v_admin::text, true);
    INSERT INTO public.usuarios (nombre, usuario, correo, contrasena, rol)
    VALUES ('Cuenta Temporal', 'temporal', 'temporal@sosnet.local', 'x', 'operador');

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'user_create'
      AND id_usuario = v_admin
      AND descripcion LIKE '%Cuenta Temporal%';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger no auditó la creación de usuario';
    END IF;

    UPDATE public.usuarios
    SET nombre = 'Cuenta Temporal Editada'
    WHERE usuario = 'temporal';

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'user_update'
      AND id_usuario = v_admin
      AND descripcion LIKE '%Cuenta Temporal Editada%';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger no auditó la edición de usuario';
    END IF;

    DELETE FROM public.usuarios WHERE usuario = 'temporal';
    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'user_delete' AND id_usuario = v_admin;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger no auditó la eliminación de usuario';
    END IF;

    -- Trigger de configuración: fecha automática + auditoría.
    SELECT actualizado_en INTO v_config_actualizado
    FROM public.configuracion_central WHERE id_configuracion = 1;

    UPDATE public.configuracion_central
    SET nombre = 'Central de pruebas'
    WHERE id_configuracion = 1;

    SELECT count(*) INTO v_count
    FROM public.configuracion_central
    WHERE id_configuracion = 1
      AND actualizado_en >= v_config_actualizado
      AND nombre = 'Central de pruebas';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger de configuración no actualizó la fecha';
    END IF;

    SELECT count(*) INTO v_count
    FROM auditoria.actividad
    WHERE accion = 'settings_update' AND id_usuario = v_admin;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'El trigger no auditó la configuración';
    END IF;

    -- Validación del procedimiento de retención.
    BEGIN
        CALL public.sp_purgar_solicitudes_antiguas(0, true, v_purgadas);
        RAISE EXCEPTION 'sp_purgar aceptó días inválidos';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    CALL public.sp_purgar_solicitudes_antiguas(9999, true, v_purgadas);

    RAISE NOTICE '03_procedures_triggers: OK (8 procedimientos y 5 triggers probados)';
END;
$$;

ROLLBACK;
