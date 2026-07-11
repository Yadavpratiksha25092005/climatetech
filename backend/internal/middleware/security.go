package middleware

import (
	"net/http"

	"climatetech-backend/internal/config"

	"github.com/gin-gonic/gin"
)

// SecurityHeaders adds standard defense-in-depth response headers. This is a
// pure JSON API (no HTML rendered), so CSP is locked to "default-src 'none'"
// — there is nothing on this origin a browser should ever be allowed to
// load/execute as active content.
func SecurityHeaders(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "no-referrer")
		c.Header("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		// HSTS only makes sense once the client actually reached us over
		// HTTPS (directly, or via a TLS-terminating load balancer) — sending
		// it over plain HTTP in local dev would be a no-op at best and
		// confusing at worst.
		if cfg.AppEnv == "production" {
			c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		c.Next()
	}
}

// maxRequestBodyBytes bounds any single JSON request body. Every payload this
// API accepts (auth, profile, carbon logs, marketplace listings) is small
// structured JSON — 1MB is generous headroom while still closing off a
// trivial memory-exhaustion vector on unauthenticated endpoints like
// /auth/register.
const maxRequestBodyBytes = 1 << 20 // 1MB

// BodySizeLimit rejects request bodies larger than maxRequestBodyBytes before
// any handler-level binding/validation runs.
func BodySizeLimit() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxRequestBodyBytes)
		c.Next()
	}
}

// RequireHTTPS rejects plaintext HTTP in production. It trusts
// X-Forwarded-Proto, which is only meaningful once Gin's trusted-proxy list
// is configured correctly (see main.go) — otherwise this would be trivially
// spoofable by any client.
func RequireHTTPS(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if cfg.AppEnv != "production" {
			c.Next()
			return
		}
		proto := c.GetHeader("X-Forwarded-Proto")
		if proto != "" && proto != "https" {
			c.AbortWithStatusJSON(http.StatusUpgradeRequired, gin.H{
				"success": false,
				"message": "HTTPS is required",
			})
			return
		}
		c.Next()
	}
}
