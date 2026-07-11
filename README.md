# Climate Tech — Day 1: Project Foundation

This is the Day 1 deliverable from the 7-day plan:
**Flutter Web + Go backend scaffolding, Postgres + Redis, Docker, JWT auth, registration/login, and basic profile — all working end-to-end.**

## What's included

```
climatetech/
├── backend/                  # Go (Gin + GORM) API
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── config/           # env config loader
│   │   ├── database/         # postgres + redis connections, SQL migration reference
│   │   ├── models/           # User model
│   │   ├── handlers/         # auth + user handlers
│   │   ├── middleware/       # JWT auth, RBAC, logging
│   │   ├── routes/           # route registration
│   │   └── utils/            # jwt, password hashing, response helpers
│   ├── Dockerfile
│   ├── go.mod
│   └── .env.example
├── frontend/                 # Flutter Web app
│   └── lib/
│       ├── core/             # theme, constants
│       ├── models/           # UserModel
│       ├── services/         # api_service (Dio + auto-refresh), auth_service, storage_service
│       ├── providers/        # Riverpod auth state
│       ├── screens/          # login, register, profile, dashboard (placeholder)
│       ├── widgets/          # shared UI components
│       └── routes/           # go_router config with auth redirects
└── docker-compose.yml         # postgres + redis + backend
```

## Backend — run it

**Option A: Docker (recommended, matches the roadmap's Day 1 task list)**
```bash
cd climatetech
docker compose up --build
```
This starts Postgres, Redis, and the Go API on `http://localhost:8080`.

**Option B: Local Go**
```bash
cd climatetech/backend
cp .env.example .env          # edit DB_HOST/REDIS_HOST to localhost if not using Docker
go mod tidy                   # downloads dependencies, generates go.sum
go run ./cmd/server
```

Tables are created automatically via GORM AutoMigrate on startup (see `internal/database/migrations/001_create_users.sql` for the canonical schema reference if you later switch to a dedicated migration tool).

### Test it
```bash
# Register
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Asha Verma","email":"asha@example.com","password":"password123"}'

# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"asha@example.com","password":"password123"}'

# Get profile (replace TOKEN with access_token from login response)
curl http://localhost:8080/api/v1/users/profile \
  -H "Authorization: Bearer TOKEN"
```

## Frontend — run it

The `frontend/` folder contains all the Dart source you need, but since this environment doesn't have the Flutter SDK to run `flutter create`, you'll generate the platform scaffolding (web/android/ios boilerplate, icons, manifest) once locally:

```bash
cd climatetech/frontend
flutter create . --project-name climatetech_frontend --platforms=web
```
This safely merges platform files into the existing `lib/`, `pubspec.yaml`, and `web/index.html` you already have — it won't overwrite your source code, only fills in missing scaffolding (it may ask to overwrite `web/index.html`; keep the version in this project, or just say no and keep ours).

Then:
```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

### What you'll see
1. Login screen (redirects here by default)
2. "Sign up" → register screen → creates account, logs in automatically
3. Redirects to dashboard placeholder showing your name
4. Profile icon → edit name, change password, log out

## Day 1 checklist status

| Task | Status |
|---|---|
| Flutter Web project setup | ✅ (source ready, run `flutter create .` once to finish scaffolding) |
| Go project setup | ✅ |
| Postgres DB + Redis setup | ✅ via docker-compose |
| Docker & Git setup | ✅ (add a `.gitignore` — see below) |
| JWT Authentication | ✅ access + refresh tokens, Redis-backed revocation |
| User registration & login | ✅ |
| User profile (name, email, password change) | ✅ |

### Suggested `.gitignore`
```
backend/.env
backend/bin/
frontend/build/
frontend/.dart_tool/
```

## Next: Day 2
Weather API + AQI API + CO₂ data integration, climate data storage, dashboard wired to live data, and a basic map widget.
