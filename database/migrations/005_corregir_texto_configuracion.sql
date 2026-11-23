-- ============================================================================
-- SOSNET - Migracion 005 - Corregir textos con acentos danados
--
-- Bases creadas con versiones antiguas del seed pueden tener la ubicacion de
-- la central guardada como 'Asunci??n, Paraguay'. Se corrige usando escapes
-- ASCII (U&) para que el resultado no dependa de la codificacion del cliente.
-- ============================================================================

BEGIN;

UPDATE public.configuracion_central
SET ubicacion = U&'Asunci\00F3n, Paraguay'
WHERE id_configuracion = 1
  AND ubicacion = 'Asunci??n, Paraguay';

COMMIT;
