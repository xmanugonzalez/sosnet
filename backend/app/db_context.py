"""Contexto de identidad para RLS en PostgreSQL.

Flask fija dos variables locales de sesión antes de consultar:
    app.current_user_id
    app.current_role

Las políticas RLS de 08_policies.sql las leen. El evento after_begin vuelve a
aplicarlas después de cada COMMIT/ROLLBACK para que una conexión reutilizada
del pool nunca herede la identidad de otra petición.
"""

from flask import g, has_app_context
from sqlalchemy import event, text
from sqlalchemy.orm import Session

from .extensions import db

_SET_CONTEXT = text(
    "SELECT set_config('app.current_user_id', :user_id, true), "
    "set_config('app.current_role', :role, true)"
)


def _apply_context(connection):
    if connection.dialect.name != "postgresql":
        return
    user_id = getattr(g, "db_user_id", None)
    role = getattr(g, "db_role", None)
    if user_id is None and role is None:
        return
    connection.execute(
        _SET_CONTEXT,
        {"user_id": user_id or "", "role": role or ""},
    )


@event.listens_for(Session, "after_begin")
def _sosnet_after_begin(_session, _transaction, connection):
    if not has_app_context():
        return
    _apply_context(connection)


def set_db_identity(user_id=None, role=None):
    """Fija la identidad de la petición y la aplica a la transacción actual."""
    if not has_app_context():
        return
    g.db_user_id = str(user_id) if user_id is not None else None
    g.db_role = role
    _apply_context(db.session.connection())


def get_db_identity():
    if not has_app_context():
        return None, None
    return getattr(g, "db_user_id", None), getattr(g, "db_role", None)
