package handlers

import (
	"net/http"
	"strconv"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AlertHandler struct{}

func NewAlertHandler() *AlertHandler {
	return &AlertHandler{}
}

// GetHistory returns the authenticated user's recent climate alerts, newest first.
// GET /api/v1/alerts/history?limit=50
func (h *AlertHandler) GetHistory(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	limit, err := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if err != nil || limit <= 0 || limit > 200 {
		limit = 50
	}

	var alerts []models.Alert
	if err := database.DB.
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(limit).
		Find(&alerts).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch alert history", err)
		return
	}

	utils.Success(c, http.StatusOK, "alert history fetched", alerts)
}

// GetUnreadCount returns how many of the authenticated user's alerts are
// still unread — a single COUNT query, no N+1.
// GET /api/v1/alerts/unread-count
func (h *AlertHandler) GetUnreadCount(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var count int64
	if err := database.DB.Model(&models.Alert{}).
		Where("user_id = ? AND is_read = ?", userID, false).
		Count(&count).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count unread alerts", err)
		return
	}

	utils.Success(c, http.StatusOK, "unread alert count fetched", gin.H{"count": count})
}

// MarkAsRead marks one of the authenticated user's own alerts as read.
// Scoped by user_id so a user can't mark another user's alert as read.
// PUT /api/v1/alerts/:id/read
func (h *AlertHandler) MarkAsRead(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid alert id", err)
		return
	}

	result := database.DB.Model(&models.Alert{}).
		Where("id = ? AND user_id = ?", alertID, userID).
		Update("is_read", true)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to mark alert as read", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "alert not found", nil)
		return
	}

	utils.Success(c, http.StatusOK, "alert marked as read", nil)
}
