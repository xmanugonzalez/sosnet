
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_emergencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion_central ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_sos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registros_comunicacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria.historial_estados ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria.actividad ENABLE ROW LEVEL SECURITY;

-- Usuarios

DROP POLICY IF EXISTS p_usuarios_api_select ON public.usuarios;
CREATE POLICY p_usuarios_api_select ON public.usuarios
    FOR SELECT TO sosnet_api
    USING (
        id_usuario = public.fn_usuario_actual()
        OR public.fn_rol_actual() = 'admin'
    );

DROP POLICY IF EXISTS p_usuarios_api_insert ON public.usuarios;
CREATE POLICY p_usuarios_api_insert ON public.usuarios
    FOR INSERT TO sosnet_api
    WITH CHECK (public.fn_rol_actual() = 'admin');

DROP POLICY IF EXISTS p_usuarios_api_update ON public.usuarios;
CREATE POLICY p_usuarios_api_update ON public.usuarios
    FOR UPDATE TO sosnet_api
    USING (public.fn_rol_actual() = 'admin')
    WITH CHECK (public.fn_rol_actual() = 'admin');

DROP POLICY IF EXISTS p_usuarios_api_delete ON public.usuarios;
CREATE POLICY p_usuarios_api_delete ON public.usuarios
    FOR DELETE TO sosnet_api
    USING (public.fn_rol_actual() = 'admin');

DROP POLICY IF EXISTS p_usuarios_auth_select ON public.usuarios;
CREATE POLICY p_usuarios_auth_select ON public.usuarios
    FOR SELECT TO authenticated
    USING (
        id_usuario = public.fn_usuario_externo_actual()
        OR public.fn_jwt_role() = 'admin'
    );


-- Tipos de emergencia

DROP POLICY IF EXISTS p_tipos_api_select ON public.tipos_emergencia;
CREATE POLICY p_tipos_api_select ON public.tipos_emergencia
    FOR SELECT TO sosnet_api USING (true);

DROP POLICY IF EXISTS p_tipos_auth_select ON public.tipos_emergencia;
CREATE POLICY p_tipos_auth_select ON public.tipos_emergencia
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS p_tipos_reporte_select ON public.tipos_emergencia;
CREATE POLICY p_tipos_reporte_select ON public.tipos_emergencia
    FOR SELECT TO sosnet_reporte USING (true);

-- Dispositivos

DROP POLICY IF EXISTS p_dispositivos_api_select ON public.dispositivos;
CREATE POLICY p_dispositivos_api_select ON public.dispositivos
    FOR SELECT TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin', 'sistema'));

DROP POLICY IF EXISTS p_dispositivos_auth_select ON public.dispositivos;
CREATE POLICY p_dispositivos_auth_select ON public.dispositivos
    FOR SELECT TO authenticated
    USING (public.fn_jwt_role() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_dispositivos_reporte_select ON public.dispositivos;
CREATE POLICY p_dispositivos_reporte_select ON public.dispositivos
    FOR SELECT TO sosnet_reporte USING (true);

-- Configuración de la central

DROP POLICY IF EXISTS p_configuracion_api_select ON public.configuracion_central;
CREATE POLICY p_configuracion_api_select ON public.configuracion_central
    FOR SELECT TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin', 'sistema'));

DROP POLICY IF EXISTS p_configuracion_api_insert ON public.configuracion_central;
CREATE POLICY p_configuracion_api_insert ON public.configuracion_central
    FOR INSERT TO sosnet_api
    WITH CHECK (public.fn_rol_actual() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_configuracion_api_update ON public.configuracion_central;
CREATE POLICY p_configuracion_api_update ON public.configuracion_central
    FOR UPDATE TO sosnet_api
    USING (public.fn_rol_actual() = 'admin')
    WITH CHECK (public.fn_rol_actual() = 'admin');

DROP POLICY IF EXISTS p_configuracion_auth_select ON public.configuracion_central;
CREATE POLICY p_configuracion_auth_select ON public.configuracion_central
    FOR SELECT TO authenticated USING (true);

-- Solicitudes SOS

DROP POLICY IF EXISTS p_solicitudes_api_select ON public.solicitudes_sos;
CREATE POLICY p_solicitudes_api_select ON public.solicitudes_sos
    FOR SELECT TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin', 'sistema'));

DROP POLICY IF EXISTS p_solicitudes_api_update ON public.solicitudes_sos;
CREATE POLICY p_solicitudes_api_update ON public.solicitudes_sos
    FOR UPDATE TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin'))
    WITH CHECK (public.fn_rol_actual() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_solicitudes_api_delete ON public.solicitudes_sos;
CREATE POLICY p_solicitudes_api_delete ON public.solicitudes_sos
    FOR DELETE TO sosnet_api
    USING (public.fn_rol_actual() = 'admin');

DROP POLICY IF EXISTS p_solicitudes_auth_select ON public.solicitudes_sos;
CREATE POLICY p_solicitudes_auth_select ON public.solicitudes_sos
    FOR SELECT TO authenticated
    USING (public.fn_jwt_role() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_solicitudes_reporte_select ON public.solicitudes_sos;
CREATE POLICY p_solicitudes_reporte_select ON public.solicitudes_sos
    FOR SELECT TO sosnet_reporte USING (true);

-- Registros de comunicación

DROP POLICY IF EXISTS p_registros_api_select ON public.registros_comunicacion;
CREATE POLICY p_registros_api_select ON public.registros_comunicacion
    FOR SELECT TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin', 'sistema'));

DROP POLICY IF EXISTS p_registros_auth_select ON public.registros_comunicacion;
CREATE POLICY p_registros_auth_select ON public.registros_comunicacion
    FOR SELECT TO authenticated
    USING (public.fn_jwt_role() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_registros_reporte_select ON public.registros_comunicacion;
CREATE POLICY p_registros_reporte_select ON public.registros_comunicacion
    FOR SELECT TO sosnet_reporte USING (true);

-- Historial de estados (auditoría)

DROP POLICY IF EXISTS p_historial_api_select ON auditoria.historial_estados;
CREATE POLICY p_historial_api_select ON auditoria.historial_estados
    FOR SELECT TO sosnet_api
    USING (public.fn_rol_actual() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_historial_auth_select ON auditoria.historial_estados;
CREATE POLICY p_historial_auth_select ON auditoria.historial_estados
    FOR SELECT TO authenticated
    USING (public.fn_jwt_role() IN ('operador', 'admin'));

DROP POLICY IF EXISTS p_historial_reporte_select ON auditoria.historial_estados;
CREATE POLICY p_historial_reporte_select ON auditoria.historial_estados
    FOR SELECT TO sosnet_reporte USING (true);

-- Actividad (auditoría)

DROP POLICY IF EXISTS p_actividad_api_select ON auditoria.actividad;
CREATE POLICY p_actividad_api_select ON auditoria.actividad
    FOR SELECT TO sosnet_api
    USING (
        public.fn_rol_actual() = 'admin'
        OR id_usuario = public.fn_usuario_actual()
    );

DROP POLICY IF EXISTS p_actividad_auth_select ON auditoria.actividad;
CREATE POLICY p_actividad_auth_select ON auditoria.actividad
    FOR SELECT TO authenticated
    USING (
        public.fn_jwt_role() = 'admin'
        OR id_usuario = public.fn_usuario_externo_actual()
    );
