#!/usr/bin/env python
"""Migra los datos de SOSNET desde MySQL 8 a PostgreSQL local.

Características:
  * Copia usuarios, catálogos, dispositivos web, configuración, solicitudes,
    comunicaciones, historial y actividad.
  * Omite los nodos de hardware de la versión anterior.
  * Es idempotente: busca por claves naturales y actualiza/inserta sin duplicar.
  * Remapea IDs cuando el destino ya tiene datos (por ejemplo, el seed).
  * Activa el modo de migración para que los triggers de historial no
    dupliquen filas ya importadas; las claves foráneas siguen verificándose.
  * Al final ajusta las secuencias IDENTITY.

Uso típico (desde la raíz del proyecto):
    backend/.venv/Scripts/python database/migrations/migrate_mysql_to_postgres.py \
        --mysql-url mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet \
        --target-url postgresql+psycopg://sosnet_admin:...@127.0.0.1:5432/sosnet

Usa un rol administrador solo para esta migración; la aplicación debe conectar
después con sosnet_api.

Requisitos: pip install PyMySQL "psycopg[binary]" SQLAlchemy
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import Connection

SOURCE_TABLES = [
    "TiposEmergencia",
    "Dispositivos",
    "Usuarios",
    "ConfiguracionCentral",
    "SolicitudesSOS",
    "RegistrosComunicacion",
    "HistorialEstados",
    "Actividad",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migra SOSNET de MySQL a PostgreSQL")
    parser.add_argument(
        "--mysql-url",
        default=os.getenv("MYSQL_URL") or os.getenv("SOURCE_DATABASE_URL"),
        help="URL SQLAlchemy de MySQL (o variable MYSQL_URL).",
    )
    parser.add_argument(
        "--target-url",
        default=os.getenv("TARGET_DATABASE_URL") or os.getenv("DATABASE_URL"),
        help="URL SQLAlchemy de PostgreSQL local (o TARGET_DATABASE_URL).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Solo cuenta las filas de origen; no escribe en el destino.",
    )
    return parser.parse_args()


def rows(connection: Connection, table: str) -> list[dict[str, Any]]:
    return [dict(row._mapping) for row in connection.execute(text(f"SELECT * FROM `{table}`"))]


def has_table(connection: Connection, table: str) -> bool:
    return inspect(connection).has_table(table)


def value(row: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in row and row[key] is not None:
            return row[key]
    return None


def first_id(connection: Connection, sql: str, params: dict[str, Any]) -> int | None:
    return connection.execute(text(sql), params).scalar()


def upsert_usuario(connection: Connection, row: dict[str, Any]) -> int:
    usuario = value(row, "usuario") or "usuario"
    correo = value(row, "correo")
    params = {
        "nombre": value(row, "nombre") or usuario,
        "usuario": usuario,
        "correo": correo,
        "contrasena": value(row, "contrasena") or "!",
        "rol": value(row, "rol") or "operador",
        "activo": bool(value(row, "activo")) if "activo" in row else True,
        "ultimo_acceso": value(row, "ultimo_acceso"),
        "fecha_registro": value(row, "fecha_registro"),
    }
    target_id = first_id(
        connection,
        """
        SELECT id_usuario FROM public.usuarios
        WHERE lower(usuario) = lower(:usuario)
           OR (
               CAST(:correo AS text) IS NOT NULL
               AND correo IS NOT NULL
               AND lower(correo) = lower(CAST(:correo AS text))
           )
        ORDER BY id_usuario
        LIMIT 1
        """,
        params,
    )
    if target_id is None:
        result = connection.execute(
            text(
                """
                INSERT INTO public.usuarios (
                    nombre, usuario, correo, contrasena, rol, activo,
                    ultimo_acceso, fecha_registro
                ) VALUES (
                    :nombre, :usuario, :correo, :contrasena, :rol, :activo,
                    :ultimo_acceso, COALESCE(:fecha_registro, now())
                )
                RETURNING id_usuario
                """
            ),
            params,
        )
        return result.scalar_one()
    connection.execute(
        text(
            """
            UPDATE public.usuarios SET
                nombre = :nombre,
                correo = :correo,
                contrasena = :contrasena,
                rol = :rol,
                activo = :activo,
                ultimo_acceso = :ultimo_acceso,
                fecha_registro = COALESCE(:fecha_registro, fecha_registro)
            WHERE id_usuario = :id
            """
        ),
        {**params, "id": target_id},
    )
    return target_id


def upsert_tipo(connection: Connection, row: dict[str, Any]) -> int:
    nombre = value(row, "nombre") or "Otra"
    descripcion = value(row, "descripcion")
    target_id = first_id(
        connection,
        "SELECT id_tipo FROM public.tipos_emergencia WHERE lower(nombre) = lower(:nombre) LIMIT 1",
        {"nombre": nombre},
    )
    if target_id is None:
        return connection.execute(
            text(
                "INSERT INTO public.tipos_emergencia (nombre, descripcion) "
                "VALUES (:nombre, :descripcion) RETURNING id_tipo"
            ),
            {"nombre": nombre, "descripcion": descripcion},
        ).scalar_one()
    connection.execute(
        text(
            "UPDATE public.tipos_emergencia SET descripcion = COALESCE(:descripcion, descripcion) "
            "WHERE id_tipo = :id"
        ),
        {"descripcion": descripcion, "id": target_id},
    )
    return target_id


def upsert_dispositivo(connection: Connection, row: dict[str, Any]) -> int:
    codigo = value(row, "codigo") or "DESCONOCIDO"
    tipo = value(row, "tipo") or "desconocido"
    if tipo not in ("web", "desconocido"):
        tipo = "desconocido"
    params = {
        "codigo": codigo,
        "nombre": value(row, "nombre") or codigo,
        "tipo": tipo,
        "estado": value(row, "estado") or "activo",
        "fecha_registro": value(row, "fecha_registro"),
    }
    target_id = first_id(
        connection,
        "SELECT id_dispositivo FROM public.dispositivos WHERE codigo = :codigo LIMIT 1",
        params,
    )
    if target_id is None:
        return connection.execute(
            text(
                """
                INSERT INTO public.dispositivos (
                    codigo, nombre, tipo, estado, fecha_registro
                ) VALUES (
                    :codigo, :nombre, :tipo, :estado, COALESCE(:fecha_registro, now())
                ) RETURNING id_dispositivo
                """
            ),
            params,
        ).scalar_one()
    connection.execute(
        text(
            """
            UPDATE public.dispositivos SET
                nombre = :nombre,
                tipo = :tipo,
                estado = :estado,
                fecha_registro = COALESCE(:fecha_registro, fecha_registro)
            WHERE id_dispositivo = :id
            """
        ),
        {**params, "id": target_id},
    )
    return target_id


def ensure_system_user(connection: Connection) -> int:
    target_id = first_id(
        connection,
        "SELECT id_usuario FROM public.usuarios WHERE usuario = 'sistema' LIMIT 1",
        {},
    )
    if target_id is not None:
        return target_id
    return connection.execute(
        text(
            """
            INSERT INTO public.usuarios (
                nombre, usuario, correo, contrasena, rol, activo, fecha_registro
            ) VALUES ('Sistema SOSNET', 'sistema', NULL, '!', 'sistema', false, now())
            RETURNING id_usuario
            """
        )
    ).scalar_one()


def migrate(mysql: Connection, pg: Connection) -> dict[str, int]:
    counts = {table: 0 for table in SOURCE_TABLES}

    pg.execute(text("SET LOCAL TIME ZONE 'UTC'"))
    pg.execute(text("SELECT set_config('app.audit_enabled', 'false', true)"))
    pg.execute(text("SELECT set_config('app.migration_mode', 'true', true)"))

    user_map: dict[int, int] = {}
    tipo_map: dict[int, int] = {}
    dispositivo_map: dict[int, int] = {}

    for row in rows(mysql, "Usuarios"):
        source_id = int(value(row, "id_usuario"))
        user_map[source_id] = upsert_usuario(pg, row)
        counts["Usuarios"] += 1

    for row in rows(mysql, "TiposEmergencia"):
        tipo_map[int(value(row, "id_tipo"))] = upsert_tipo(pg, row)
        counts["TiposEmergencia"] += 1

    for row in rows(mysql, "Dispositivos"):
        # Solo se migran dispositivos web. Los nodos de hardware anteriores
        # quedan fuera del sistema local actual.
        if (value(row, "tipo") or "desconocido") not in ("web", "desconocido"):
            continue
        dispositivo_map[int(value(row, "id_dispositivo"))] = upsert_dispositivo(pg, row)
        counts["Dispositivos"] += 1

    system_id = ensure_system_user(pg)
    fallback_tipo = first_id(
        pg, "SELECT id_tipo FROM public.tipos_emergencia WHERE nombre = 'Otra' LIMIT 1", {}
    )
    fallback_dispositivo = first_id(
        pg,
        "SELECT id_dispositivo FROM public.dispositivos WHERE codigo = 'FORMULARIO-SOS' LIMIT 1",
        {},
    )

    config_rows = rows(mysql, "ConfiguracionCentral")
    if config_rows:
        config = config_rows[0]
        pg.execute(
            text(
                """
                INSERT INTO public.configuracion_central (
                    id_configuracion, nombre, ubicacion, actualizado_en
                ) VALUES (1, :nombre, :ubicacion, COALESCE(:actualizado_en, now()))
                ON CONFLICT (id_configuracion) DO UPDATE SET
                    nombre = EXCLUDED.nombre,
                    ubicacion = EXCLUDED.ubicacion,
                    actualizado_en = EXCLUDED.actualizado_en
                """
            ),
            {
                "nombre": value(config, "nombre") or "Central de rescate",
                "ubicacion": value(config, "ubicacion") or "Asunción, Paraguay",
                "actualizado_en": value(config, "actualizado_en"),
            },
        )
        counts["ConfiguracionCentral"] = 1

    solicitud_map: dict[int, int] = {}
    for row in rows(mysql, "SolicitudesSOS"):
        source_id = int(value(row, "id_solicitud"))
        codigo = value(row, "codigo_mensaje") or f"SOS-MIGRADA-{source_id}"
        tipo_id = tipo_map.get(int(value(row, "id_tipo")), fallback_tipo)
        dispositivo_id = dispositivo_map.get(
            int(value(row, "id_dispositivo")), fallback_dispositivo
        )
        params = {
            "codigo": codigo,
            "nombre": value(row, "nombre_solicitante"),
            "tipo": tipo_id,
            "dispositivo": dispositivo_id,
            "ubicacion": value(row, "ubicacion") or "No indicada",
            "personas": int(value(row, "cantidad_personas") or 1),
            "descripcion": value(row, "descripcion"),
            "prioridad": value(row, "prioridad") or "media",
            "estado": value(row, "estado") or "pending",
            "fecha": value(row, "fecha_recepcion"),
        }
        target_id = first_id(
            pg,
            "SELECT id_solicitud FROM public.solicitudes_sos WHERE codigo_mensaje = :codigo LIMIT 1",
            params,
        )
        if target_id is None:
            target_id = pg.execute(
                text(
                    """
                    INSERT INTO public.solicitudes_sos (
                        codigo_mensaje, nombre_solicitante, id_tipo, id_dispositivo,
                        ubicacion, cantidad_personas, descripcion, prioridad,
                        estado, fecha_recepcion, actualizado_en
                    ) VALUES (
                        :codigo, :nombre, :tipo, :dispositivo, :ubicacion, :personas,
                        :descripcion, :prioridad, :estado,
                        COALESCE(:fecha, now()), COALESCE(:fecha, now())
                    ) RETURNING id_solicitud
                    """
                ),
                params,
            ).scalar_one()
        else:
            pg.execute(
                text(
                    """
                    UPDATE public.solicitudes_sos SET
                        nombre_solicitante = :nombre,
                        id_tipo = :tipo,
                        id_dispositivo = :dispositivo,
                        ubicacion = :ubicacion,
                        cantidad_personas = :personas,
                        descripcion = :descripcion,
                        prioridad = :prioridad,
                        estado = :estado,
                        fecha_recepcion = COALESCE(:fecha, fecha_recepcion),
                        actualizado_en = COALESCE(:fecha, actualizado_en)
                    WHERE id_solicitud = :id
                    """
                ),
                {**params, "id": target_id},
            )
        solicitud_map[source_id] = target_id
        counts["SolicitudesSOS"] += 1

    for row in rows(mysql, "RegistrosComunicacion"):
        solicitud_id = solicitud_map.get(int(value(row, "id_solicitud")))
        dispositivo_id = dispositivo_map.get(int(value(row, "id_dispositivo")))
        if solicitud_id is None or dispositivo_id is None:
            continue
        fecha = value(row, "fecha_recepcion")
        estado = value(row, "estado_recepcion") or "recibido"
        exists = pg.execute(
            text(
                """
                SELECT 1 FROM public.registros_comunicacion
                WHERE id_solicitud = :solicitud
                  AND id_dispositivo = :dispositivo
                  AND estado_recepcion = :estado
                  AND fecha_recepcion = COALESCE(:fecha, fecha_recepcion)
                LIMIT 1
                """
            ),
            {
                "solicitud": solicitud_id,
                "dispositivo": dispositivo_id,
                "estado": estado,
                "fecha": fecha,
            },
        ).first()
        if exists is None:
            pg.execute(
                text(
                    """
                    INSERT INTO public.registros_comunicacion (
                        id_solicitud, id_dispositivo, fecha_recepcion, estado_recepcion
                    ) VALUES (
                        :solicitud, :dispositivo, COALESCE(:fecha, now()), :estado
                    )
                    """
                ),
                {
                    "solicitud": solicitud_id,
                    "dispositivo": dispositivo_id,
                    "fecha": fecha,
                    "estado": estado,
                },
            )
        counts["RegistrosComunicacion"] += 1

    for row in rows(mysql, "HistorialEstados"):
        solicitud_id = solicitud_map.get(int(value(row, "id_solicitud")))
        usuario_id = user_map.get(int(value(row, "id_usuario")), system_id)
        if solicitud_id is None:
            continue
        fecha = value(row, "fecha_cambio")
        estado_nuevo = value(row, "estado_nuevo") or "pending"
        exists = pg.execute(
            text(
                """
                SELECT 1 FROM auditoria.historial_estados
                WHERE id_solicitud = :solicitud
                  AND id_usuario = :usuario
                  AND estado_nuevo = :estado_nuevo
                  AND fecha_cambio = COALESCE(:fecha, fecha_cambio)
                LIMIT 1
                """
            ),
            {
                "solicitud": solicitud_id,
                "usuario": usuario_id,
                "estado_nuevo": estado_nuevo,
                "fecha": fecha,
            },
        ).first()
        if exists is None:
            pg.execute(
                text(
                    """
                    INSERT INTO auditoria.historial_estados (
                        id_solicitud, id_usuario, estado_anterior, estado_nuevo,
                        fecha_cambio, observacion
                    ) VALUES (
                        :solicitud, :usuario, :anterior, :nuevo,
                        COALESCE(:fecha, now()), :observacion
                    )
                    """
                ),
                {
                    "solicitud": solicitud_id,
                    "usuario": usuario_id,
                    "anterior": value(row, "estado_anterior"),
                    "nuevo": estado_nuevo,
                    "fecha": fecha,
                    "observacion": value(row, "observacion"),
                },
            )
        counts["HistorialEstados"] += 1

    for row in rows(mysql, "Actividad"):
        usuario_id = user_map.get(int(value(row, "id_usuario"))) if value(row, "id_usuario") else None
        fecha = value(row, "fecha")
        accion = value(row, "accion") or "evento"
        descripcion = value(row, "descripcion") or "Evento migrado"
        entidad = value(row, "entidad")
        entidad_id = value(row, "entidad_id")
        exists = pg.execute(
            text(
                """
                SELECT 1 FROM auditoria.actividad
                WHERE accion = :accion
                  AND descripcion = :descripcion
                  AND fecha = COALESCE(:fecha, fecha)
                  AND COALESCE(id_usuario, -1) = COALESCE(:usuario, -1)
                  AND COALESCE(entidad, '') = COALESCE(:entidad, '')
                  AND COALESCE(entidad_id, -1) = COALESCE(:entidad_id, -1)
                LIMIT 1
                """
            ),
            {
                "accion": accion,
                "descripcion": descripcion,
                "fecha": fecha,
                "usuario": usuario_id,
                "entidad": entidad,
                "entidad_id": entidad_id,
            },
        ).first()
        if exists is None:
            pg.execute(
                text(
                    """
                    INSERT INTO auditoria.actividad (
                        id_usuario, accion, descripcion, entidad, entidad_id, fecha
                    ) VALUES (
                        :usuario, :accion, :descripcion, :entidad, :entidad_id,
                        COALESCE(:fecha, now())
                    )
                    """
                ),
                {
                    "usuario": usuario_id,
                    "accion": accion,
                    "descripcion": descripcion,
                    "entidad": entidad,
                    "entidad_id": entidad_id,
                    "fecha": fecha,
                },
            )
        counts["Actividad"] += 1

    pg.execute(text("SELECT set_config('app.migration_mode', 'false', true)"))
    _reset_sequences(pg)
    return counts


def _reset_sequences(connection: Connection) -> None:
    for table, column in [
        ("public.usuarios", "id_usuario"),
        ("public.tipos_emergencia", "id_tipo"),
        ("public.dispositivos", "id_dispositivo"),
        ("public.solicitudes_sos", "id_solicitud"),
        ("public.registros_comunicacion", "id_registro"),
        ("auditoria.historial_estados", "id_historial"),
        ("auditoria.actividad", "id_actividad"),
    ]:
        connection.execute(
            text(
                f"""
                SELECT setval(
                    pg_get_serial_sequence('{table}', '{column}'),
                    COALESCE((SELECT max({column}) FROM {table}), 1),
                    (SELECT count(*) > 0 FROM {table})
                )
                """
            )
        )


def main() -> int:
    args = parse_args()
    if not args.mysql_url or not args.target_url:
        print(
            "Indica --mysql-url y --target-url (o MYSQL_URL/TARGET_DATABASE_URL).",
            file=sys.stderr,
        )
        return 2

    mysql_engine = create_engine(args.mysql_url)
    target_engine = create_engine(args.target_url)

    with mysql_engine.connect() as mysql:
        available = {table: has_table(mysql, table) for table in SOURCE_TABLES}
        missing = [table for table, present in available.items() if not present]
        if missing:
            print(
                "Tablas de origen ausentes: " + ", ".join(missing) + ". ¿Es la base correcta?",
                file=sys.stderr,
            )
            return 2
        if args.dry_run:
            print("Modo dry-run: no se escribirá en el destino.")
            for table in SOURCE_TABLES:
                total = mysql.execute(text(f"SELECT count(*) FROM `{table}`")).scalar_one()
                print(f"  {table}: {total} filas")
            return 0

        with target_engine.begin() as target:
            counts = migrate(mysql, target)
            # Validación de integridad referencial posterior a la carga.
            orphans = target.execute(
                text(
                    """
                    SELECT
                      (SELECT count(*) FROM public.solicitudes_sos s
                       LEFT JOIN public.tipos_emergencia t ON t.id_tipo = s.id_tipo
                       WHERE t.id_tipo IS NULL) AS solicitudes_sin_tipo,
                      (SELECT count(*) FROM public.solicitudes_sos s
                       LEFT JOIN public.dispositivos d ON d.id_dispositivo = s.id_dispositivo
                       WHERE d.id_dispositivo IS NULL) AS solicitudes_sin_dispositivo,
                      (SELECT count(*) FROM auditoria.historial_estados h
                       LEFT JOIN public.usuarios u ON u.id_usuario = h.id_usuario
                       WHERE u.id_usuario IS NULL) AS historial_sin_usuario
                    """
                )
            ).mappings().one()
            if any(orphans.values()):
                raise RuntimeError(f"Integridad referencial inválida: {dict(orphans)}")

            print("Migración completada:")
            for table, total in counts.items():
                print(f"  {table}: {total} filas procesadas")
            print("Secuencias IDENTITY ajustadas y FKs verificadas.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
