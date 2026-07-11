package handlers

import (
	"log"
	"net/http"
	"strings"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type UserHandler struct{}

func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

type UpdateProfileRequest struct {
	Name   string `json:"name" binding:"omitempty,min=2,max=150"`
	Avatar string `json:"avatar" binding:"omitempty,url"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=8,max=72"`
}

type UpdateFCMTokenRequest struct {
	FCMToken string `json:"fcm_token" binding:"required,max=4096"`
}

// profileResponse embeds the standard UserResponse (id/name/email/role/
// avatar/total_points/badges/created_at) and anonymously flattens it in JSON,
// alongside profile-only fields that don't belong on every UserResponse
// caller (e.g. auth login/register).
type profileResponse struct {
	models.UserResponse
	CompletedChallengesCount int64 `json:"completed_challenges_count"`
}

// GetProfile returns the authenticated user's profile, including how many
// challenges they've completed all-time.
func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var user models.User
	if err := database.DB.First(&user, "id = ?", userID).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "user not found", err)
		return
	}

	var completedChallengesCount int64
	if err := database.DB.Model(&models.UserChallenge{}).
		Where("user_id = ? AND status = ?", userID, models.UserChallengeStatusCompleted).
		Count(&completedChallengesCount).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count completed challenges", err)
		return
	}

	utils.Success(c, http.StatusOK, "profile fetched", profileResponse{
		UserResponse:             user.ToResponse(),
		CompletedChallengesCount: completedChallengesCount,
	})
}

// UpdateProfile updates name/avatar for the authenticated user.
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var user models.User
	if err := database.DB.First(&user, "id = ?", userID).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "user not found", err)
		return
	}

	if trimmedName := strings.TrimSpace(req.Name); trimmedName != "" {
		user.Name = trimmedName
	}
	if req.Avatar != "" {
		user.Avatar = req.Avatar
	}

	if err := database.DB.Save(&user).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update profile", err)
		return
	}

	utils.Success(c, http.StatusOK, "profile updated", user.ToResponse())
}

// ChangePassword updates the authenticated user's password.
func (h *UserHandler) ChangePassword(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var user models.User
	if err := database.DB.First(&user, "id = ?", userID).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "user not found", err)
		return
	}

	if !utils.CheckPasswordHash(req.CurrentPassword, user.PasswordHash) {
		utils.Fail(c, http.StatusUnauthorized, "current password is incorrect", nil)
		return
	}

	newHash, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to secure new password", err)
		return
	}

	user.PasswordHash = newHash
	if err := database.DB.Save(&user).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update password", err)
		return
	}

	// Revoke the stored refresh token so any other logged-in session (or a
	// leaked refresh token) can't keep minting new access tokens after the
	// password that was supposed to invalidate it has changed. Best-effort:
	// the password change itself has already succeeded and must not fail
	// over a Redis hiccup here.
	if err := database.RedisClient.Del(database.Ctx, refreshTokenKey(userID)).Err(); err != nil {
		log.Printf("failed to revoke refresh token after password change for user %s: %v", userID, err)
	}

	utils.Success(c, http.StatusOK, "password changed successfully", nil)
}

// UpdateFCMToken saves the authenticated user's current Firebase Cloud
// Messaging device token, used to deliver climate alert push notifications.
func (h *UserHandler) UpdateFCMToken(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req UpdateFCMTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	if err := database.DB.Model(&models.User{}).Where("id = ?", userID).Update("fcm_token", req.FCMToken).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to save fcm token", err)
		return
	}

	utils.Success(c, http.StatusOK, "fcm token saved", nil)
}
