package middleware

import (
	"fmt"
	"net/http"
	"time"

	"climatetech-backend/internal/database"

	"github.com/gin-gonic/gin"
)

// RateLimit throttles a route to maxAttempts requests per window, keyed by
// client IP — implemented with Redis INCR+EXPIRE so the limit is shared
// correctly across every horizontally-scaled instance of the app (an
// in-process limiter would let each ECS task/App Runner instance grant its
// own separate quota, defeating the point once there's more than one).
// Fails open (allows the request) on a Redis error — an outage of the rate
// limiter itself must not take down login/register entirely.
func RateLimit(keyPrefix string, maxAttempts int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := fmt.Sprintf("ratelimit:%s:%s", keyPrefix, c.ClientIP())

		count, err := database.RedisClient.Incr(database.Ctx, key).Result()
		if err != nil {
			c.Next()
			return
		}

		// INCR and EXPIRE aren't atomic together — if the EXPIRE below ever
		// fails (a transient Redis error) right after the count==1 INCR
		// created the key, the key would be left with no TTL and count
		// upward forever, permanently locking out that IP once it crosses
		// maxAttempts. Checking TTL on every request (not just count==1)
		// self-heals that case by re-applying the expiry as soon as it's
		// noticed missing, instead of trusting the first attempt succeeded.
		ttl, ttlErr := database.RedisClient.TTL(database.Ctx, key).Result()
		if ttlErr == nil && ttl < 0 {
			database.RedisClient.Expire(database.Ctx, key, window)
			ttl = window
		}

		if count > int64(maxAttempts) {
			retryAfter := window
			if ttlErr == nil && ttl > 0 {
				retryAfter = ttl
			}
			c.Header("Retry-After", fmt.Sprintf("%.0f", retryAfter.Seconds()))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"success": false,
				"message": "too many requests — please try again later",
			})
			return
		}

		c.Next()
	}
}
