package handlers

import (
	"log"
	"net/http"
	"sync"
	"sync/atomic"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AdminNotificationHandler struct {
	fcmService *services.FCMService
}

func NewAdminNotificationHandler(fcmService *services.FCMService) *AdminNotificationHandler {
	return &AdminNotificationHandler{fcmService: fcmService}
}

type broadcastRequest struct {
	Title   string `json:"title" binding:"required,max=200"`
	Message string `json:"message" binding:"required,max=2000"`
	// "all" or a specific user_id.
	Target string `json:"target" binding:"required"`
}

// broadcastWorkerCount bounds how many recipients are processed concurrently
// — high enough to avoid the old fully-sequential per-recipient latency
// (which could time out the request for any non-trivial user base), low
// enough not to overwhelm the DB connection pool or the FCM/Postgres
// connections with an unbounded fan-out.
const broadcastWorkerCount = 10

// Broadcast sends a push notification (best-effort — SendPushNotification
// already no-ops for recipients with no FCM token) and creates an in-app
// Alert record for each recipient, fanning the work out across a bounded
// worker pool instead of processing recipients one at a time. One
// recipient's failure never stops any other recipient from being processed.
// POST /api/v1/admin/notifications/broadcast
func (h *AdminNotificationHandler) Broadcast(c *gin.Context) {
	var req broadcastRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	recipients, err := h.resolveRecipients(req.Target)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid target", err)
		return
	}
	if len(recipients) == 0 {
		utils.Success(c, http.StatusOK, "no recipients found", gin.H{"sent_count": 0})
		return
	}

	var sentCount int64
	var pushFailedCount int64

	jobs := make(chan models.User)
	var wg sync.WaitGroup
	workers := broadcastWorkerCount
	if workers > len(recipients) {
		workers = len(recipients)
	}
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for recipient := range jobs {
				h.notifyOne(recipient, req.Title, req.Message, &sentCount, &pushFailedCount)
			}
		}()
	}
	for _, recipient := range recipients {
		jobs <- recipient
	}
	close(jobs)
	wg.Wait()

	utils.Success(c, http.StatusOK, "broadcast sent", gin.H{
		"sent_count":        atomic.LoadInt64(&sentCount),
		"recipient_count":   len(recipients),
		"push_failed_count": atomic.LoadInt64(&pushFailedCount),
	})
}

// notifyOne sends the push (if configured) and creates the in-app alert for
// a single recipient, incrementing the shared counters. Safe to call
// concurrently from multiple workers — sentCount/pushFailedCount are only
// ever mutated via atomic ops.
func (h *AdminNotificationHandler) notifyOne(recipient models.User, title, message string, sentCount, pushFailedCount *int64) {
	if h.fcmService != nil {
		if err := h.fcmService.SendPushNotification(recipient.FCMToken, title, message); err != nil {
			log.Printf("failed to send broadcast push to user %s: %v", recipient.ID, err)
			atomic.AddInt64(pushFailedCount, 1)
			// Push failing doesn't stop the in-app alert below.
		}
	}

	alert := models.Alert{
		UserID:    recipient.ID,
		AlertType: models.AlertTypeAdminBroadcast,
		Severity:  "info",
		Title:     title,
		Message:   message,
	}
	if err := database.DB.Create(&alert).Error; err != nil {
		log.Printf("failed to create broadcast alert for user %s: %v", recipient.ID, err)
		return
	}
	atomic.AddInt64(sentCount, 1)
}

// resolveRecipients returns everyone to notify. For "all", that's every
// active user with an FCM token registered; for anything else, target is
// parsed as a single user_id. Only id/fcm_token are selected — no full-row
// loads for what's ultimately a fan-out over id + token.
func (h *AdminNotificationHandler) resolveRecipients(target string) ([]models.User, error) {
	if target == "all" {
		// Every active user is a recipient of the in-app Alert regardless of
		// whether they have a push token — excluding no-token users here
		// would silently drop them from the in-app alert too, not just the
		// push. SendPushNotification already no-ops for an empty token, so
		// there's no need to pre-filter for push eligibility.
		var users []models.User
		err := database.DB.Select("id", "fcm_token").
			Where("is_active = ?", true).
			Find(&users).Error
		return users, err
	}

	userID, err := uuid.Parse(target)
	if err != nil {
		return nil, err
	}
	var user models.User
	if err := database.DB.Select("id", "fcm_token").First(&user, "id = ?", userID).Error; err != nil {
		return nil, err
	}
	return []models.User{user}, nil
}
