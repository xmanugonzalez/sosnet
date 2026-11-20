# Esquema MySQL heredado

Estos archivos son la referencia histórica del sistema antes de la migración a
PostgreSQL/Supabase:

- `schema.sql`: esquema MySQL 8 original.
- `seed.sql`: datos iniciales originales.
- `migrations/001_auth_seguridad.sql`: migración de autenticación, configuración
  y auditoría.

No se ejecutan en Docker ni en Supabase. Se conservan para comparar, auditar la
migración y poder volver atrás durante el período de verificación. El sistema
activo usa exclusivamente `database/*.sql` (PostgreSQL).

Para migrar datos existentes, consulta `database/migrations/README.md`.
