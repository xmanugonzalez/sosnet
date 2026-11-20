-- ============================================================================
-- SOSNET · Migración 002 · Seguridad de sesiones, hashes y reportes
--
-- Aplicar una sola vez sobre una base PostgreSQL local creada con los
-- scripts 00 a 09 anteriores a esta corrección. En una instalación nueva,
-- los cambios ya están incluidos en 01/03/04/07/08 y este archivo no es
-- necesario.
-- ============================================================================

BEGIN;

ALTER TABLE public.usuarios
    ADD COLUMN IF NOT EXISTS token_version integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.usuarios.token_version IS
  'Se incrementa al cerrar sesión o cambiar contraseña para invalidar JWT.';

-- Directorio mínimo para historial/reportes: nombre y rol, sin hash ni correo.
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

REVOKE ALL ON FUNCTION public.fn_usuario_directorio(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_usuario_directorio(integer)
    TO sosnet_api, authenticated, sosnet_reporte;

-- El historial ya no depende del JOIN directo a usuarios (que RLS filtraba).
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
    JOIN public.solicitudes_sos AS s ON s.id_solicitud = h.id_solicitud
    LEFT JOIN LATERAL public.fn_usuario_directorio(h.id_usuario) AS u ON true
    WHERE h.id_solicitud = p_id_solicitud
    ORDER BY h.fecha_cambio, h.id_historial;
$$;

-- Logout con invalidación de JWT.
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

REVOKE ALL ON PROCEDURE public.sp_logout_usuario(integer) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE public.sp_logout_usuario(integer) TO sosnet_api;

-- La RPC de alta queda restringida a Flask (sosnet_api).
REVOKE EXECUTE ON PROCEDURE public.sp_registrar_solicitud(
    text, text, text, text, text, integer, text, text, timestamptz, integer
) FROM anon, authenticated;
GRANT EXECUTE ON PROCEDURE public.sp_registrar_solicitud(
    text, text, text, text, text, integer, text, text, timestamptz, integer
) TO sosnet_api;

-- Hashes: solo la función de login (SECURITY DEFINER) los consulta.
REVOKE ALL ON public.usuarios FROM anon;
REVOKE ALL ON public.usuarios FROM authenticated;
GRANT SELECT (
    id_usuario, nombre, usuario, correo, rol, activo,
    ultimo_acceso, fecha_registro
) ON public.usuarios TO authenticated;

REVOKE SELECT ON public.usuarios FROM sosnet_api;
GRANT SELECT (
    id_usuario, nombre, usuario, correo, rol, activo,
    token_version, ultimo_acceso, fecha_registro, supabase_uid
) ON public.usuarios TO sosnet_api;

-- Reportes: historial legible por el rol de reportes sin acceso a usuarios.
GRANT SELECT ON auditoria.historial_estados TO sosnet_reporte;

DROP POLICY IF EXISTS p_historial_reporte_select ON auditoria.historial_estados;
CREATE POLICY p_historial_reporte_select ON auditoria.historial_estados
    FOR SELECT TO sosnet_reporte USING (true);

COMMIT;
