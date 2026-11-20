-- Datos iniciales de SOSNET.
-- Accesos de demostración:
--   operador@sosnet.local / OperadorDemo123
--   admin@sosnet.local    / AdminDemo123
-- Cambiar ambas contraseñas en producción.

USE sosnet;

SET NAMES utf8mb4;

INSERT INTO TiposEmergencia (nombre, descripcion)
SELECT 'Inundación', 'Viviendas o zonas afectadas por agua' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM TiposEmergencia WHERE nombre = 'Inundación');

INSERT INTO TiposEmergencia (nombre, descripcion)
SELECT 'Asistencia médica', 'Personas que necesitan atención médica urgente' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM TiposEmergencia WHERE nombre = 'Asistencia médica');

INSERT INTO TiposEmergencia (nombre, descripcion)
SELECT 'Evacuación', 'Traslado de personas a un lugar seguro' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM TiposEmergencia WHERE nombre = 'Evacuación');

INSERT INTO TiposEmergencia (nombre, descripcion)
SELECT 'Suministros', 'Agua, alimentos u otros insumos básicos' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM TiposEmergencia WHERE nombre = 'Suministros');

INSERT INTO TiposEmergencia (nombre, descripcion)
SELECT 'Otra', 'Emergencia no clasificada' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM TiposEmergencia WHERE nombre = 'Otra');

INSERT INTO Dispositivos (codigo, nombre, tipo, estado, fecha_registro)
SELECT 'NODE-001', 'Nodo emisor 01', 'emisor', 'activo', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Dispositivos WHERE codigo = 'NODE-001');

INSERT INTO Dispositivos (codigo, nombre, tipo, estado, fecha_registro)
SELECT 'NODE-002', 'Nodo repetidor 02', 'repetidor', 'activo', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Dispositivos WHERE codigo = 'NODE-002');

INSERT INTO Dispositivos (codigo, nombre, tipo, estado, fecha_registro)
SELECT 'NODE-003', 'Nodo receptor 03', 'receptor', 'activo', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Dispositivos WHERE codigo = 'NODE-003');

INSERT INTO Dispositivos (codigo, nombre, tipo, estado, fecha_registro)
SELECT 'FORMULARIO-SOS', 'Formulario web SOS', 'web', 'activo', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Dispositivos WHERE codigo = 'FORMULARIO-SOS');

INSERT INTO Usuarios (nombre, usuario, correo, contrasena, rol, activo, fecha_registro)
SELECT 'Operador SOSNET', 'operador', 'operador@sosnet.local',
       'scrypt:32768:8:1$3VXPvpbwneBrVL6S$1ddce3db24eaf66fbd24a130dc1ea9cc3074c821fa76e4a9276c5f215c844b307309d6aae0fc6a85fa8ff4afbc2cf6993e2ebf1dee5c60e8609e7e23e2130583',
       'operador', 1, NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'operador');

INSERT INTO Usuarios (nombre, usuario, correo, contrasena, rol, activo, fecha_registro)
SELECT 'Administrador SOSNET', 'admin', 'admin@sosnet.local',
       'scrypt:32768:8:1$gPNoK63RGggCffmo$34431a8a16bb87e5e2373cb8445924a4c86c482ad579dcdda7f53a3e185675eacebfa221761cb5ce6b8fb9e8a7707b89f0e95b298660dba7d03fa32d11146b65',
       'admin', 1, NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'admin');

INSERT INTO Usuarios (nombre, usuario, correo, contrasena, rol, activo, fecha_registro)
SELECT 'Sistema SOSNET', 'sistema', NULL,
       '!',
       'sistema', 0, NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'sistema');

INSERT INTO ConfiguracionCentral (nombre, ubicacion, actualizado_en)
SELECT 'Central de rescate', 'Asunción, Paraguay', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ConfiguracionCentral);
