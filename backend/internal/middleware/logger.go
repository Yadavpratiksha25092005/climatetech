package middleware

import (
	"log/slog"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger emits one structured (JSON, via slog's default handler set up in
// main.go) log line per request, tagged with the request ID from RequestID
// so a single request's log line can be found/correlated in CloudWatch Logs
// Insights by request_id, status, or client IP.
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next()

		path := c.Request.URL.Path
		if c.Request.URL.RawQuery != "" {
			path += "?" + c.Request.URL.RawQuery
		}

		level := slog.LevelInfo
		status := c.Writer.Status()
		if status >= 500 {
			level = slog.LevelError
		} else if status >= 400 {
			level = slog.LevelWarn
		}

		slog.Log(c.Request.Context(), level, "request",
			"request_id", GetRequestID(c),
			"status", status,
			"method", c.Request.Method,
			"path", path,
			"latency_ms", time.Since(start).Milliseconds(),
			"client_ip", c.ClientIP(),
		)
	}
}
