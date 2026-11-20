-- ============================================================================
-- SOSNET · Migración 004 · Renombrar identidad externa
--
-- Compatibilidad para bases creadas antes de quitar el nombre técnico de
-- Supabase. En instalaciones nuevas, 00–09 ya usan external_uid.
-- ============================================================================

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'usuarios'
          AND column_name = 'supabase_uid'
    ) THEN
        ALTER TABLE public.usuarios
            RENAME COLUMN supabase_uid TO external_uid;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_usuarios_supabase_uid'
    ) THEN
        ALTER TABLE public.usuarios
            RENAME CONSTRAINT uq_usuarios_supabase_uid TO uq_usuarios_external_uid;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'fn_usuario_supabase_actual'
    ) THEN
        ALTER FUNCTION public.fn_usuario_supabase_actual()
            RENAME TO fn_usuario_externo_actual;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_usuario_externo_actual() TO PUBLIC;

COMMIT;
