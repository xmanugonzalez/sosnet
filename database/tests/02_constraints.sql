-- ============================================================================
-- SOSNET · Pruebas SQL · 02 Restricciones e integridad
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_tipo integer;
    v_dispositivo integer;
BEGIN
    SELECT id_tipo INTO v_tipo FROM public.tipos_emergencia WHERE nombre = 'Inundación';
    SELECT id_dispositivo INTO v_dispositivo FROM public.dispositivos WHERE codigo = 'FORMULARIO-SOS';

    -- CHECK cantidad_personas
    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        ) VALUES (
            'SOS-CHECK-PEOPLE', v_tipo, v_dispositivo, 'Test', 0, 'alta', 'pending', now()
        );
        RAISE EXCEPTION 'CHECK de cantidad_personas no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- CHECK prioridad
    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        ) VALUES (
            'SOS-CHECK-PRIORITY', v_tipo, v_dispositivo, 'Test', 1, 'urgente', 'pending', now()
        );
        RAISE EXCEPTION 'CHECK de prioridad no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- CHECK estado
    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        ) VALUES (
            'SOS-CHECK-STATE', v_tipo, v_dispositivo, 'Test', 1, 'alta', 'cerrado', now()
        );
        RAISE EXCEPTION 'CHECK de estado no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- FK tipo inexistente
    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        ) VALUES (
            'SOS-CHECK-FK', 999999, v_dispositivo, 'Test', 1, 'alta', 'pending', now()
        );
        RAISE EXCEPTION 'FK de tipo no se aplicó';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;

    -- Código duplicado
    INSERT INTO public.solicitudes_sos (
        codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
        cantidad_personas, prioridad, estado, fecha_recepcion
    ) VALUES (
        'SOS-CONSTRAINT-DUP', v_tipo, v_dispositivo, 'Test', 1, 'media', 'pending', now()
    );

    BEGIN
        INSERT INTO public.solicitudes_sos (
            codigo_mensaje, id_tipo, id_dispositivo, ubicacion,
            cantidad_personas, prioridad, estado, fecha_recepcion
        ) VALUES (
            'SOS-CONSTRAINT-DUP', v_tipo, v_dispositivo, 'Test', 1, 'media', 'pending', now()
        );
        RAISE EXCEPTION 'UNIQUE de codigo_mensaje no se aplicó';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Rol inválido
    BEGIN
        INSERT INTO public.usuarios (nombre, usuario, correo, contrasena, rol)
        VALUES ('Rol malo', 'rolmalo', 'rolmalo@sosnet.local', 'x', 'superadmin');
        RAISE EXCEPTION 'CHECK de rol no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Correo duplicado sin distinguir mayúsculas
    BEGIN
        INSERT INTO public.usuarios (nombre, usuario, correo, contrasena, rol)
        VALUES ('Duplicado', 'duplicado', 'OPERADOR@SOSNET.LOCAL', 'x', 'operador');
        RAISE EXCEPTION 'UNIQUE insensible a mayúsculas no se aplicó';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Formato de correo
    BEGIN
        INSERT INTO public.usuarios (nombre, usuario, correo, contrasena, rol)
        VALUES ('Correo malo', 'correomalo', 'correo-invalido', 'x', 'operador');
        RAISE EXCEPTION 'CHECK de formato de correo no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Configuración singleton
    BEGIN
        INSERT INTO public.configuracion_central (id_configuracion, nombre, ubicacion)
        VALUES (2, 'Otra', 'Otro');
        RAISE EXCEPTION 'CHECK singleton no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    RAISE NOTICE '02_constraints: OK (NOT NULL, UNIQUE, CHECK y FK)';
END;
$$;

ROLLBACK;
