-- ============================================================================
-- SOSNET · Migración 003 · Eliminación de dispositivos de hardware anteriores
--
-- Aplicar una sola vez sobre una base creada con los scripts anteriores.
-- En una instalación nueva, los scripts 01/04/09 ya no incluyen hardware.
-- ============================================================================

BEGIN;

-- Eliminar dispositivos de hardware no referenciados. Si alguno está asociado a
-- una solicitud, se aborta para no perder trazabilidad.
DELETE FROM public.dispositivos d
WHERE d.tipo NOT IN ('web', 'desconocido')
  AND NOT EXISTS (
      SELECT 1 FROM public.solicitudes_sos s
      WHERE s.id_dispositivo = d.id_dispositivo
  );

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.dispositivos
        WHERE tipo NOT IN ('web', 'desconocido')
    ) THEN
        RAISE EXCEPTION
            'Hay dispositivos de hardware referenciados por solicitudes. Reasignalos antes de aplicar esta migración.';
    END IF;
END;
$$;

ALTER TABLE public.dispositivos
    DROP CONSTRAINT IF EXISTS ck_dispositivos_tipo;

ALTER TABLE public.dispositivos
    ADD CONSTRAINT ck_dispositivos_tipo CHECK (tipo IN ('web', 'desconocido'));

CREATE OR REPLACE PROCEDURE public.sp_registrar_dispositivo(
    p_codigo text,
    INOUT p_id_dispositivo integer DEFAULT NULL,
    p_nombre text DEFAULT NULL,
    p_tipo text DEFAULT 'desconocido',
    p_estado text DEFAULT 'activo'
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_codigo varchar(50);
    v_nombre varchar(100);
    v_tipo   varchar(30);
    v_estado varchar(20);
BEGIN
    v_codigo := left(COALESCE(NULLIF(btrim(p_codigo), ''), 'DESCONOCIDO'), 50);
    v_nombre := left(COALESCE(NULLIF(btrim(p_nombre), ''), v_codigo), 100);
    v_tipo   := lower(COALESCE(NULLIF(btrim(p_tipo), ''), 'desconocido'));
    v_estado := lower(COALESCE(NULLIF(btrim(p_estado), ''), 'activo'));

    IF v_tipo NOT IN ('web', 'desconocido') THEN
        RAISE EXCEPTION 'Tipo de dispositivo no válido: %', v_tipo
            USING ERRCODE = '22023';
    END IF;
    IF v_estado NOT IN ('activo', 'inactivo', 'mantenimiento') THEN
        RAISE EXCEPTION 'Estado de dispositivo no válido: %', v_estado
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.dispositivos (codigo, nombre, tipo, estado)
    VALUES (v_codigo, v_nombre, v_tipo, v_estado)
    ON CONFLICT (codigo) DO NOTHING;

    SELECT d.id_dispositivo
    INTO p_id_dispositivo
    FROM public.dispositivos AS d
    WHERE d.codigo = v_codigo;
END;
$$;

COMMENT ON PROCEDURE public.sp_registrar_dispositivo(text, integer, text, text, text) IS
  'Alta idempotente de un dispositivo web; devuelve su ID existente o nuevo.';

COMMIT;
