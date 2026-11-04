#!/bin/bash
# Removes V-Go data older than 2026-10-21 on production, keeping admins and active accounts.
# Rules are in purge-before-20261021.sql. Takes a fresh verified backup first and stops if that fails.
# Without the single argument YES it runs everything and rolls back, changing nothing.
set -euo pipefail
MODE="${1:-NO}"
cd /srv/vgo
PW=$(grep -E '^(MSSQL_SA_PASSWORD|SA_PASSWORD)=' .env | head -1 | cut -d= -f2-)
STAMP=$(date -u +%Y%m%d-%H%M%S)
BAK="/var/opt/mssql/backup/MasafetElseka-before-purge-$STAMP.bak"
run() { docker exec -i -e SQLCMDPASSWORD="$PW" vgo-sql /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -h -1 -W -b -w 300 "$@"; }

echo "Mode: $MODE"
echo "BACKUP DATABASE MasafetElseka TO DISK='$BAK' WITH COPY_ONLY, INIT, CHECKSUM; RESTORE VERIFYONLY FROM DISK='$BAK' WITH CHECKSUM;" | run -d master | grep -E 'valid|successfully'
sed 's/\r$//' /srv/vgo/purge-before-20261021.sql | run -d MasafetElseka -v "COMMIT_PURGE=$MODE"
echo "SET NOCOUNT ON; SELECT 'now: users=' + CAST((SELECT COUNT(*) FROM AspNetUsers) AS varchar) + ' trips=' + CAST((SELECT COUNT(*) FROM Trips) AS varchar) + ' payments=' + CAST((SELECT COUNT(*) FROM Payments) AS varchar);" | run -d MasafetElseka
echo "Backup to restore from: /srv/vgo/sqldata/backup/$(basename "$BAK")"
