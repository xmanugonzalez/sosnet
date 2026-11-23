-- Funciones de apoyo: usuario y rol actuales, datos del JWT, login y reportes.

-- Devuelve el ID de usuario que Flask guarda en la sesión de la base.
CREATE OR REPLACE FUNCTION public.fn_usuario_actual()
RETURNS integer
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::integer;
$$;

COMMENT ON FUNCTION public.fn_usuario_actual() IS
  'ID del usuario de SOSNET fijado por Flask para la transacción actual.';

-- Devuelve el rol (admin, operador o sistema) guardado por Flask.
CREATE OR REPLACE FUNCTION public.fn_rol_actual()
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.current_role', true), '');
$$;

COMMENT ON FUNCTION public.fn_rol_actual() IS
  'Rol funcional (admin/operador/sistema) fijado por Flask para RLS.';

-- Devuelve los datos del JWT externo como JSON; NULL si no hay.
CREATE OR REPLACE FUNCTION public.fn_jwt_claims()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_raw text;
BEGIN
    v_raw := NULLIF(current_setting('request.jwt.claims', true), '');
    IF v_raw IS NULL THEN
        RETURN NULL;
    END IF;
    BEGIN
        RETURN v_raw::jsonb;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;
END;
$$;

COMMENT ON FUNCTION public.fn_jwt_claims() IS
  'Claims JWT que publican los clientes externos en request.jwt.claims.';

-- Extrae un dato del JWT, por ejemplo 'sub' o 'role'.
CREATE OR REPLACE FUNCTION public.fn_jwt_claim(p_claim text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(public.fn_jwt_claims(), '{}'::jsonb) ->> p_claim;
$$;

COMMENT ON FUNCTION public.fn_jwt_claim(text) IS
  'Valor de un claim JWT de primer nivel, o NULL.';

-- Busca el rol dentro del JWT; si no existe, devuelve 'anon'.
CREATE OR REPLACE FUNCTION public.fn_jwt_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        public.fn_jwt_claims() -> 'app_metadata' ->> 'role',
        public.fn_jwt_claims() -> 'user_metadata' ->> 'role',
        public.fn_jwt_claim('role'),
        'anon'
    );
$$;

COMMENT ON FUNCTION public.fn_jwt_role() IS
  'Rol funcional transportado en el JWT externo (app_metadata.role).';

-- Encuentra la cuenta local a partir del UID del JWT externo.
CREATE OR REPLACE FUNCTION public.fn_usuario_externo_actual()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT u.id_usuario
    FROM public.usuarios AS u
    WHERE u.external_uid IS NOT NULL
      AND u.external_uid::text = public.fn_jwt_claim('sub')
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_usuario_externo_actual() IS
  'Mapea un UID externo opcional con la fila correspondiente de public.usuarios.';

-- ID de la cuenta interna 'sistema', usada cuando no hay usuario en sesión.
CREATE OR REPLACE FUNCTION public.fn_usuario_sistema_id()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT u.id_usuario
    FROM public.usuarios AS u
    WHERE u.usuario = 'sistema'
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_usuario_sistema_id() IS
  'Cuenta interna usada como actor de respaldo en triggers de auditoría.';

-- Devuelve solo nombre y rol, sin contraseña ni correo.
CREATE OR REPLACE FUNCTION public.fn_usuario_directorio(p_id_usuario integer)
RETURNS TABLE (
    nombre varchar,
    rol    varchar
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT u.nombre, u.rol
    FROM public.usuarios AS u
    WHERE u.id_usuario = p_id_usuario
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_usuario_directorio(integer) IS
  'Devuelve solo nombre y rol para reportes/historial; nunca el hash ni el correo.';

-- Utilidades
-- Crea códigos como SOS-20251123153000-A1B2C3.
CREATE OR REPLACE FUNCTION public.fn_generar_codigo_mensaje()
RETURNS text
LANGUAGE sql
VOLATILE
AS $$
    SELECT 'SOS-'
        || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS')
        || '-'
        || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
$$;

COMMENT ON FUNCTION public.fn_generar_codigo_mensaje() IS
  'Genera un código único legible para una solicitud SOS.';

-- Login: búsqueda previa a la autenticación
-- Busca la cuenta por correo o usuario; Flask valida la contraseña.
CREATE OR REPLACE FUNCTION public.fn_login_usuario(p_identifier text)
RETURNS TABLE (
    id_usuario    integer,
    nombre        varchar,
    usuario       varchar,
    correo        varchar,
    contrasena    varchar,
    rol           varchar,
    activo        boolean,
    ultimo_acceso timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT u.id_usuario,
           u.nombre,
           u.usuario,
           u.correo,
           u.contrasena,
           u.rol,
           u.activo,
           u.ultimo_acceso
    FROM public.usuarios AS u
    WHERE lower(u.correo) = lower(btrim(p_identifier))
       OR lower(u.usuario) = lower(btrim(p_identifier))
    ORDER BY u.id_usuario
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_login_usuario(text) IS
  'Devuelve la cuenta para validar la contraseña en Flask. Solo para sosnet_api.';

-- Funciones escalares de reporte (un único valor)
-- Total de solicitudes registradas.
CREATE OR REPLACE FUNCTION reportes.fn_total_solicitudes()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT count(*) FROM public.solicitudes_sos;
$$;

-- Cuántas solicitudes siguen pendientes.
CREATE OR REPLACE FUNCTION reportes.fn_solicitudes_pendientes()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT count(*) FROM public.solicitudes_sos WHERE estado = 'pending';
$$;

-- Cuántos dispositivos están activos.
CREATE OR REPLACE FUNCTION reportes.fn_dispositivos_activos()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT count(*) FROM public.dispositivos WHERE estado = 'activo';
$$;

-- Cuenta solicitudes entre dos fechas; valida el rango.
CREATE OR REPLACE FUNCTION reportes.fn_solicitudes_periodo(
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL THEN
        RAISE EXCEPTION 'El período requiere fecha inicial y final'
            USING ERRCODE = '22023';
    END IF;
    IF p_desde > p_hasta THEN
        RAISE EXCEPTION 'La fecha inicial no puede ser posterior a la final'
            USING ERRCODE = '22023';
    END IF;

    RETURN (
        SELECT count(*)
        FROM public.solicitudes_sos
        WHERE fecha_recepcion >= p_desde
          AND fecha_recepcion < p_hasta
    );
END;
$$;

COMMENT ON FUNCTION reportes.fn_solicitudes_periodo(timestamptz, timestamptz) IS
  'Cantidad de solicitudes recibidas en un rango [desde, hasta).';

-- Funciones que retornan tablas.
-- Lista las solicitudes de un estado con su tipo y dispositivo.
CREATE OR REPLACE FUNCTION reportes.fn_solicitudes_por_estado(p_estado text)
RETURNS TABLE (
    id_solicitud      integer,
    codigo_mensaje    varchar,
    tipo              varchar,
    dispositivo       varchar,
    ubicacion         varchar,
    cantidad_personas integer,
    prioridad         varchar,
    estado            varchar,
    fecha_recepcion   timestamptz
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_estado NOT IN ('pending', 'in_progress', 'resolved') THEN
        RAISE EXCEPTION 'Estado no válido: %', p_estado
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT s.id_solicitud,
           s.codigo_mensaje,
           t.nombre AS tipo,
           d.codigo AS dispositivo,
           s.ubicacion,
           s.cantidad_personas,
           s.prioridad,
           s.estado,
           s.fecha_recepcion
    FROM public.solicitudes_sos AS s
    JOIN public.tipos_emergencia AS t ON t.id_tipo = s.id_tipo
    JOIN public.dispositivos AS d ON d.id_dispositivo = s.id_dispositivo
    WHERE s.estado = p_estado
    ORDER BY s.fecha_recepcion DESC;
END;
$$;

COMMENT ON FUNCTION reportes.fn_solicitudes_por_estado(text) IS
  'Solicitudes de un estado con su tipo y dispositivo.';

-- Historial completo de una solicitud, con el operador responsable.
CREATE OR REPLACE FUNCTION reportes.fn_historial_solicitud(p_id_solicitud integer)
RETURNS TABLE (
    id_historial    integer,
    estado_anterior varchar,
    estado_nuevo    varchar,
    usuario         varchar,
    rol             varchar,
    fecha_cambio    timestamptz,
    observacion     varchar
)
LANGUAGE sql
STABLE
AS $$
    SELECT h.id_historial,
           h.estado_anterior,
           h.estado_nuevo,
           COALESCE(u.nombre, 'Sistema') AS usuario,
           COALESCE(u.rol, 'sistema') AS rol,
           h.fecha_cambio,
           h.observacion
    FROM auditoria.historial_estados AS h
    -- El JOIN con solicitudes aplica la RLS de la solicitud que consulta.
    JOIN public.solicitudes_sos AS s ON s.id_solicitud = h.id_solicitud
    -- Se usa un directorio mínimo (nombre/rol) para no filtrar el historial
    -- por la política RLS de public.usuarios ni exponer hashes/correos.
    LEFT JOIN LATERAL public.fn_usuario_directorio(h.id_usuario) AS u ON true
    WHERE h.id_solicitud = p_id_solicitud
    ORDER BY h.fecha_cambio, h.id_historial;
$$;

COMMENT ON FUNCTION reportes.fn_historial_solicitud(integer) IS
  'Historial completo de una solicitud, del más antiguo al más reciente.';

-- Lista solicitudes entre dos fechas; valida el rango.
CREATE OR REPLACE FUNCTION reportes.fn_solicitudes_entre_fechas(
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS TABLE (
    id_solicitud    integer,
    codigo_mensaje  varchar,
    tipo            varchar,
    dispositivo     varchar,
    prioridad       varchar,
    estado          varchar,
    fecha_recepcion timestamptz
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
        RAISE EXCEPTION 'Rango de fechas no válido'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT s.id_solicitud,
           s.codigo_mensaje,
           t.nombre AS tipo,
           d.codigo AS dispositivo,
           s.prioridad,
           s.estado,
           s.fecha_recepcion
    FROM public.solicitudes_sos AS s
    JOIN public.tipos_emergencia AS t ON t.id_tipo = s.id_tipo
    JOIN public.dispositivos AS d ON d.id_dispositivo = s.id_dispositivo
    WHERE s.fecha_recepcion >= p_desde
      AND s.fecha_recepcion < p_hasta
    ORDER BY s.fecha_recepcion DESC;
END;
$$;

COMMENT ON FUNCTION reportes.fn_solicitudes_entre_fechas(timestamptz, timestamptz) IS
  'Solicitudes recibidas en un rango de fechas con tipo y dispositivo.';

-- Totales por tipo de emergencia: solicitudes y personas afectadas.
CREATE OR REPLACE FUNCTION reportes.fn_estadisticas_por_tipo()
RETURNS TABLE (
    tipo        varchar,
    total       bigint,
    pendientes  bigint,
    en_proceso  bigint,
    resueltas   bigint,
    personas    bigint
)
LANGUAGE sql
STABLE
AS $$
    SELECT t.nombre,
           count(s.id_solicitud),
           count(*) FILTER (WHERE s.estado = 'pending'),
           count(*) FILTER (WHERE s.estado = 'in_progress'),
           count(*) FILTER (WHERE s.estado = 'resolved'),
           COALESCE(sum(s.cantidad_personas), 0)
    FROM public.tipos_emergencia AS t
    LEFT JOIN public.solicitudes_sos AS s ON s.id_tipo = t.id_tipo
    GROUP BY t.id_tipo, t.nombre
    ORDER BY count(s.id_solicitud) DESC, t.nombre;
$$;

COMMENT ON FUNCTION reportes.fn_estadisticas_por_tipo() IS
  'Agregado por tipo de emergencia: total, estados y personas afectadas.';

-- Permisos: las funciones de sesión son públicas; las sensibles se bloquean.
GRANT EXECUTE ON FUNCTION public.fn_usuario_actual() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rol_actual() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_jwt_claims() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_jwt_claim(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_jwt_role() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_usuario_externo_actual() TO PUBLIC;

-- Se quitan permisos generales y luego se habilitan solo a los roles necesarios.
REVOKE ALL ON FUNCTION public.fn_login_usuario(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_usuario_sistema_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_usuario_directorio(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_generar_codigo_mensaje() FROM PUBLIC;
