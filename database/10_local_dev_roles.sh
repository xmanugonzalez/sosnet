
set -euo pipefail

if [ "${SOSNET_LOCAL_ROLES:-true}" != "true" ]; then
  exit 0
fi

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v api_password="${SOSNET_API_PASSWORD:-sosnet_api_dev}" \
  -v report_password="${SOSNET_REPORT_PASSWORD:-sosnet_reporte_dev}" <<'EOSQL'
ALTER ROLE sosnet_api WITH LOGIN PASSWORD :'api_password';
ALTER ROLE sosnet_reporte WITH LOGIN PASSWORD :'report_password';
EOSQL

echo "[SOSNET] Roles locales sosnet_api y sosnet_reporte habilitados para login."
