# --- Build stage ---
FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

# go.sum is already committed and verified — `go mod download` (not
# `go mod tidy`) so the build never silently rewrites go.mod/go.sum,
# keeping the build reproducible and cacheable on unchanged dependencies.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/server ./cmd/server
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/migrate ./cmd/migrate

# --- Run stage ---
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata wget \
    && addgroup -S climatetech && adduser -S -G climatetech climatetech

WORKDIR /app
COPY --from=builder /app/bin/server .
COPY --from=builder /app/bin/migrate .
# No .env file is copied into the image — every config value is required to
# be supplied by the deployment platform (ECS task definition env/secrets,
# App Runner env vars, `docker run -e`/--env-file at the host level, etc).
# Baking even a blank placeholder .env into the image risked a future commit
# to .env.example silently becoming a permanent secret in the image layer
# history; config.Load() already fails closed on any required value that
# isn't actually set in the environment, so there is nothing for a baked-in
# file to usefully provide.
# firebase-service-account.json is intentionally NOT copied into the image —
# it's a real credential, mounted read-only at runtime via the
# docker-compose volume (dev) or Secrets Manager (production) instead.

RUN chown -R climatetech:climatetech /app
USER climatetech

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["./server"]
