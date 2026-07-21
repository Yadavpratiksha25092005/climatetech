package middleware

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"climatetech-backend/internal/config"
	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// activeStatusCacheTTL bounds how long a deactivated user can keep using an
// already-issued access token before AuthRequired notices. AuthRequired runs
// on every authenticated request in the app — the hottest path in the
// backend — so a DB lookup here on every single call was judged too costly;
// the is_active result is cached in Redis for this long instead, and a
// cache miss/error falls back to Postgres. Worst case this adds up to
// activeStatusCacheTTL of continued access after deactivation; RefreshToken
// separately re-checks is_active with no caching, closing the rest of the
// gap up to the access token's full remaining lifetime.
const activeStatusCacheTTL = 60 * time.Second

func activeStatusCacheKey(userID uuid.UUID) string {
	return "active_status:" + userID.String()
}

// LoggedOutAtKey stores the Unix timestamp of a user's most recent logout.
// AuthRequired rejects any access token issued before this time, so logout
// revokes the token immediately instead of waiting out its remaining
// lifetime.
func LoggedOutAtKey(userID uuid.UUID) string {
	return "logged_out_at:" + userID.String()
}

func isUserActive(userID uuid.UUID) (bool, error) {
	cached, err := database.RedisClient.Get(database.Ctx, activeStatusCacheKey(userID)).Result()
	if err == nil {
		return cached == "1", nil
	}

	var user models.User
	if err := database.DB.Select("is_active").First(&user, "id = ?", userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, nil
		}
		return false, err
	}

	value := "0"
	if user.IsActive {
		value = "1"
	}
	// Best-effort — a failed cache write just means the next request falls
	// back to the DB again, not a correctness problem.
	database.RedisClient.Set(database.Ctx, activeStatusCacheKey(userID), value, activeStatusCacheTTL)

	return user.IsActive, nil
}

// AuthRequired validates the access token, confirms the account is still
// active, and injects user claims into context.
func AuthRequired(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			utils.Fail(c, http.StatusUnauthorized, "missing authorization header", nil)
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			utils.Fail(c, http.StatusUnauthorized, "invalid authorization header format", nil)
			c.Abort()
			return
		}

		claims, err := utils.ParseToken(parts[1], cfg.JWTAccessSecret)
		if err != nil {
			utils.Fail(c, http.StatusUnauthorized, "invalid or expired token", err)
			c.Abort()
			return
		}

		if claims.Type != utils.AccessToken {
			utils.Fail(c, http.StatusUnauthorized, "token is not an access token", nil)
			c.Abort()
			return
		}

		loggedOutAt, err := database.RedisClient.Get(database.Ctx, LoggedOutAtKey(claims.UserID)).Result()
		if err == nil && claims.IssuedAt != nil {
			if loggedOutUnix, parseErr := strconv.ParseInt(loggedOutAt, 10, 64); parseErr == nil {
				if claims.IssuedAt.Unix() <= loggedOutUnix {
					utils.Fail(c, http.StatusUnauthorized, "token has been revoked", nil)
					c.Abort()
					return
				}
			}
		}

		active, err := isUserActive(claims.UserID)
		if err != nil {
			utils.Fail(c, http.StatusInternalServerError, "failed to verify account status", err)
			c.Abort()
			return
		}
		if !active {
			utils.Fail(c, http.StatusForbidden, "account is deactivated", nil)
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("role", claims.Role)
		c.Next()
	}
}

// RequireRole restricts a route to specific roles (e.g. "admin").
func RequireRole(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("role")
		if !exists {
			utils.Fail(c, http.StatusForbidden, "role not found in context", nil)
			c.Abort()
			return
		}

		roleStr, _ := role.(string)
		for _, r := range roles {
			if r == roleStr {
				c.Next()
				return
			}
		}

		utils.Fail(c, http.StatusForbidden, "insufficient permissions", nil)
		c.Abort()
	}
}
