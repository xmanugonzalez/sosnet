-- Crea los roles de la base y les da permisos mínimos según su función.

-- Crear los roles si no existen.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sosnet_api') THEN
        CREATE ROLE sosnet_api NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sosnet_reporte') THEN
        CREATE ROLE sosnet_reporte NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
    END IF;
END;
$$;

-- Los roles no son superusuarios y RLS siempre les aplica.
ALTER ROLE sosnet_api NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
ALTER ROLE sosnet_reporte NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- Permite que los roles se conecten a esta base.
DO $$
BEGIN
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO sosnet_api, sosnet_reporte, anon, authenticated',
        current_database()
    );
END;
$$;

-- El público no puede crear objetos en public; solo usar los esquemas.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public, auditoria, reportes
    TO sosnet_api, sosnet_reporte, anon, authenticated;

-- sosnet_api: DML controlado por RLS, sin DDL
-- La API puede leer y escribir datos, pero RLS filtra las filas.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sosnet_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sosnet_api;
GRANT SELECT ON ALL TABLES IN SCHEMA auditoria TO sosnet_api;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO sosnet_api;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO sosnet_api;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA reportes TO sosnet_api;

-- Funciones y procedimientos sensibles solo para la API.
GRANT EXECUTE ON FUNCTION public.fn_login_usuario(text) TO sosnet_api;
GRANT EXECUTE ON FUNCTION public.fn_usuario_directorio(integer)
    TO sosnet_api, authenticated, sosnet_reporte;
GRANT EXECUTE ON FUNCTION public.fn_generar_codigo_mensaje() TO sosnet_api;
GRANT EXECUTE ON PROCEDURE public.sp_actualizar_estado(integer, text, integer, text)
    TO sosnet_api;
GRANT EXECUTE ON PROCEDURE public.sp_registrar_actividad(integer, text, text, text, integer)
    TO sosnet_api;
GRANT EXECUTE ON PROCEDURE public.sp_login_exitoso(integer) TO sosnet_api;
GRANT EXECUTE ON PROCEDURE public.sp_logout_usuario(integer) TO sosnet_api;
GRANT EXECUTE ON PROCEDURE public.sp_purgar_solicitudes_antiguas(integer, boolean, integer)
    TO sosnet_api;

-- anon / authenticated: privilegios para las pruebas de RLS.
-- RLS decide qué filas y operaciones se permiten.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
    TO anon, authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO authenticated;

GRANT SELECT ON auditoria.actividad, auditoria.historial_estados TO authenticated;

-- Protección de hashes: ningún rol de cliente/API puede leer contrasena.
-- La única vía es fn_login_usuario(), SECURITY DEFINER y solo para sosnet_api.
REVOKE ALL ON public.usuarios FROM anon;
REVOKE ALL ON public.usuarios FROM authenticated;

-- authenticated solo ve datos básicos, nunca la contraseña.
GRANT SELECT (
    id_usuario, nombre, usuario, correo, rol, activo,
    ultimo_acceso, fecha_registro
) ON public.usuarios TO authenticated;

-- sosnet_api ve token_version y external_uid, pero no la contraseña.
REVOKE SELECT ON public.usuarios FROM sosnet_api;
GRANT SELECT (
    id_usuario, nombre, usuario, correo, rol, activo,
    token_version, ultimo_acceso, fecha_registro, external_uid
) ON public.usuarios TO sosnet_api;

-- Las altas públicas de SOS pasan por Flask, que aplica el límite de 30/min.
-- anon/authenticated no ejecutan el procedimiento directamente en local.
GRANT EXECUTE ON PROCEDURE public.sp_registrar_solicitud(
    text, text, text, text, text, integer, text, text, timestamptz, integer
) TO sosnet_api;

GRANT EXECUTE ON ALL ROUTINES IN SCHEMA reportes TO authenticated;

-- sosnet_reporte: solo datos operativos y agregados, nunca usuarios/hashes.

GRANT SELECT ON public.solicitudes_sos,
                public.tipos_emergencia,
                public.dispositivos,
                public.registros_comunicacion
    TO sosnet_reporte;

-- Necesario para fn_historial_solicitud (solo lectura de auditoría).
GRANT SELECT ON auditoria.historial_estados TO sosnet_reporte;

GRANT SELECT ON reportes.vw_estadisticas_emergencias,
                reportes.vw_solicitudes_por_tipo,
                reportes.vw_resumen_dispositivos
    TO sosnet_reporte;

GRANT EXECUTE ON ALL ROUTINES IN SCHEMA reportes TO sosnet_reporte;
