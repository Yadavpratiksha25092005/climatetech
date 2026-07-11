package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type ChallengeHandler struct {
	geminiService *services.GeminiService
}

func NewChallengeHandler(geminiService *services.GeminiService) *ChallengeHandler {
	return &ChallengeHandler{geminiService: geminiService}
}

// isSameUTCDay compares calendar dates after normalizing both times to UTC,
// so the check-in "once per day" rule can't be thrown off by the server's
// local timezone setting or by whatever timezone the DB driver hands back.
func isSameUTCDay(a, b time.Time) bool {
	au, bu := a.UTC(), b.UTC()
	return au.Year() == bu.Year() && au.Month() == bu.Month() && au.Day() == bu.Day()
}

type challengeWithProgress struct {
	models.Challenge
	Joined              bool                       `json:"joined"`
	TotalCheckIns       int                        `json:"total_check_ins"`
	Status              models.UserChallengeStatus `json:"status,omitempty"`
	CheckedInToday      bool                       `json:"checked_in_today"`
	PersonalizedBenefit *string                    `json:"personalized_benefit"`
	Source              string                     `json:"source"`
}

// GetChallenges lists active challenges alongside the current user's
// join/progress status for each. This is always exactly 2 queries for that
// part — one for the challenges, one for all of the user's UserChallenge
// rows — never one query per challenge. It then makes at most ONE additional
// Gemini call (never one per challenge) to personalize each challenge's
// benefit text against this user's own carbon data, falling back to the
// static BenefitInfo for every challenge on any failure.
// GET /api/v1/challenges
func (h *ChallengeHandler) GetChallenges(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var challenges []models.Challenge
	if err := database.DB.Where("is_active = ?", true).Order("created_at ASC").Find(&challenges).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch challenges", err)
		return
	}

	var userChallenges []models.UserChallenge
	if err := database.DB.Where("user_id = ?", userID).Find(&userChallenges).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your challenge progress", err)
		return
	}
	progressByChallenge := make(map[uuid.UUID]models.UserChallenge, len(userChallenges))
	for _, uc := range userChallenges {
		progressByChallenge[uc.ChallengeID] = uc
	}

	now := time.Now()
	results := make([]challengeWithProgress, 0, len(challenges))
	for _, challenge := range challenges {
		item := challengeWithProgress{Challenge: challenge, Source: "rule_based"}
		if uc, ok := progressByChallenge[challenge.ID]; ok {
			item.Joined = true
			item.TotalCheckIns = uc.TotalCheckIns
			item.Status = uc.Status
			item.CheckedInToday = uc.LastCheckInDate != nil && isSameUTCDay(*uc.LastCheckInDate, now)
		}
		results = append(results, item)
	}

	h.attachPersonalizedBenefits(userID, challenges, results, now)

	utils.Success(c, http.StatusOK, "challenges fetched", results)
}

// attachPersonalizedBenefits makes at most one Gemini call for the whole
// challenge list and writes results in place. Every failure path (no Gemini
// service configured, DB error computing the user's carbon data, API error,
// unparseable response) simply leaves the static BenefitInfo/"rule_based"
// source already set on results — this never fails the endpoint.
func (h *ChallengeHandler) attachPersonalizedBenefits(userID uuid.UUID, challenges []models.Challenge, results []challengeWithProgress, now time.Time) {
	if h.geminiService == nil || len(challenges) == 0 {
		return
	}

	// Pinned to UTC to agree with isSameUTCDay/CheckIn's day boundary below,
	// rather than the server's local timezone — using server-local here
	// while check-ins are decided in UTC would disagree near local midnight
	// about which activity counts toward "this week"/"this month".
	now = now.UTC()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	startOfWeek := startOfDay.AddDate(0, 0, -int(now.Weekday()))
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)

	weekTotal, err := co2TotalSince(userID, startOfWeek)
	if err != nil {
		log.Printf("failed to compute weekly CO2 for personalized benefits, falling back to static: %v", err)
		return
	}

	var highestCategory string
	if breakdown, err := categoryTotalsSince(userID, startOfMonth); err == nil && len(breakdown) > 0 {
		top := breakdown[0]
		for _, b := range breakdown[1:] {
			if b.CO2Kg > top.CO2Kg {
				top = b
			}
		}
		highestCategory = top.Category
	}

	benefits, err := h.generatePersonalizedBenefits(challenges, weekTotal, highestCategory)
	if err != nil {
		log.Printf("gemini personalized benefits generation failed, falling back to static benefit_info: %v", err)
		return
	}

	for i := range results {
		if benefit, ok := benefits[results[i].ID.String()]; ok && benefit != "" {
			results[i].PersonalizedBenefit = &benefit
			results[i].Source = "ai"
		}
	}
}

// generatePersonalizedBenefits makes exactly one Gemini call listing every
// active challenge alongside this user's weekly CO2 total and highest
// emission category, and returns a challenge_id -> personalized_benefit map.
func (h *ChallengeHandler) generatePersonalizedBenefits(challenges []models.Challenge, weekTotalKg float64, highestCategory string) (map[string]string, error) {
	text, err := h.geminiService.GenerateInsights(buildPersonalizedBenefitPrompt(challenges, weekTotalKg, highestCategory))
	if err != nil {
		return nil, err
	}

	var parsed []struct {
		ChallengeID         string `json:"challenge_id"`
		PersonalizedBenefit string `json:"personalized_benefit"`
	}
	if err := json.Unmarshal([]byte(extractJSONArray(text)), &parsed); err != nil {
		return nil, fmt.Errorf("failed to parse gemini response: %w", err)
	}
	if len(parsed) == 0 {
		return nil, fmt.Errorf("gemini returned no personalized benefits")
	}

	result := make(map[string]string, len(parsed))
	for _, p := range parsed {
		if p.ChallengeID != "" && p.PersonalizedBenefit != "" {
			result[p.ChallengeID] = p.PersonalizedBenefit
		}
	}
	return result, nil
}

func buildPersonalizedBenefitPrompt(challenges []models.Challenge, weekTotalKg float64, highestCategory string) string {
	category := highestCategory
	if category == "" {
		category = "none logged yet"
	}

	var sb strings.Builder
	for _, ch := range challenges {
		fmt.Fprintf(&sb, "- challenge_id: %s | title: %q | static_benefit: %q\n", ch.ID, ch.Title, ch.BenefitInfo)
	}

	return fmt.Sprintf(`You are a friendly climate coach inside a carbon-footprint tracking app. Here is this user's own data:
- This week's CO2 logged so far: %.1f kg
- Highest-emission category this month: %s

Here are the active challenges (with their generic static benefit text for reference only):
%s
Return ONLY a JSON array (no markdown, no code fences, no extra text) with exactly one object per challenge listed above, each with exactly these keys:
"challenge_id" (copy exactly as given above),
"personalized_benefit" (1-2 encouraging sentences connecting this specific challenge to this user's own data above — reference their weekly CO2 total or highest-emission category where relevant).`,
		weekTotalKg, category, sb.String(),
	)
}

// JoinChallenge lets the authenticated user join an active challenge.
// POST /api/v1/challenges/:id/join
func (h *ChallengeHandler) JoinChallenge(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	challengeID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid challenge id", err)
		return
	}

	var challenge models.Challenge
	if err := database.DB.Where("id = ? AND is_active = ?", challengeID, true).First(&challenge).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "challenge not found", err)
		return
	}

	existingErr := database.DB.Where("user_id = ? AND challenge_id = ?", userID, challengeID).First(&models.UserChallenge{}).Error
	if existingErr == nil {
		utils.Fail(c, http.StatusConflict, "you've already joined this challenge", nil)
		return
	}
	if !errors.Is(existingErr, gorm.ErrRecordNotFound) {
		utils.Fail(c, http.StatusInternalServerError, "failed to check existing progress", existingErr)
		return
	}

	userChallenge := models.UserChallenge{
		UserID:      userID,
		ChallengeID: challengeID,
		Status:      models.UserChallengeStatusActive,
	}
	if err := database.DB.Create(&userChallenge).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to join challenge", err)
		return
	}

	utils.Success(c, http.StatusCreated, "joined challenge", userChallenge)
}

type checkInResult struct {
	TotalCheckIns int                        `json:"total_check_ins"`
	Status        models.UserChallengeStatus `json:"status"`
	PointsAwarded int                        `json:"points_awarded"`
}

// CheckIn records one check-in per calendar UTC day and awards points,
// marking the challenge completed once enough check-ins have accumulated.
// The read-check-write sequence runs inside a transaction that locks the
// UserChallenge row (SELECT ... FOR UPDATE), so two concurrent check-in
// requests for the same user+challenge (e.g. a retried request) can't both
// pass the "already checked in today" guard and double-award points — the
// second one blocks until the first commits, then correctly sees today's
// check-in already recorded. The ChallengeCheckInLog row is written in the
// same transaction as the points update, so reports can never see one
// without the other.
// POST /api/v1/challenges/:id/checkin
func (h *ChallengeHandler) CheckIn(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	challengeID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid challenge id", err)
		return
	}

	now := time.Now()
	var result checkInResult
	var notJoined, alreadyCompleted, alreadyCheckedIn bool

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var userChallenge models.UserChallenge
		lockErr := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("user_id = ? AND challenge_id = ?", userID, challengeID).
			First(&userChallenge).Error
		if lockErr != nil {
			if errors.Is(lockErr, gorm.ErrRecordNotFound) {
				notJoined = true
				return nil
			}
			return lockErr
		}

		if userChallenge.Status == models.UserChallengeStatusCompleted {
			alreadyCompleted = true
			return nil
		}

		if userChallenge.LastCheckInDate != nil && isSameUTCDay(*userChallenge.LastCheckInDate, now) {
			alreadyCheckedIn = true
			return nil
		}

		var challenge models.Challenge
		if err := tx.First(&challenge, "id = ?", challengeID).Error; err != nil {
			return err
		}

		userChallenge.TotalCheckIns++
		userChallenge.LastCheckInDate = &now
		if userChallenge.TotalCheckIns >= challenge.DurationDays {
			userChallenge.Status = models.UserChallengeStatusCompleted
		}
		if err := tx.Save(&userChallenge).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.User{}).Where("id = ?", userID).
			Update("total_points", gorm.Expr("total_points + ?", challenge.PointsPerCheckIn)).Error; err != nil {
			return err
		}

		checkInLog := models.ChallengeCheckInLog{
			UserID:        userID,
			ChallengeID:   challengeID,
			CheckedInAt:   now,
			PointsAwarded: challenge.PointsPerCheckIn,
		}
		if err := tx.Create(&checkInLog).Error; err != nil {
			return err
		}

		result = checkInResult{
			TotalCheckIns: userChallenge.TotalCheckIns,
			Status:        userChallenge.Status,
			PointsAwarded: challenge.PointsPerCheckIn,
		}
		return nil
	})

	if txErr != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to record check-in", txErr)
		return
	}
	if notJoined {
		utils.Fail(c, http.StatusBadRequest, "you haven't joined this challenge", nil)
		return
	}
	if alreadyCompleted {
		utils.Fail(c, http.StatusConflict, "you've already completed this challenge", nil)
		return
	}
	if alreadyCheckedIn {
		utils.Fail(c, http.StatusConflict, "you've already checked in today", nil)
		return
	}

	utils.Success(c, http.StatusOK, "checked in", result)
}

// GetNewChallengesCount returns how many active challenges the authenticated
// user has not yet joined — a single COUNT query with a NOT IN subquery,
// no N+1.
// GET /api/v1/challenges/new-count
func (h *ChallengeHandler) GetNewChallengesCount(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	joinedIDs := database.DB.Model(&models.UserChallenge{}).
		Select("challenge_id").
		Where("user_id = ?", userID)

	var count int64
	if err := database.DB.Model(&models.Challenge{}).
		Where("is_active = ? AND id NOT IN (?)", true, joinedIDs).
		Count(&count).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count new challenges", err)
		return
	}

	utils.Success(c, http.StatusOK, "new challenges count fetched", gin.H{"count": count})
}

// ---------- Admin challenge management ----------

type createChallengeRequest struct {
	Title            string `json:"title" binding:"required"`
	Description      string `json:"description"`
	BenefitInfo      string `json:"benefit_info"`
	Category         string `json:"category" binding:"required"`
	IconHint         string `json:"icon_hint" binding:"required"`
	PointsPerCheckIn int    `json:"points_per_check_in" binding:"required,gt=0"`
	DurationDays     int    `json:"duration_days" binding:"required,gt=0"`
}

// CreateChallengeAdmin creates a new challenge.
// POST /api/v1/admin/challenges
func (h *ChallengeHandler) CreateChallengeAdmin(c *gin.Context) {
	var req createChallengeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	challenge := models.Challenge{
		Title:            req.Title,
		Description:      req.Description,
		BenefitInfo:      req.BenefitInfo,
		Category:         req.Category,
		IconHint:         req.IconHint,
		PointsPerCheckIn: req.PointsPerCheckIn,
		DurationDays:     req.DurationDays,
		IsActive:         true,
	}
	if err := database.DB.Create(&challenge).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to create challenge", err)
		return
	}

	utils.Success(c, http.StatusCreated, "challenge created", challenge)
}

// updateChallengeRequest uses pointers throughout so only fields actually
// present in the request body get applied — omitted fields leave the
// existing column untouched instead of being zeroed out.
type updateChallengeRequest struct {
	Title            *string `json:"title"`
	Description      *string `json:"description"`
	BenefitInfo      *string `json:"benefit_info"`
	Category         *string `json:"category"`
	IconHint         *string `json:"icon_hint"`
	PointsPerCheckIn *int    `json:"points_per_check_in" binding:"omitempty,gt=0"`
	DurationDays     *int    `json:"duration_days" binding:"omitempty,gt=0"`
	IsActive         *bool   `json:"is_active"`
}

// UpdateChallengeAdmin partially updates a challenge.
// PUT /api/v1/admin/challenges/:id
func (h *ChallengeHandler) UpdateChallengeAdmin(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid challenge id", err)
		return
	}

	var req updateChallengeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var challenge models.Challenge
	if err := database.DB.First(&challenge, "id = ?", id).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "challenge not found", err)
		return
	}

	if req.Title != nil {
		challenge.Title = *req.Title
	}
	if req.Description != nil {
		challenge.Description = *req.Description
	}
	if req.BenefitInfo != nil {
		challenge.BenefitInfo = *req.BenefitInfo
	}
	if req.Category != nil {
		challenge.Category = *req.Category
	}
	if req.IconHint != nil {
		challenge.IconHint = *req.IconHint
	}
	if req.PointsPerCheckIn != nil {
		challenge.PointsPerCheckIn = *req.PointsPerCheckIn
	}
	if req.DurationDays != nil {
		challenge.DurationDays = *req.DurationDays
	}
	if req.IsActive != nil {
		challenge.IsActive = *req.IsActive
	}

	if err := database.DB.Save(&challenge).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update challenge", err)
		return
	}

	utils.Success(c, http.StatusOK, "challenge updated", challenge)
}

// DeleteChallengeAdmin soft-deletes a challenge by marking it inactive —
// never a hard delete, since existing UserChallenge/ChallengeCheckInLog rows
// reference it and users' check-in history/points must stay intact.
// DELETE /api/v1/admin/challenges/:id
func (h *ChallengeHandler) DeleteChallengeAdmin(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid challenge id", err)
		return
	}

	result := database.DB.Model(&models.Challenge{}).Where("id = ?", id).Update("is_active", false)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to deactivate challenge", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "challenge not found", nil)
		return
	}

	utils.Success(c, http.StatusOK, "challenge deactivated", nil)
}

type leaderboardEntry struct {
	UserID      uuid.UUID `json:"user_id"`
	Name        string    `json:"name"`
	Avatar      string    `json:"avatar,omitempty"`
	TotalPoints int       `json:"total_points"`
	Badges      []string  `json:"badges"`
	Rank        int       `json:"rank"`
}

// GetLeaderboard returns the top N users by total points, plus the current
// user's own rank/entry when they fall outside that top N (nil when they're
// already visible in the top list — the frontend can find itself there by
// user_id instead of getting a duplicate entry).
// GET /api/v1/leaderboard?limit=20
func (h *ChallengeHandler) GetLeaderboard(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	limit, err := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if err != nil || limit <= 0 || limit > 100 {
		limit = 20
	}

	var topUsers []models.User
	if err := database.DB.
		Where("total_points > 0").
		Order("total_points DESC, created_at ASC").
		Limit(limit).
		Find(&topUsers).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch leaderboard", err)
		return
	}

	top := make([]leaderboardEntry, 0, len(topUsers))
	inTopList := false
	for i, u := range topUsers {
		if u.ID == userID {
			inTopList = true
		}
		top = append(top, leaderboardEntry{
			UserID:      u.ID,
			Name:        u.Name,
			Avatar:      u.Avatar,
			TotalPoints: u.TotalPoints,
			Badges:      models.GetBadges(u.TotalPoints),
			Rank:        i + 1,
		})
	}

	var yourEntry *leaderboardEntry
	if !inTopList {
		var me models.User
		if err := database.DB.First(&me, "id = ?", userID).Error; err == nil {
			var higherCount int64
			// Mirrors the top list's own "total_points DESC, created_at ASC"
			// ordering exactly — counting only strictly-greater points would
			// disagree with that ordering for anyone tied with users who
			// joined earlier (and therefore rank above them in the top
			// list), understating this rank number.
			if err := database.DB.Model(&models.User{}).
				Where("total_points > ? OR (total_points = ? AND created_at < ?)", me.TotalPoints, me.TotalPoints, me.CreatedAt).
				Count(&higherCount).Error; err == nil {
				yourEntry = &leaderboardEntry{
					UserID:      me.ID,
					Name:        me.Name,
					Avatar:      me.Avatar,
					TotalPoints: me.TotalPoints,
					Badges:      models.GetBadges(me.TotalPoints),
					Rank:        int(higherCount) + 1,
				}
			}
		}
	}

	utils.Success(c, http.StatusOK, "leaderboard fetched", gin.H{
		"top":         top,
		"your_rank":   yourEntry,
		"in_top_list": inTopList,
	})
}
