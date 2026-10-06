#!/usr/bin/env bash
# Runs the captain finance/verification E2E suite against the STAGING backend on the
# Hetzner box. Recreates the staging database from scratch every time.
#   usage (on the server): bash /srv/vgo-staging/e2e/run-e2e.sh
set -uo pipefail
cd /srv/vgo-staging

sql() { # sql <database> <query>
  docker exec -e Q="$2" -e D="$1" vgo-sql bash -c \
    'T=$(ls -d /opt/mssql-tools*/bin | head -1); $T/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -I -W -h -1 -d "$D" -Q "SET NOCOUNT ON; $Q"'
}
wait_started() {
  for _ in $(seq 1 80); do
    docker logs --since 3m vgo-backend-staging 2>&1 | grep -q "Application started" && return 0
    sleep 3
  done
  echo "staging backend did not start"; docker logs --tail 50 vgo-backend-staging; exit 1
}

echo "== fresh staging database"
docker compose stop backend >/dev/null 2>&1
LOGIN=$(grep "^ConnectionStrings__DefaultConnection=" backend.env | grep -oiE "(User Id|UID|User)=[^;]*" | head -1 | cut -d= -f2)
sql master "IF DB_ID('MasafetElseka_Staging') IS NOT NULL BEGIN ALTER DATABASE [MasafetElseka_Staging] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [MasafetElseka_Staging]; END; CREATE DATABASE [MasafetElseka_Staging];"
sql MasafetElseka_Staging "CREATE USER [$LOGIN] FOR LOGIN [$LOGIN]; ALTER ROLE db_owner ADD MEMBER [$LOGIN];"
rm -rf private-data/* public-media/* e2e/state.json

echo "== build + start staging backend"
docker compose up -d --build backend 2>&1 | tail -1
wait_started

# A fresh database has no Identity roles (production has them); seed the ones the app uses.
for R in Admin Client Driver Dispatcher Accountant; do
  sql MasafetElseka_Staging "IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE NormalizedName=UPPER('$R')) INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), '$R', UPPER('$R'), NEWID())"
done

HMAC=$(grep "^Paymob__HmacSecret=" backend.env | cut -d= -f2-)
node_run() { # node_run <phase> [extra env...]
  docker run --rm --network host -e PHASE="$1" -e HMAC="$HMAC" "${@:2}" \
    -v /srv/vgo-staging/e2e:/e2e -v /srv/vgo-staging/e2e-node:/e2e/node_modules -w /e2e node:20-alpine \
    sh -c '[ -d node_modules/@microsoft/signalr ] || npm i --silent --no-save @microsoft/signalr@8 >/dev/null 2>&1; node e2e.mjs'
}

TOTAL_FAIL=0
echo; echo "== phase: setup"; node_run setup || TOTAL_FAIL=1

echo; echo "== restart (runs the one-time launch bootstrap)"
docker compose restart backend >/dev/null 2>&1; sleep 2; wait_started

echo; echo "== phase: main"; OUT=$(node_run main); RC=$?; echo "$OUT" | grep -v NEED_ORDER_ID_FOR; [ $RC -eq 0 ] || TOTAL_FAIL=1
PID=$(echo "$OUT" | grep NEED_ORDER_ID_FOR | awk '{print $2}')
if [ -n "$PID" ]; then
  ORDER=$(sql MasafetElseka_Staging "SELECT OrderId FROM Payments WHERE Id='$PID'" | tr -d '[:space:]')
  echo; echo "== phase: settle (Paymob order $ORDER)"; node_run settle -e ORDER_ID="$ORDER" || TOTAL_FAIL=1
fi

echo; echo "== phase: overdue (grace deadline moved into the past)"
OLD=$(docker run --rm -v /srv/vgo-staging/e2e:/e2e node:20-alpine node -e "console.log(require('/e2e/state.json').oldDriver.id)")
sql MasafetElseka_Staging "UPDATE AspNetUsers SET DocumentsDeadline = DATEADD(day,-1,GETDATE()) WHERE Id='$OLD'"
node_run overdue || TOTAL_FAIL=1

echo; echo "== phase: banners"; node_run banners || TOTAL_FAIL=1

echo; echo "== ledger integrity: balance = sum of entries, no duplicate settlement credit"
sql MasafetElseka_Staging "SELECT COUNT(*) FROM (SELECT PaymentId FROM DriverLedgerEntries WHERE PaymentId IS NOT NULL GROUP BY PaymentId HAVING COUNT(*)>1) d" | sed 's/^/duplicate settlement credits: /'
echo; echo "== backend errors during the run"
docker logs --since 30m vgo-backend-staging 2>&1 | grep -E "\[ERR\]|Exception" | grep -viE "PreAuthExpiry|BackgroundServerProcess|Hangfire" | sort | uniq -c | head -20

echo; [ $TOTAL_FAIL -eq 0 ] && echo "E2E RESULT: ALL PHASES PASSED" || echo "E2E RESULT: FAILURES"
exit $TOTAL_FAIL
