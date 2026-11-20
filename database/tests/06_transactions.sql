-- ============================================================================
-- SOSNET · Pruebas SQL · 06 Transacciones (COMMIT y ROLLBACK)
-- ============================================================================
\set ON_ERROR_STOP on

-- ----------------------------------------------------------------------------
-- COMMIT: la solicitud queda persistida.
-- ----------------------------------------------------------------------------
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-TX-COMMIT'::text, 'Commit'::text, 'Inundación'::text,
    'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
    'Confirmada'::text, 'media'::text, now()::timestamptz, NULL
);
COMMIT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-TX-COMMIT'
    ) THEN
        RAISE EXCEPTION 'COMMIT no persistió la solicitud';
    END IF;
    RAISE NOTICE '06_transactions COMMIT: OK';
END;
$$;

-- ----------------------------------------------------------------------------
-- ROLLBACK explícito: no queda rastro.
-- ----------------------------------------------------------------------------
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-TX-ROLLBACK'::text, 'Rollback'::text, 'Evacuación'::text,
    'FORMULARIO-SOS'::text, 'Luque'::text, 1,
    'No debe persistir'::text, 'alta'::text, now()::timestamptz, NULL
);
ROLLBACK;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-TX-ROLLBACK'
    ) THEN
        RAISE EXCEPTION 'ROLLBACK dejó una solicitud persistida';
    END IF;
    RAISE NOTICE '06_transactions ROLLBACK: OK';
END;
$$;

-- ----------------------------------------------------------------------------
-- Fallo dentro del procedimiento: se revierten tipo, dispositivo y solicitud.
-- ----------------------------------------------------------------------------
BEGIN;
CALL public.sp_registrar_solicitud(
    'SOS-TX-BASE'::text, 'Base'::text, 'Inundación'::text,
    'FORMULARIO-SOS'::text, 'Asunción'::text, 1,
    'Solicitud base'::text, 'media'::text, now()::timestamptz, NULL
);
COMMIT;

BEGIN;
DO $$
DECLARE
    v_id integer;
BEGIN
    BEGIN
        CALL public.sp_registrar_solicitud(
            'SOS-TX-BASE'::text, 'Duplicada'::text,
            'TipoQueNoDebeQuedar'::text, 'DISPOSITIVO-QUE-NO-DEBE-QUEDAR'::text,
            'Asunción'::text, 1, 'Duplicada'::text, 'alta'::text,
            now()::timestamptz, v_id
        );
        RAISE EXCEPTION 'El procedimiento aceptó un código duplicado';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.tipos_emergencia WHERE nombre = 'TipoQueNoDebeQuedar'
    ) THEN
        RAISE EXCEPTION 'El tipo creado antes del fallo no se revirtió';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.dispositivos WHERE codigo = 'DISPOSITIVO-QUE-NO-DEBE-QUEDAR'
    ) THEN
        RAISE EXCEPTION 'El dispositivo creado antes del fallo no se revirtió';
    END IF;
    RAISE NOTICE '06_transactions fallo parcial: OK (todo revertido)';
END;
$$;
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Cambio de estado revertido.
-- ----------------------------------------------------------------------------
BEGIN;
DO $$
DECLARE
    v_solicitud integer;
    v_operador integer;
BEGIN
    SELECT id_solicitud INTO v_solicitud
    FROM public.solicitudes_sos WHERE codigo_mensaje = 'SOS-TX-BASE';
    SELECT id_usuario INTO v_operador
    FROM public.usuarios WHERE usuario = 'operador';
    CALL public.sp_actualizar_estado(
        v_solicitud, 'resolved', v_operador, 'No debe persistir'
    );
END;
$$;
ROLLBACK;

DO $$
DECLARE
    v_estado varchar;
    v_historial integer;
BEGIN
    SELECT estado INTO v_estado
    FROM public.solicitudes_sos
    WHERE codigo_mensaje = 'SOS-TX-BASE';

    SELECT count(*) INTO v_historial
    FROM auditoria.historial_estados h
    JOIN public.solicitudes_sos s ON s.id_solicitud = h.id_solicitud
    WHERE s.codigo_mensaje = 'SOS-TX-BASE';

    IF v_estado <> 'pending' THEN
        RAISE EXCEPTION 'El ROLLBACK dejó el estado en %', v_estado;
    END IF;
    IF v_historial <> 0 THEN
        RAISE EXCEPTION 'El ROLLBACK dejó % filas de historial', v_historial;
    END IF;

    RAISE NOTICE '06_transactions estado: OK (historial revertido)';
END;
$$;

-- Limpieza de las filas confirmadas por esta prueba.
DELETE FROM public.solicitudes_sos
WHERE codigo_mensaje IN ('SOS-TX-COMMIT', 'SOS-TX-BASE');

DELETE FROM public.tipos_emergencia
WHERE nombre = 'TipoQueNoDebeQuedar';

DELETE FROM public.dispositivos
WHERE codigo = 'DISPOSITIVO-QUE-NO-DEBE-QUEDAR';

SELECT '06_transactions: OK' AS resultado;
