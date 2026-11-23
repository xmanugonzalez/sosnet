-- Disparadores automáticos: fechas de modificación, historial de estados y auditoría.

-- 1. Fecha de modificación de solicitudes

-- Actualiza la fecha de modificación en cada cambio.
CREATE OR REPLACE FUNCTION public.trg_fn_solicitud_actualizada()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_fn_solicitud_actualizada() IS
  'Actualiza solicitudes_sos.actualizado_en en cada modificación.';

-- 2. Historial y auditoría automáticos del cambio de estado

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
    -- Durante una migración se omite la auditoría.
    IF current_setting('app.migration_mode', true) = 'true' THEN
        RETURN NULL;
    END IF;

    -- Usuario que hizo el cambio; si no hay, usa la cuenta 'sistema'.
    v_usuario := COALESCE(
        public.fn_usuario_actual(),
        public.fn_usuario_sistema_id()
    );

    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'No hay usuario para registrar el cambio de estado';
    END IF;

    -- Toma la observación que dejó el procedimiento.
    v_observacion := NULLIF(
        left(COALESCE(current_setting('app.current_observation', true), ''), 255),
        ''
    );

    -- Guarda el cambio en el historial.
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

    -- Guarda también la actividad con texto legible.
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
  'Registra historial y auditoría cuando cambia solicitudes_sos.estado.';

-- 3. Auditoría automática de cuentas

CREATE OR REPLACE FUNCTION auditoria.trg_fn_usuarios_auditoria()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auditoria, pg_temp
AS $$
DECLARE
    v_actor   integer;
    v_accion  varchar(50);
    v_desc    varchar(255);
    v_cambios text;
BEGIN
    -- La carga inicial (seed) desactiva la auditoría para no generar ruido.
    IF current_setting('app.audit_enabled', true) = 'false' THEN
        RETURN NULL;
    END IF;

    v_actor := COALESCE(public.fn_usuario_actual(), public.fn_usuario_sistema_id());
    IF v_actor IS NULL THEN
        RETURN NULL;
    END IF;

    -- Decide la acción y el mensaje según INSERT, UPDATE o DELETE.
    IF TG_OP = 'INSERT' THEN
        v_accion := 'user_create';
        v_desc := left(
            'Se creó la cuenta de ' || NEW.nombre || ' (' || NEW.rol || ')',
            255
        );
    ELSIF TG_OP = 'UPDATE' THEN
        -- Detecta qué campos cambiaron.
        v_cambios := concat_ws(
            ', ',
            CASE WHEN OLD.nombre IS DISTINCT FROM NEW.nombre THEN 'nombre' END,
            CASE WHEN OLD.usuario IS DISTINCT FROM NEW.usuario THEN 'usuario' END,
            CASE WHEN OLD.correo IS DISTINCT FROM NEW.correo THEN 'correo' END,
            CASE WHEN OLD.rol IS DISTINCT FROM NEW.rol THEN 'rol' END,
            CASE WHEN OLD.activo IS DISTINCT FROM NEW.activo THEN 'activo' END,
            CASE WHEN OLD.contrasena IS DISTINCT FROM NEW.contrasena THEN 'contraseña' END
        );

        IF v_cambios IS NULL THEN
            RETURN NULL;
        END IF;

        v_accion := 'user_update';
        v_desc := left(
            'Se actualizó la cuenta de ' || NEW.nombre || ': ' || v_cambios,
            255
        );
    ELSE
        v_accion := 'user_delete';
        v_desc := left('Se eliminó la cuenta de ' || OLD.nombre, 255);
    END IF;

    INSERT INTO auditoria.actividad (
        id_usuario,
        accion,
        descripcion,
        entidad,
        entidad_id,
        fecha
    )
    VALUES (
        v_actor,
        v_accion,
        v_desc,
        'usuario',
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id_usuario ELSE NEW.id_usuario END,
        now()
    );

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION auditoria.trg_fn_usuarios_auditoria() IS
  'Audita creación, cambios relevantes y eliminación de cuentas.';

-- 4 y 5. Configuración de la central
-- Actualiza la fecha de modificación de la configuración.
CREATE OR REPLACE FUNCTION public.trg_fn_configuracion_actualizada()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;

-- Registra quién cambió la configuración.
CREATE OR REPLACE FUNCTION auditoria.trg_fn_configuracion_auditoria()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auditoria, pg_temp
AS $$
DECLARE
    v_actor integer;
BEGIN
    IF current_setting('app.audit_enabled', true) = 'false' THEN
        RETURN NULL;
    END IF;

    v_actor := COALESCE(public.fn_usuario_actual(), public.fn_usuario_sistema_id());
    IF v_actor IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO auditoria.actividad (
        id_usuario,
        accion,
        descripcion,
        entidad,
        entidad_id,
        fecha
    )
    VALUES (
        v_actor,
        'settings_update',
        'Se actualizó la identificación de la central',
        'configuracion',
        NEW.id_configuracion,
        now()
    );

    RETURN NULL;
END;
$$;

-- Creación de triggers
-- Antes de actualizar una solicitud, cambia actualizado_en.
DROP TRIGGER IF EXISTS trg_solicitud_actualizada ON public.solicitudes_sos;
CREATE TRIGGER trg_solicitud_actualizada
    BEFORE UPDATE ON public.solicitudes_sos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_solicitud_actualizada();

-- Si cambia el estado, guarda historial y actividad.
DROP TRIGGER IF EXISTS trg_sos_historial_estado ON public.solicitudes_sos;
CREATE TRIGGER trg_sos_historial_estado
    AFTER UPDATE OF estado ON public.solicitudes_sos
    FOR EACH ROW
    WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION auditoria.trg_fn_historial_estado();

-- Audita altas, cambios y bajas de cuentas.
DROP TRIGGER IF EXISTS trg_usuarios_auditoria ON public.usuarios;
CREATE TRIGGER trg_usuarios_auditoria
    AFTER INSERT OR UPDATE OF nombre, usuario, correo, rol, activo, contrasena OR DELETE
    ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION auditoria.trg_fn_usuarios_auditoria();

-- Configuración: fecha automática y auditoría.
DROP TRIGGER IF EXISTS trg_configuracion_actualizada ON public.configuracion_central;
CREATE TRIGGER trg_configuracion_actualizada
    BEFORE UPDATE ON public.configuracion_central
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_configuracion_actualizada();

DROP TRIGGER IF EXISTS trg_configuracion_auditoria ON public.configuracion_central;
CREATE TRIGGER trg_configuracion_auditoria
    AFTER UPDATE ON public.configuracion_central
    FOR EACH ROW
    WHEN (OLD.nombre IS DISTINCT FROM NEW.nombre OR OLD.ubicacion IS DISTINCT FROM NEW.ubicacion)
    EXECUTE FUNCTION auditoria.trg_fn_configuracion_auditoria();

-- Las funciones de trigger no se ejecutan a mano.
REVOKE ALL ON FUNCTION public.trg_fn_solicitud_actualizada() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditoria.trg_fn_historial_estado() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditoria.trg_fn_usuarios_auditoria() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.trg_fn_configuracion_actualizada() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditoria.trg_fn_configuracion_auditoria() FROM PUBLIC;
