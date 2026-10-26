-- Datos iniciales de SOSNET.
-- Usuario de demostración: operador / sosnet123 (cambiar en producción).

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

INSERT INTO Usuarios (nombre, usuario, contrasena, rol, fecha_registro)
SELECT 'Operador SOSNET', 'operador',
       'scrypt:32768:8:1$vshewdkUg0OSCCRm$f3bc84d3ce7bf83127a240154e90b44f27bd6c50ecbef297756242f880428d671b37b832cf8713501e6bf02f66b287841bdabf30d8f9529fa0aaea072ab02a70',
       'operador', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'operador');

INSERT INTO Usuarios (nombre, usuario, contrasena, rol, fecha_registro)
SELECT 'Sistema SOSNET', 'sistema',
       'scrypt:32768:8:1$sxnnj69oF5KJdJmi$f208225ec347e5fe588d4e38cd093d4bf1ea79338e7bc1f4b0c7cfef3cb9cb2631980bebaec66dd918a39933db3ed117e1547404f6945336e366cd93cc1cc806',
       'sistema', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'sistema');
