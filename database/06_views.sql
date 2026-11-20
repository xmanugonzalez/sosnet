-- ============================================================================
-- SOSNET · PostgreSQL / Supabase
-- 06 · Vistas del esquema reportes
--
-- Las vistas usan relaciones reales y security_invoker = true para que las
-- políticas RLS de las tablas base se apliquen al rol que consulta.
-- ============================================================================

DROP VIEW IF EXISTS reportes.vw_solicitudes_detalladas CASCADE;
CREATE VIEW reportes.vw_solicitudes_detalladas
WITH (security_invoker = true)
AS
SELECT
    s.id_solicitud,
    s.codigo_mensaje,
    s.nombre_solicitante,
    t.nombre AS tipo,
    t.descripcion AS tipo_descripcion,
    d.codigo AS dispositivo_codigo,
    d.nombre AS dispositivo_nombre,
    d.tipo AS dispositivo_tipo,
    s.ubicacion,
    s.cantidad_personas,
    s.descripcion,
    s.prioridad,
    s.estado,
    s.fecha_recepcion,
    s.actualizado_en,
    (
        SELECT count(*)
        FROM public.registros_comunicacion AS r
        WHERE r.id_solicitud = s.id_solicitud
    ) AS comunicaciones
FROM public.solicitudes_sos AS s
JOIN public.tipos_emergencia AS t ON t.id_tipo = s.id_tipo
JOIN public.dispositivos AS d ON d.id_dispositivo = s.id_dispositivo;

COMMENT ON VIEW reportes.vw_solicitudes_detalladas IS
  'Solicitudes con tipo de emergencia, dispositivo y cantidad de comunicaciones.';

DROP VIEW IF EXISTS reportes.vw_solicitudes_por_tipo CASCADE;
CREATE VIEW reportes.vw_solicitudes_por_tipo
WITH (security_invoker = true)
AS
SELECT
    t.id_tipo,
    t.nombre AS tipo,
    count(s.id_solicitud) AS total,
    count(*) FILTER (WHERE s.estado = 'pending') AS pendientes,
    count(*) FILTER (WHERE s.estado = 'in_progress') AS en_proceso,
    count(*) FILTER (WHERE s.estado = 'resolved') AS resueltas,
    COALESCE(sum(s.cantidad_personas), 0) AS personas_afectadas,
    round(
        100.0 * count(s.id_solicitud)
        / NULLIF((SELECT count(*) FROM public.solicitudes_sos), 0),
        2
    ) AS porcentaje
FROM public.tipos_emergencia AS t
LEFT JOIN public.solicitudes_sos AS s ON s.id_tipo = t.id_tipo
GROUP BY t.id_tipo, t.nombre
ORDER BY count(s.id_solicitud) DESC, t.nombre;

COMMENT ON VIEW reportes.vw_solicitudes_por_tipo IS
  'Agregado por tipo: total, estados, personas y porcentaje del total.';

DROP VIEW IF EXISTS reportes.vw_historial_solicitudes CASCADE;
CREATE VIEW reportes.vw_historial_solicitudes
WITH (security_invoker = true)
AS
SELECT
    h.id_historial,
    h.id_solicitud,
    s.codigo_mensaje,
    h.estado_anterior,
    h.estado_nuevo,
    u.nombre AS usuario,
    u.rol AS usuario_rol,
    h.fecha_cambio,
    h.observacion
FROM auditoria.historial_estados AS h
JOIN public.solicitudes_sos AS s ON s.id_solicitud = h.id_solicitud
JOIN public.usuarios AS u ON u.id_usuario = h.id_usuario;

COMMENT ON VIEW reportes.vw_historial_solicitudes IS
  'Historial de estados con el código de la solicitud y el operador responsable.';

DROP VIEW IF EXISTS reportes.vw_actividad_usuarios CASCADE;
CREATE VIEW reportes.vw_actividad_usuarios
WITH (security_invoker = true)
AS
SELECT
    a.id_actividad,
    a.fecha,
    a.accion,
    a.descripcion,
    a.entidad,
    a.entidad_id,
    COALESCE(u.nombre, 'Sistema') AS actor,
    COALESCE(u.rol, 'sistema') AS actor_rol
FROM auditoria.actividad AS a
LEFT JOIN public.usuarios AS u ON u.id_usuario = a.id_usuario;

COMMENT ON VIEW reportes.vw_actividad_usuarios IS
  'Auditoría enriquecida con el nombre y rol del actor.';

DROP VIEW IF EXISTS reportes.vw_estadisticas_emergencias CASCADE;
CREATE VIEW reportes.vw_estadisticas_emergencias
WITH (security_invoker = true)
AS
SELECT
    count(*) AS total_solicitudes,
    count(*) FILTER (WHERE estado = 'pending') AS pendientes,
    count(*) FILTER (WHERE estado = 'in_progress') AS en_proceso,
    count(*) FILTER (WHERE estado = 'resolved') AS resueltas,
    count(*) FILTER (WHERE prioridad = 'alta') AS prioridad_alta,
    count(*) FILTER (WHERE prioridad = 'media') AS prioridad_media,
    count(*) FILTER (WHERE prioridad = 'baja') AS prioridad_baja,
    COALESCE(sum(cantidad_personas), 0) AS personas_afectadas,
    round(COALESCE(avg(cantidad_personas), 0), 2) AS promedio_personas,
    count(*) FILTER (WHERE fecha_recepcion >= now() - interval '24 hours')
        AS ultimas_24_horas,
    max(fecha_recepcion) AS ultima_solicitud,
    (SELECT count(*) FROM public.dispositivos WHERE estado = 'activo')
        AS dispositivos_activos
FROM public.solicitudes_sos;

COMMENT ON VIEW reportes.vw_estadisticas_emergencias IS
  'Resumen de una fila para el panel administrativo y consultas académicas.';

DROP VIEW IF EXISTS reportes.vw_resumen_dispositivos CASCADE;
CREATE VIEW reportes.vw_resumen_dispositivos
WITH (security_invoker = true)
AS
SELECT
    d.id_dispositivo,
    d.codigo,
    d.nombre,
    d.tipo,
    d.estado,
    count(s.id_solicitud) AS total_solicitudes,
    count(*) FILTER (WHERE s.estado = 'pending') AS pendientes,
    count(*) FILTER (WHERE s.estado = 'in_progress') AS en_proceso,
    count(*) FILTER (WHERE s.estado = 'resolved') AS resueltas,
    max(s.fecha_recepcion) AS ultima_solicitud
FROM public.dispositivos AS d
LEFT JOIN public.solicitudes_sos AS s ON s.id_dispositivo = d.id_dispositivo
GROUP BY d.id_dispositivo, d.codigo, d.nombre, d.tipo, d.estado
ORDER BY count(s.id_solicitud) DESC, d.codigo;

COMMENT ON VIEW reportes.vw_resumen_dispositivos IS
  'Actividad acumulada por dispositivo emisor o formulario web.';
