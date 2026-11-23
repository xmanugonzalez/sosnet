-- ============================================================================
-- SOSNET - Migracion 006 - Etiquetas de estado en la actividad
--
-- La auditoria mostraba los valores tecnicos (pending, in_progress, resolved).
-- Se reemplazan por las etiquetas visibles del sistema: Pendiente, En atencion
-- y Resuelta. Tambien corrige las filas ya registradas.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION auditoria.trg_fn_historial_estado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auditoria, pg_temp
AS $$
DECLARE
    v_usuario integer;
    v_observacion varchar(255);
BEGIN
    IF current_setting('app.migration_mode', true) = 'true' THEN
        RETURN NULL;
    END IF;

    v_usuario := COALESCE(
        public.fn_usuario_actual(),
        public.fn_usuario_sistema_id()
    );

    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'No hay usuario para registrar el cambio de estado';
    END IF;

    v_observacion := NULLIF(
        left(COALESCE(current_setting('app.current_observation', true), ''), 255),
        ''
    );

    INSERT INTO auditoria.historial_estados (
        id_solicitud,
        id_usuario,
        estado_anterior,
        estado_nuevo,
        fecha_cambio,
        observacion
    )
    VALUES (
        NEW.id_solicitud,
        v_usuario,
        OLD.estado,
        NEW.estado,
        now(),
        v_observacion
    );

    INSERT INTO auditoria.actividad (
        id_usuario,
        accion,
        descripcion,
        entidad,
        entidad_id,
        fecha
    )
    VALUES (
        v_usuario,
        'emergency_status',
        left(
            NEW.codigo_mensaje
            || ': Estado '
            || CASE OLD.estado
                   WHEN 'pending' THEN 'Pendiente'
                   WHEN 'in_progress' THEN 'En atención'
                   WHEN 'resolved' THEN 'Resuelta'
                   ELSE OLD.estado
               END
            || ' → '
            || CASE NEW.estado
                   WHEN 'pending' THEN 'Pendiente'
                   WHEN 'in_progress' THEN 'En atención'
                   WHEN 'resolved' THEN 'Resuelta'
                   ELSE NEW.estado
               END,
            255
        ),
        'solicitud',
        NEW.id_solicitud,
        now()
    );

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION auditoria.trg_fn_historial_estado() IS
  'Registra historial y auditoria cuando cambia solicitudes_sos.estado.';

UPDATE auditoria.actividad
SET descripcion = regexp_replace(
        regexp_replace(
            regexp_replace(
                regexp_replace(descripcion, 'estado pending', 'Estado: Pendiente', 'g'),
                'estado pendiente',
                'Estado: Pendiente',
                'g'
            ),
            'in_progress',
            'En atención',
            'g'
        ),
        'resolved',
        'Resuelta',
        'g'
    )
WHERE accion = 'emergency_status';

COMMIT;
