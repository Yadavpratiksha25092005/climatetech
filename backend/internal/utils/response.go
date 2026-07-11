package utils

import (
	"log/slog"

	"github.com/gin-gonic/gin"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

func Success(c *gin.Context, status int, message string, data interface{}) {
	c.JSON(status, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// Fail sends an error response. For 5xx statuses, the underlying error is
// logged server-side (with request context for CloudWatch correlation) but
// never included in the JSON body — raw DB/driver errors can contain schema
// details, constraint names, or connection info (CWE-209 information
// exposure) that a client has no legitimate need to see. 4xx errors are
// caller-facing by design (validation messages, etc.) and are still echoed.
func Fail(c *gin.Context, status int, message string, err error) {
	resp := APIResponse{
		Success: false,
		Message: message,
	}

	if err != nil {
		if status >= 500 {
			requestID, _ := c.Get("request_id")
			slog.Error("request failed",
				"request_id", requestID,
				"status", status,
				"path", c.Request.URL.Path,
				"error", err.Error(),
			)
		} else {
			resp.Error = err.Error()
		}
	}

	c.JSON(status, resp)
}
