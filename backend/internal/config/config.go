package config

import (
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

type Config struct {
	AppEnv  string
	AppPort string

	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	RedisHost     string
	RedisPort     string
	RedisPassword string

	JWTAccessSecret      string
	JWTRefreshSecret     string
	JWTAccessExpiryMins  int
	JWTRefreshExpiryDays int

	OpenWeatherAPIKey string

	GeminiAPIKey string
	GeminiModel  string

	FirebaseCredentialsPath string

	NewsAPIKey string

	AllowedOrigins []string

	// TrustedProxies pins which upstream hops Gin trusts for X-Forwarded-*
	// headers (client IP, proto). Defaults to none trusted in production
	// unless explicitly configured — set to the load balancer's subnet.
	TrustedProxies []string
}

func Load() *Config {
	// In production, config is expected to come from the platform (ECS task
	// definition env vars / Secrets Manager, App Runner env vars, etc.) —
	// loading a .env file there would let a stray file silently override
	// deployment config, so it's skipped entirely outside development.
	if getEnv("APP_ENV", "development") != "production" {
		if err := godotenv.Load(); err != nil {
			log.Println("no .env file found, relying on system environment variables")
		}
	}

	accessMins, err := strconv.Atoi(getEnv("JWT_ACCESS_EXPIRY_MINUTES", "15"))
	if err != nil {
		accessMins = 15
	}
	refreshDays, err := strconv.Atoi(getEnv("JWT_REFRESH_EXPIRY_DAYS", "7"))
	if err != nil {
		refreshDays = 7
	}

	origins := splitAndTrim(getEnv("ALLOWED_ORIGINS", "http://localhost:5000"))
	appEnv := getEnv("APP_ENV", "development")

	for _, origin := range origins {
		if origin == "*" {
			log.Fatal("ALLOWED_ORIGINS must not contain '*' — CORS is configured with AllowCredentials, and a wildcard origin combined with credentials is a known-dangerous misconfiguration")
		}
	}

	dbSSLMode := getEnv("DB_SSLMODE", "disable")
	if appEnv == "production" && dbSSLMode == "disable" {
		log.Fatal("DB_SSLMODE must not be 'disable' in production — set it to 'require' or 'verify-full'")
	}

	trustedProxies := splitAndTrim(getEnv("TRUSTED_PROXIES", ""))

	return &Config{
		AppEnv:  appEnv,
		AppPort: getEnv("APP_PORT", "8080"),

		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "climatetech"),
		DBPassword: requireEnv("DB_PASSWORD"),
		DBName:     getEnv("DB_NAME", "climatetech_db"),
		DBSSLMode:  dbSSLMode,

		RedisHost:     getEnv("REDIS_HOST", "localhost"),
		RedisPort:     getEnv("REDIS_PORT", "6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),

		JWTAccessSecret:      requireEnv("JWT_ACCESS_SECRET"),
		JWTRefreshSecret:     requireEnv("JWT_REFRESH_SECRET"),
		JWTAccessExpiryMins:  accessMins,
		JWTRefreshExpiryDays: refreshDays,

		OpenWeatherAPIKey: getEnv("OPENWEATHER_API_KEY", ""),

		GeminiAPIKey: getEnv("GEMINI_API_KEY", ""),
		GeminiModel:  getEnv("GEMINI_MODEL", "gemini-1.5-flash"),

		FirebaseCredentialsPath: getEnv("FIREBASE_CREDENTIALS_PATH", ""),

		NewsAPIKey: getEnv("NEWS_API_KEY", ""),

		AllowedOrigins: origins,
		TrustedProxies: trustedProxies,
	}
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

// splitAndTrim splits a comma-separated env value into a trimmed, non-empty
// slice — used for ALLOWED_ORIGINS/TRUSTED_PROXIES so stray whitespace after
// a comma (a common copy-paste artifact in deploy configs) doesn't produce a
// literal " https://example.com" entry that never matches a real request.
func splitAndTrim(v string) []string {
	if v == "" {
		return nil
	}
	parts := strings.Split(v, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			result = append(result, p)
		}
	}
	return result
}

// requireEnv reads a secret that must never silently fall back to a
// hardcoded default (JWT signing keys, DB password) — a missing value here
// means misconfiguration, not "use dev settings," so the app refuses to
// start rather than run with a guessable secret.
func requireEnv(key string) string {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		log.Fatalf("%s is required but not set — refusing to start without it", key)
	}
	return v
}
