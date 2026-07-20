package handlers

import (
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"climatetech-backend/internal/config"
	"climatetech-backend/internal/database"
	"climatetech-backend/internal/middleware"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// normalizeEmail lowercases and trims an email before it's ever used for
// lookup, uniqueness-checking, or storage — otherwise "Alice@x.com" and
// "alice@x.com" register as two distinct accounts, and a user who signed up
// with mixed case can't log back in typing it lowercase.
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

type AuthHandler struct {
	cfg *config.Config
}

func NewAuthHandler(cfg *config.Config) *AuthHandler {
	return &AuthHandler{cfg: cfg}
}

func refreshTokenKey(userID uuid.UUID) string {
	return "refresh:" + userID.String()
}

type RegisterRequest struct {
	Name     string `json:"name" binding:"required,min=2,max=150"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8,max=72"`
	Role     string `json:"role" binding:"omitempty,oneof=user organization"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type AuthResponse struct {
	User         models.UserResponse `json:"user"`
	AccessToken  string              `json:"access_token"`
	RefreshToken string              `json:"refresh_token"`
}

// Register creates a new user account.
func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}
	req.Email = normalizeEmail(req.Email)

	// Case-insensitive lookup (LOWER(email) rather than a plain equality
	// check) so this correctly finds an existing account regardless of the
	// case it was originally registered with — new accounts are always
	// stored lowercase (below), but pre-existing rows may still have mixed
	// case, and this must keep matching those without a data migration.
	var existing models.User
	if err := database.DB.Where("LOWER(email) = ?", req.Email).First(&existing).Error; err == nil {
		utils.Fail(c, http.StatusConflict, "an account with this email already exists", nil)
		return
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		utils.Fail(c, http.StatusInternalServerError, "failed to check existing user", err)
		return
	}

	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to secure password", err)
		return
	}

	role := models.RoleUser
	if req.Role == string(models.RoleOrganization) {
		role = models.RoleOrganization
	}

	user := models.User{
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: hashedPassword,
		Role:         role,
	}

	if err := database.DB.Create(&user).Error; err != nil {
		// Another request may have created the same email between the check
		// above and this insert; the DB's unique constraint is the real
		// source of truth for that race, so translate its violation into the
		// same 409 the pre-check gives in the common case, instead of a 500.
		if utils.IsUniqueViolation(err) {
			utils.Fail(c, http.StatusConflict, "an account with this email already exists", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to create user", err)
		return
	}

	tokens, err := h.issueTokens(user)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to issue tokens", err)
		return
	}

	utils.Success(c, http.StatusCreated, "registration successful", tokens)
}

// Login authenticates a user and returns access + refresh tokens.
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}
	req.Email = normalizeEmail(req.Email)

	// Same case-insensitive lookup as Register, so a user who registered
	// with mixed-case can still log in typing any case variant.
	var user models.User
	if err := database.DB.Where("LOWER(email) = ?", req.Email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusUnauthorized, "invalid email or password", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to look up user", err)
		return
	}

	// Password is checked before the active-status gate so a wrong password
	// always yields the same "invalid email or password" response an
	// attacker can't distinguish from a deactivated account — checking
	// IsActive first would let anyone probe which emails belong to
	// deactivated accounts without knowing their password.
	if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
		utils.Fail(c, http.StatusUnauthorized, "invalid email or password", nil)
		return
	}

	if !user.IsActive {
		utils.Fail(c, http.StatusForbidden, "account is deactivated", nil)
		return
	}

	tokens, err := h.issueTokens(user)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to issue tokens", err)
		return
	}

	utils.Success(c, http.StatusOK, "login successful", tokens)
}

// RefreshToken exchanges a valid refresh token for a new access token.
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	claims, err := utils.ParseToken(req.RefreshToken, h.cfg.JWTRefreshSecret)
	if err != nil || claims.Type != utils.RefreshToken {
		utils.Fail(c, http.StatusUnauthorized, "invalid or expired refresh token", err)
		return
	}

	// Verify refresh token hasn't been revoked (stored in Redis at login time)
	stored, err := database.RedisClient.Get(database.Ctx, refreshTokenKey(claims.UserID)).Result()
	if err != nil || stored != req.RefreshToken {
		utils.Fail(c, http.StatusUnauthorized, "refresh token has been revoked", nil)
		return
	}

	// Re-checked on every refresh, not just at login — otherwise a
	// deactivated account's refresh token keeps minting valid access tokens
	// until it naturally expires (up to JWTRefreshExpiryDays later).
	var user models.User
	if err := database.DB.Select("id", "is_active").First(&user, "id = ?", claims.UserID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusUnauthorized, "invalid or expired refresh token", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to look up user", err)
		return
	}
	if !user.IsActive {
		// Best-effort cleanup — even if this Del fails, the same is_active
		// check catches the next refresh attempt too, so the 403 below is
		// what actually matters, not whether this cache entry is cleared.
		if err := database.RedisClient.Del(database.Ctx, refreshTokenKey(claims.UserID)).Err(); err != nil {
			log.Printf("failed to revoke refresh token for deactivated user %s: %v", claims.UserID, err)
		}
		utils.Fail(c, http.StatusForbidden, "account is deactivated", nil)
		return
	}

	accessToken, err := utils.GenerateAccessToken(claims.UserID, claims.Email, claims.Role, h.cfg.JWTAccessSecret, h.cfg.JWTAccessExpiryMins)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to generate access token", err)
		return
	}

	utils.Success(c, http.StatusOK, "token refreshed", gin.H{"access_token": accessToken})
}

// Logout revokes the stored refresh token.
func (h *AuthHandler) Logout(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}
	userID, ok := userIDVal.(uuid.UUID)
	if !ok {
		utils.Fail(c, http.StatusInternalServerError, "invalid user context", nil)
		return
	}

	if err := database.RedisClient.Del(database.Ctx, refreshTokenKey(userID)).Err(); err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to log out", err)
		return
	}

	// Recorded so AuthRequired can reject any access token issued before
	// this moment, even though the token itself remains cryptographically
	// valid until it expires. TTL matches the refresh token lifetime since
	// no access token can outlive it.
	revokeWindow := time.Duration(h.cfg.JWTRefreshExpiryDays) * 24 * time.Hour
	if err := database.RedisClient.Set(database.Ctx, middleware.LoggedOutAtKey(userID), time.Now().Unix(), revokeWindow).Err(); err != nil {
		log.Printf("failed to record logout timestamp for user %s: %v", userID, err)
	}

	utils.Success(c, http.StatusOK, "logged out successfully", nil)
}

func (h *AuthHandler) issueTokens(user models.User) (*AuthResponse, error) {
	accessToken, err := utils.GenerateAccessToken(user.ID, user.Email, string(user.Role), h.cfg.JWTAccessSecret, h.cfg.JWTAccessExpiryMins)
	if err != nil {
		return nil, err
	}

	refreshToken, err := utils.GenerateRefreshToken(user.ID, user.Email, string(user.Role), h.cfg.JWTRefreshSecret, h.cfg.JWTRefreshExpiryDays)
	if err != nil {
		return nil, err
	}

	// Store refresh token in Redis so it can be revoked/rotated
	expiry := time.Duration(h.cfg.JWTRefreshExpiryDays) * 24 * time.Hour
	if err := database.RedisClient.Set(database.Ctx, refreshTokenKey(user.ID), refreshToken, expiry).Err(); err != nil {
		return nil, err
	}

	return &AuthResponse{
		User:         user.ToResponse(),
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}
