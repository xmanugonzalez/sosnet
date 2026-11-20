-- ============================================================================
-- SOSNET · PostgreSQL / Supabase
-- 00 · Esquemas de la base de datos
--
-- Organización:
--   public     Tablas principales y objetos usados por la aplicación Flask.
--   auditoria  Historial de estados y actividad (trazabilidad del sistema).
--   reportes   Vistas y funciones de consulta administrativa.
--
-- Ejecutar en Supabase SQL Editor o con psql en este orden:
--   00_schemas.sql → 01_tables.sql → ... → 09_seed.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE SCHEMA IF NOT EXISTS reportes;

COMMENT ON SCHEMA public IS
  'Tablas operativas de SOSNET: usuarios, dispositivos, solicitudes y configuración.';
COMMENT ON SCHEMA auditoria IS
  'Trazabilidad: historial de estados de solicitudes y actividad de usuarios.';
COMMENT ON SCHEMA reportes IS
  'Objetos de solo lectura para consultas administrativas y académicas.';
