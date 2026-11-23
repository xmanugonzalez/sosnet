-- Crea índices para acelerar búsquedas y evitar datos duplicados.

-- Usuario único sin distinguir mayúsculas.
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_usuario_lower
    ON public.usuarios (lower(usuario));

-- Correo único sin distinguir mayúsculas; ignora los NULL.
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_correo_lower
    ON public.usuarios (lower(correo))
    WHERE correo IS NOT NULL;

-- Búsquedas operativas de solicitudes.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_estado
    ON public.solicitudes_sos (estado);

-- Ordenar por fecha: las más recientes primero.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_fecha_recepcion
    ON public.solicitudes_sos (fecha_recepcion DESC);

-- Filtrar por tipo de emergencia.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_tipo
    ON public.solicitudes_sos (id_tipo);

-- Filtrar por dispositivo.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_dispositivo
    ON public.solicitudes_sos (id_dispositivo);

-- Filtrar por prioridad.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_prioridad
    ON public.solicitudes_sos (prioridad);

-- Índice parcial para el tablero de trabajo de la central.
CREATE INDEX IF NOT EXISTS ix_solicitudes_sos_abiertas
    ON public.solicitudes_sos (fecha_recepcion DESC)
    WHERE estado IN ('pending', 'in_progress');

-- Comunicaciones y trazabilidad.
CREATE INDEX IF NOT EXISTS ix_registros_comunicacion_solicitud
    ON public.registros_comunicacion (id_solicitud);

CREATE INDEX IF NOT EXISTS ix_registros_comunicacion_dispositivo
    ON public.registros_comunicacion (id_dispositivo);

-- Historial de una solicitud, del cambio más reciente al más antiguo.
CREATE INDEX IF NOT EXISTS ix_historial_estados_solicitud_fecha
    ON auditoria.historial_estados (id_solicitud, fecha_cambio DESC);

-- Historial por usuario responsable.
CREATE INDEX IF NOT EXISTS ix_historial_estados_usuario
    ON auditoria.historial_estados (id_usuario);

-- Actividad reciente.
CREATE INDEX IF NOT EXISTS ix_actividad_fecha
    ON auditoria.actividad (fecha DESC);

-- Actividad por usuario.
CREATE INDEX IF NOT EXISTS ix_actividad_usuario
    ON auditoria.actividad (id_usuario);

-- Actividad por entidad afectada.
CREATE INDEX IF NOT EXISTS ix_actividad_entidad
    ON auditoria.actividad (entidad, entidad_id);

-- Dispositivos por estado (para reportes de disponibilidad).
CREATE INDEX IF NOT EXISTS ix_dispositivos_estado
    ON public.dispositivos (estado);
