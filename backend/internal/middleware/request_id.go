package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// RequestIDHeader is the header name clients/load balancers can supply (or
// that we generate) to correlate a request across logs.
const RequestIDHeader = "X-Request-ID"

// RequestIDKey is the gin.Context key the request ID is stored under.
const RequestIDKey = "request_id"

// RequestID assigns a unique ID to every request (reusing an inbound
// X-Request-ID if the caller/ALB already set one) so a single request's log
// lines can be correlated in CloudWatch, and echoes it back in the response.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = uuid.NewString()
		}
		c.Set(RequestIDKey, id)
		c.Header(RequestIDHeader, id)
		c.Next()
	}
}

// GetRequestID reads the request ID set by RequestID, if present.
func GetRequestID(c *gin.Context) string {
	if v, ok := c.Get(RequestIDKey); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
