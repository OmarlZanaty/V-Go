# Deploying the V-Go backend to Google Cloud Run

This backend is a .NET 9 API using **SQL Server** (EF Core + Hangfire), Firebase,
Cloudinary, PayMob, Google OAuth and SignalR. It is now Cloud-Run-ready:
binds to `$PORT`, logs to stdout, skips HTTPS-redirect in the container, and
resolves Firebase credentials from an env var / Secret Manager / ADC.

---

## 0. Secrets checklist (gather these first)

.NET reads nested config keys with a **double underscore** as the env-var name
(`JWT:Key` → `JWT__Key`). Every value the app needs:

| Env var (Cloud Run) | What it is |
|---|---|
| `ConnectionStrings__DefaultConnection` | SQL Server connection string (Cloud SQL) |
| `JWT__Key` | JWT signing secret (long random string) |
| `JWT__Issuer` | JWT issuer (e.g. `https://api.vgo-eg.com`) |
| `JWT__Audience` | JWT audience (e.g. `vgo-clients`) |
| `MailSettings__Email` | SMTP sender address |
| `MailSettings__DisplayName` | SMTP display name |
| `MailSettings__Password` | SMTP/app password |
| `MailSettings__Host` | SMTP host (e.g. `smtp.gmail.com`) |
| `MailSettings__Port` | SMTP port (e.g. `587`) |
| `GoogleAuth__ClientId` | Google OAuth client id |
| `GoogleAuth__ClientSecret` | Google OAuth client secret |
| `GoogleAuth__googleAuthUrl` | Google auth URL |
| `GoogleAuth__redirect_uri` | Web OAuth redirect URI |
| `GoogleAuth__redirect_uri_mobile` | Mobile OAuth redirect URI |
| `Paymob__HmacSecret` | PayMob HMAC secret (webhook verification) |
| `Paymob__PublicKey` | PayMob public key |
| `Paymob__SecretKey` | PayMob secret key |
| `Cloudinary__CloudName` | Cloudinary cloud name |
| `Cloudinary__ApiKey` | Cloudinary API key |
| `Cloudinary__ApiSecret` | Cloudinary API secret |
| `FIREBASE_CREDENTIALS_PATH` | Path to the mounted Firebase admin JSON (set in step 5) |

Sensitive ones (DB, JWT, PayMob, Mail, Cloudinary, Firebase JSON) go in
**Secret Manager**; non-sensitive ones can be plain env vars.

---

## 1. Install the gcloud CLI (Windows)

```powershell
# Download + install the Google Cloud SDK installer:
#   https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe
# Then, in a NEW terminal:
gcloud version
gcloud auth login
```

## 2. Create a project + enable billing

```powershell
gcloud projects create vgo-prod --name="V-Go"
gcloud config set project vgo-prod

# Link billing (list accounts, then link the one you want):
gcloud billing accounts list
gcloud billing projects link vgo-prod --billing-account=BILLING_ACCOUNT_ID
```

## 3. Enable the required APIs

```powershell
gcloud services enable `
  run.googleapis.com `
  cloudbuild.googleapis.com `
  sqladmin.googleapis.com `
  secretmanager.googleapis.com `
  artifactregistry.googleapis.com
```

## 4. Create the Cloud SQL (SQL Server) instance

```powershell
# Instance (Express edition is cheapest; pick a region near your users, e.g. europe-west1):
gcloud sql instances create vgo-sql `
  --database-version=SQLSERVER_2022_EXPRESS `
  --cpu=2 --memory=4GB `
  --region=europe-west1 `
  --root-password="CHOOSE_A_STRONG_ROOT_PASSWORD"

# App database + login:
gcloud sql databases create MasafetElseka --instance=vgo-sql
gcloud sql users create vgoapp --instance=vgo-sql --password="CHOOSE_A_STRONG_APP_PASSWORD"

# Note the instance connection name (PROJECT:REGION:INSTANCE):
gcloud sql instances describe vgo-sql --format="value(connectionName)"
```

Connection string to use for `ConnectionStrings__DefaultConnection`
(Cloud Run reaches the instance through the built-in Cloud SQL connector on
`127.0.0.1:1433` when you pass `--add-cloudsql-instances`):

```
Server=127.0.0.1,1433;Database=MasafetElseka;User Id=vgoapp;Password=APP_PASSWORD;TrustServerCertificate=True;Encrypt=False;
```

## 5. Store secrets in Secret Manager

```powershell
# Firebase admin JSON (the file that must NOT go in git):
gcloud secrets create firebase-adminsdk --data-file="appdata/secrets/v-go-f6d46-firebase-adminsdk-fbsvc-ab74bd572b.json"

# Example for a text secret (repeat per sensitive value):
"Server=127.0.0.1,1433;Database=MasafetElseka;User Id=vgoapp;Password=APP_PASSWORD;TrustServerCertificate=True;Encrypt=False;" | `
  gcloud secrets create ConnectionStrings__DefaultConnection --data-file=-

"YOUR_LONG_RANDOM_JWT_KEY" | gcloud secrets create JWT__Key --data-file=-
# ...repeat for Paymob__HmacSecret, Paymob__SecretKey, Cloudinary__ApiSecret,
#    MailSettings__Password, GoogleAuth__ClientSecret, etc.
```

## 6. Deploy to Cloud Run

Run from the `Backend/` folder (it contains the Dockerfile + .sln):

```powershell
gcloud run deploy vgo-api `
  --source . `
  --region=europe-west1 `
  --allow-unauthenticated `
  --min-instances=1 `
  --add-cloudsql-instances=PROJECT:REGION:vgo-sql `
  --update-secrets="ConnectionStrings__DefaultConnection=ConnectionStrings__DefaultConnection:latest,JWT__Key=JWT__Key:latest,/secrets/firebase/admin.json=firebase-adminsdk:latest" `
  --set-env-vars="JWT__Issuer=https://api.vgo-eg.com,JWT__Audience=vgo-clients,FIREBASE_CREDENTIALS_PATH=/secrets/firebase/admin.json"
```

> `--min-instances=1` is important: the app runs a background `HostedService`
> (`DriverStatusSyncService`) and **Hangfire** jobs, which need an always-on
> instance. Scaling to zero would pause them.

After deploy, gcloud prints the service URL, e.g.
`https://vgo-api-xxxxx-ew.a.run.app`.

## 7. Apply the database schema (first deploy only)

The fresh Cloud SQL database is empty. Apply EF Core migrations once. Easiest:
temporarily allow your IP and run from your machine against the instance's
public IP, or use the Cloud SQL Auth Proxy:

```powershell
# With the Cloud SQL Auth Proxy running locally on 1433:
$env:ConnectionStrings__DefaultConnection = "Server=127.0.0.1,1433;Database=MasafetElseka;User Id=vgoapp;Password=APP_PASSWORD;TrustServerCertificate=True;Encrypt=False;"
dotnet ef database update --project Masafet_Elseka.Infrastructure --startup-project Masafet_Elseka.Presentation
```

(Or ask me to add `context.Database.Migrate()` on startup so the schema applies
automatically on the first request — simpler, but couples startup to the DB.)

---

## 8. Point the apps at the new URL

Both Flutter apps read the base URL from `AppConfig` and accept a build-time
override. Once you have the Cloud Run URL:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://vgo-api-xxxxx-ew.a.run.app/api/ `
  --dart-define=SIGNALR_BASE_URL=https://vgo-api-xxxxx-ew.a.run.app
```

For release builds use the same `--dart-define` flags with
`flutter build apk` / `flutter build ipa`. To bake the URL in as the new default
instead, update `_defaultApiBaseUrl` / `_defaultSignalRBaseUrl` in
`lib/core/config/app_config.dart` in **both** apps.

Add the Cloud Run URL (and your web dashboard origin) to the CORS allow-list in
`Program.cs` if a browser client calls the API.
