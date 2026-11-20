
CREATE OR REPLACE PROCEDURE public.sp_registrar_dispositivo(
    p_codigo text,
    INOUT p_id_dispositivo integer DEFAULT NULL,
    p_nombre text DEFAULT NULL,
    p_tipo text DEFAULT 'desconocido',
    p_estado text DEFAULT 'activo'
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_codigo varchar(50);
    v_nombre varchar(100);
    v_tipo   varchar(30);
    v_estado varchar(20);
BEGIN
    v_codigo := left(COALESCE(NULLIF(btrim(p_codigo), ''), 'DESCONOCIDO'), 50);
    v_nombre := left(COALESCE(NULLIF(btrim(p_nombre), ''), v_codigo), 100);
    v_tipo   := lower(COALESCE(NULLIF(btrim(p_tipo), ''), 'desconocido'));
    v_estado := lower(COALESCE(NULLIF(btrim(p_estado), ''), 'activo'));

    IF v_tipo NOT IN ('web', 'desconocido') THEN
        RAISE EXCEPTION 'Tipo de dispositivo no válido: %', v_tipo
            USING ERRCODE = '22023';
    END IF;
    IF v_estado NOT IN ('activo', 'inactivo', 'mantenimiento') THEN
        RAISE EXCEPTION 'Estado de dispositivo no válido: %', v_estado
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.dispositivos (codigo, nombre, tipo, estado)
    VALUES (v_codigo, v_nombre, v_tipo, v_estado)
    ON CONFLICT (codigo) DO NOTHING;

    SELECT d.id_dispositivo
    INTO p_id_dispositivo
    FROM public.dispositivos AS d
    WHERE d.codigo = v_codigo;
END;
$$;

COMMENT ON PROCEDURE public.sp_registrar_dispositivo(text, integer, text, text, text) IS
  'Alta idempotente de un dispositivo; devuelve su ID existente o nuevo.';

-- ----------------------------------------------------------------------------
-- Registrar una comunicación recibida
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_registrar_comunicacion(
    p_id_solicitud integer,
    p_id_dispositivo integer,
    p_estado_recepcion text DEFAULT 'recibido',
    p_fecha_recepcion timestamptz DEFAULT now(),
    INOUT p_id_registro integer DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_estado varchar(30);
    v_fecha  timestamptz;
BEGIN
    v_estado := lower(COALESCE(NULLIF(btrim(p_estado_recepcion), ''), 'recibido'));
    v_fecha  := COALESCE(p_fecha_recepcion, now());

    IF v_estado NOT IN ('recibido', 'duplicado', 'error') THEN
        RAISE EXCEPTION 'Estado de recepción no válido: %', v_estado
            USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.solicitudes_sos WHERE id_solicitud = p_id_solicitud
    ) THEN
        RAISE EXCEPTION 'Solicitud % no encontrada', p_id_solicitud
            USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.dispositivos WHERE id_dispositivo = p_id_dispositivo
    ) THEN
        RAISE EXCEPTION 'Dispositivo % no encontrado', p_id_dispositivo
            USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.registros_comunicacion (
        id_solicitud, id_dispositivo, fecha_recepcion, estado_recepcion
    )
    VALUES (p_id_solicitud, p_id_dispositivo, v_fecha, v_estado)
    RETURNING id_registro INTO p_id_registro;
END;
$$;

COMMENT ON PROCEDURE public.sp_registrar_comunicacion(integer, integer, text, timestamptz, integer) IS
  'Registra la recepción de un mensaje SOS para una solicitud existente.';

-- ----------------------------------------------------------------------------
-- Registrar una solicitud SOS completa
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_registrar_solicitud(
    p_codigo_mensaje text,
    p_nombre_solicitante text,
    p_tipo_nombre text,
    p_dispositivo_codigo text,
    p_ubicacion text,
    p_cantidad_personas integer,
    p_descripcion text,
    p_prioridad text,
    p_fecha_recepcion timestamptz,
    OUT p_id_solicitud integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_codigo          varchar(50);
    v_nombre          varchar(100);
    v_tipo            varchar(100);
    v_dispositivo     varchar(50);
    v_ubicacion       varchar(255);
    v_descripcion     varchar(500);
    v_prioridad       varchar(20);
    v_personas        integer;
    v_fecha           timestamptz;
    v_id_tipo         integer;
    v_id_dispositivo  integer;
    v_id_registro     integer;
BEGIN
    v_codigo := left(
        COALESCE(NULLIF(btrim(p_codigo_mensaje), ''), public.fn_generar_codigo_mensaje()),
        50
    );
    v_nombre := left(NULLIF(btrim(p_nombre_solicitante), ''), 100);
    v_tipo := left(COALESCE(NULLIF(btrim(p_tipo_nombre), ''), 'Otra'), 100);
    v_dispositivo := left(
        COALESCE(NULLIF(btrim(p_dispositivo_codigo), ''), 'DESCONOCIDO'),
        50
    );
    v_ubicacion := left(
        COALESCE(NULLIF(btrim(p_ubicacion), ''), 'No indicada'),
        255
    );
    v_descripcion := left(
        COALESCE(NULLIF(btrim(p_descripcion), ''), 'Solicitud de emergencia'),
        500
    );
    v_prioridad := lower(COALESCE(NULLIF(btrim(p_prioridad), ''), 'media'));
    v_personas := COALESCE(p_cantidad_personas, 1);
    v_fecha := COALESCE(p_fecha_recepcion, now());

    IF v_personas < 1 OR v_personas > 1000 THEN
        RAISE EXCEPTION 'La cantidad de personas debe estar entre 1 y 1000'
            USING ERRCODE = '22023';
    END IF;
    IF v_prioridad NOT IN ('alta', 'media', 'baja') THEN
        RAISE EXCEPTION 'La prioridad debe ser alta, media o baja'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.tipos_emergencia (nombre)
    VALUES (v_tipo)
    ON CONFLICT (nombre) DO UPDATE SET nombre = EXCLUDED.nombre
    RETURNING id_tipo INTO v_id_tipo;

    CALL public.sp_registrar_dispositivo(
        p_codigo => v_dispositivo,
        p_id_dispositivo => v_id_dispositivo,
        p_nombre => v_dispositivo,
        p_tipo => 'desconocido',
        p_estado => 'activo'
    );

    INSERT INTO public.solicitudes_sos (
        codigo_mensaje,
        nombre_solicitante,
        id_tipo,
        id_dispositivo,
        ubicacion,
        cantidad_personas,
        descripcion,
        prioridad,
        estado,
        fecha_recepcion
    )
    VALUES (
        v_codigo,
        v_nombre,
        v_id_tipo,
        v_id_dispositivo,
        v_ubicacion,
        v_personas,
        v_descripcion,
        v_prioridad,
        'pending',
        v_fecha
    )
    RETURNING id_solicitud INTO p_id_solicitud;

    CALL public.sp_registrar_comunicacion(
        p_id_solicitud => p_id_solicitud,
        p_id_dispositivo => v_id_dispositivo,
        p_estado_recepcion => 'recibido',
        p_fecha_recepcion => v_fecha,
        p_id_registro => v_id_registro
    );
END;
$$;

COMMENT ON PROCEDURE public.sp_registrar_solicitud(text, text, text, text, text, integer, text, text, timestamptz, integer) IS
  'Crea tipo/dispositivo si faltan, registra la solicitud y su comunicación en una sola transacción.';

-- ----------------------------------------------------------------------------
-- Actualizar el estado de una solicitud
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_actualizar_estado(
    p_id_solicitud integer,
    p_nuevo_estado text,
    p_id_usuario integer,
    p_observacion text DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_estado_anterior varchar(30);
    v_nuevo_estado    varchar(30);
BEGIN
    v_nuevo_estado := lower(COALESCE(NULLIF(btrim(p_nuevo_estado), ''), ''));
    IF v_nuevo_estado NOT IN ('pending', 'in_progress', 'resolved') THEN
        RAISE EXCEPTION 'Estado no válido: %', p_nuevo_estado
            USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id_usuario = p_id_usuario
          AND activo
          AND rol IN ('admin', 'operador')
    ) THEN
        RAISE EXCEPTION 'Usuario % no autorizado para cambiar estados', p_id_usuario
            USING ERRCODE = '42501';
    END IF;

    SELECT estado
    INTO v_estado_anterior
    FROM public.solicitudes_sos
    WHERE id_solicitud = p_id_solicitud
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitud % no encontrada', p_id_solicitud
            USING ERRCODE = 'P0002';
    END IF;

    IF v_estado_anterior = v_nuevo_estado THEN
        RETURN;
    END IF;

    PERFORM set_config('app.current_user_id', p_id_usuario::text, true);
    PERFORM set_config(
        'app.current_observation',
        left(COALESCE(btrim(p_observacion), ''), 255),
        true
    );

    UPDATE public.solicitudes_sos
    SET estado = v_nuevo_estado
    WHERE id_solicitud = p_id_solicitud;

    -- El trigger trg_sos_historial_estado registra el historial y la actividad.
END;
$$;

COMMENT ON PROCEDURE public.sp_actualizar_estado(integer, text, integer, text) IS
  'Cambia el estado y deja que el trigger registre historial y auditoría.';

-- ----------------------------------------------------------------------------
-- Registrar actividad de auditoría (login, logout, acciones de la API)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_registrar_actividad(
    p_id_usuario integer,
    p_accion text,
    p_descripcion text,
    p_entidad text DEFAULT NULL,
    p_entidad_id integer DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_accion      varchar(50);
    v_descripcion varchar(255);
    v_entidad     varchar(40);
BEGIN
    v_accion := left(COALESCE(NULLIF(btrim(p_accion), ''), 'evento'), 50);
    v_descripcion := left(
        COALESCE(NULLIF(btrim(p_descripcion), ''), 'Evento registrado'),
        255
    );
    v_entidad := left(NULLIF(btrim(p_entidad), ''), 40);

    IF p_id_usuario IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.usuarios WHERE id_usuario = p_id_usuario
    ) THEN
        RAISE EXCEPTION 'Usuario % no encontrado', p_id_usuario
            USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO auditoria.actividad (
        id_usuario, accion, descripcion, entidad, entidad_id, fecha
    )
    VALUES (
        p_id_usuario, v_accion, v_descripcion, v_entidad, p_entidad_id, now()
    );
END;
$$;

COMMENT ON PROCEDURE public.sp_registrar_actividad(integer, text, text, text, integer) IS
  'Inserta una entrada de auditoría con validación de usuario.';

-- ----------------------------------------------------------------------------
-- Login correcto: actualizar último acceso y auditar
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_login_exitoso(p_id_usuario integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.usuarios
    SET ultimo_acceso = now()
    WHERE id_usuario = p_id_usuario
      AND activo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario % inactivo o inexistente', p_id_usuario
            USING ERRCODE = '42501';
    END IF;

    CALL public.sp_registrar_actividad(
        p_id_usuario => p_id_usuario,
        p_accion => 'login',
        p_descripcion => 'Inicio de sesión en la central'
    );
END;
$$;

COMMENT ON PROCEDURE public.sp_login_exitoso(integer) IS
  'Actualiza ultimo_acceso y registra el inicio de sesión en auditoría.';

-- ----------------------------------------------------------------------------
-- Logout: invalida los JWT anteriores y audita
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_logout_usuario(p_id_usuario integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.usuarios
    SET token_version = token_version + 1
    WHERE id_usuario = p_id_usuario;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario % no encontrado', p_id_usuario
            USING ERRCODE = 'P0002';
    END IF;

    CALL public.sp_registrar_actividad(
        p_id_usuario => p_id_usuario,
        p_accion => 'logout',
        p_descripcion => 'Cierre de sesión en la central'
    );
END;
$$;

COMMENT ON PROCEDURE public.sp_logout_usuario(integer) IS
  'Incrementa token_version para invalidar los JWT del usuario y registra el logout.';

-- ----------------------------------------------------------------------------
-- Retención de solicitudes antiguas
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE public.sp_purgar_solicitudes_antiguas(
    p_dias integer,
    p_dry_run boolean,
    OUT p_eliminadas integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_dias IS NULL OR p_dias < 1 THEN
        RAISE EXCEPTION 'Los días de retención deben ser mayores que cero'
            USING ERRCODE = '22023';
    END IF;

    IF p_dry_run THEN
        SELECT count(*)
        INTO p_eliminadas
        FROM public.solicitudes_sos
        WHERE fecha_recepcion < now() - make_interval(days => p_dias);
        RETURN;
    END IF;

    DELETE FROM public.solicitudes_sos
    WHERE fecha_recepcion < now() - make_interval(days => p_dias);

    GET DIAGNOSTICS p_eliminadas = ROW_COUNT;
END;
$$;

COMMENT ON PROCEDURE public.sp_purgar_solicitudes_antiguas(integer, boolean, integer) IS
  'Elimina solicitudes fuera de retención; los registros e historial caen por CASCADE.';

-- Ejecución restringida: los grants explícitos se definen en 07_roles.sql.
REVOKE ALL ON PROCEDURE public.sp_registrar_dispositivo(text, integer, text, text, text) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_registrar_comunicacion(integer, integer, text, timestamptz, integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_registrar_solicitud(text, text, text, text, text, integer, text, text, timestamptz, integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_actualizar_estado(integer, text, integer, text) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_registrar_actividad(integer, text, text, text, integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_login_exitoso(integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_logout_usuario(integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_purgar_solicitudes_antiguas(integer, boolean, integer) FROM PUBLIC;
