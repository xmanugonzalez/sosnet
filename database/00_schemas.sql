
CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE SCHEMA IF NOT EXISTS reportes;

COMMENT ON SCHEMA public IS
  'Tablas operativas de SOSNET: usuarios, dispositivos, solicitudes y configuración.';
COMMENT ON SCHEMA auditoria IS
  'Trazabilidad: historial de estados de solicitudes y actividad de usuarios.';
COMMENT ON SCHEMA reportes IS
  'Objetos de solo lectura para consultas administrativas y académicas.';
