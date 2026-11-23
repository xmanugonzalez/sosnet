-- Datos iniciales: tipos de emergencia, dispositivo, cuentas demo y configuración.

-- Evita que la carga inicial llene la auditoría de eventos.
SELECT set_config('app.audit_enabled', 'false', false);

-- Tipos de emergencia básicos.
INSERT INTO public.tipos_emergencia (nombre, descripcion) VALUES
    ('Inundación', 'Viviendas o zonas afectadas por agua'),
    ('Asistencia médica', 'Personas que necesitan atención médica urgente'),
    ('Evacuación', 'Traslado de personas a un lugar seguro'),
    ('Suministros', 'Agua, alimentos u otros insumos básicos'),
    ('Otra', 'Emergencia no clasificada')
ON CONFLICT (nombre) DO NOTHING;

-- Dispositivo que representa al formulario web.
INSERT INTO public.dispositivos (codigo, nombre, tipo, estado) VALUES
    ('FORMULARIO-SOS', 'Formulario web SOS', 'web', 'activo')
ON CONFLICT (codigo) DO NOTHING;

-- Cuenta demo de operador: operador@sosnet.local / OperadorDemo123.
INSERT INTO public.usuarios (
    nombre, usuario, correo, contrasena, rol, activo, fecha_registro
)
SELECT
    'Operador SOSNET',
    'operador',
    'operador@sosnet.local',
    'scrypt:32768:8:1$3VXPvpbwneBrVL6S$1ddce3db24eaf66fbd24a130dc1ea9cc3074c821fa76e4a9276c5f215c844b307309d6aae0fc6a85fa8ff4afbc2cf6993e2ebf1dee5c60e8609e7e23e2130583',
    'operador',
    true,
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.usuarios WHERE lower(usuario) = 'operador'
);

-- Cuenta demo de administrador: admin@sosnet.local / AdminDemo123.
INSERT INTO public.usuarios (
    nombre, usuario, correo, contrasena, rol, activo, fecha_registro
)
SELECT
    'Administrador SOSNET',
    'admin',
    'admin@sosnet.local',
    'scrypt:32768:8:1$gPNoK63RGggCffmo$34431a8a16bb87e5e2373cb8445924a4c86c482ad579dcdda7f53a3e185675eacebfa221761cb5ce6b8fb9e8a7707b89f0e95b298660dba7d03fa32d11146b65',
    'admin',
    true,
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.usuarios WHERE lower(usuario) = 'admin'
);

-- Cuenta interna del sistema: inactiva y sin acceso.
INSERT INTO public.usuarios (
    nombre, usuario, correo, contrasena, rol, activo, fecha_registro
)
SELECT
    'Sistema SOSNET',
    'sistema',
    NULL,
    '!',
    'sistema',
    false,
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.usuarios WHERE lower(usuario) = 'sistema'
);

-- Datos de la central (solo existe la fila 1).
INSERT INTO public.configuracion_central (
    id_configuracion, nombre, ubicacion, actualizado_en
)
VALUES (
    1, 'Central de rescate', 'Asunción, Paraguay', now()
)
ON CONFLICT (id_configuracion) DO NOTHING;

-- Reactiva la auditoría para el uso normal.
SELECT set_config('app.audit_enabled', 'true', false);
