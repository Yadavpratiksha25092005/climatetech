package handlers

import (
	"math"
	"net/http"
	"strconv"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CarbonHandler struct{}

func NewCarbonHandler() *CarbonHandler {
	return &CarbonHandler{}
}

type logActivityRequest struct {
	Category string  `json:"category" binding:"required,max=30"`
	SubType  string  `json:"sub_type" binding:"required,max=100"`
	Quantity float64 `json:"quantity" binding:"required,gt=0,lte=1000000"`
	Notes    string  `json:"notes" binding:"omitempty,max=2000"`
}

// LogActivity validates the category/sub_type combo, computes CO2 emissions,
// and saves the activity for the authenticated user.
// POST /api/v1/carbon/log
func (h *CarbonHandler) LogActivity(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req logActivityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	category := models.ActivityCategory(req.Category)
	co2Kg, unit, found, err := services.CalculateEmission(category, req.SubType, req.Quantity)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid category", err)
		return
	}

	// A finite, in-range Quantity can still yield a non-finite CO2Kg if the
	// emission factor itself is degenerate — belt-and-suspenders guard, since
	// Postgres can store Infinity/NaN but encoding/json cannot marshal it,
	// which would otherwise silently corrupt every later read of this record
	// (history, summary, insights, reports all aggregate CO2Kg).
	if math.IsInf(co2Kg, 0) || math.IsNaN(co2Kg) {
		utils.Fail(c, http.StatusBadRequest, "quantity out of range", nil)
		return
	}

	notes := req.Notes
	if !found {
		const customNote = "Emission factor not available for this custom entry."
		if notes == "" {
			notes = customNote
		} else {
			notes = notes + " " + customNote
		}
	}

	record := models.CarbonActivity{
		UserID:   userID,
		Category: category,
		SubType:  req.SubType,
		Quantity: req.Quantity,
		Unit:     unit,
		CO2Kg:    co2Kg,
		IsCustom: !found,
		Notes:    notes,
	}

	if err := database.DB.Create(&record).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to save activity", err)
		return
	}

	utils.Success(c, http.StatusCreated, "activity logged", record)
}

// GetHistory returns the authenticated user's recent carbon activities, newest first.
// GET /api/v1/carbon/history?limit=50
func (h *CarbonHandler) GetHistory(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	limit, err := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if err != nil || limit <= 0 || limit > 200 {
		limit = 50
	}

	var records []models.CarbonActivity
	if err := database.DB.
		Where("user_id = ?", userID).
		Order("recorded_at DESC, created_at DESC").
		Limit(limit).
		Find(&records).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch carbon history", err)
		return
	}

	utils.Success(c, http.StatusOK, "carbon history fetched", records)
}

type categoryTotal struct {
	Category string  `json:"category"`
	CO2Kg    float64 `json:"co2_kg"`
}

// GetSummary returns today/this-week/this-month/this-year CO2 totals for the
// authenticated user, plus a per-category breakdown for the current month.
// GET /api/v1/carbon/summary
func (h *CarbonHandler) GetSummary(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	startOfWeek := startOfDay.AddDate(0, 0, -int(now.Weekday()))
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	startOfYear := time.Date(now.Year(), 1, 1, 0, 0, 0, 0, now.Location())

	today, err := h.sumSince(userID, startOfDay)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute today's total", err)
		return
	}
	week, err := h.sumSince(userID, startOfWeek)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute this week's total", err)
		return
	}
	month, err := h.sumSince(userID, startOfMonth)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute this month's total", err)
		return
	}
	year, err := h.sumSince(userID, startOfYear)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute this year's total", err)
		return
	}

	breakdown, err := h.categoryBreakdown(userID, startOfMonth)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute category breakdown", err)
		return
	}

	utils.Success(c, http.StatusOK, "carbon summary fetched", gin.H{
		"today_kg":          today,
		"this_week_kg":      week,
		"this_month_kg":     month,
		"this_year_kg":      year,
		"month_by_category": breakdown,
	})
}

func (h *CarbonHandler) sumSince(userID uuid.UUID, since time.Time) (float64, error) {
	var total float64
	err := database.DB.Model(&models.CarbonActivity{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("COALESCE(SUM(co2_kg), 0)").
		Scan(&total).Error
	return total, err
}

func (h *CarbonHandler) categoryBreakdown(userID uuid.UUID, since time.Time) ([]categoryTotal, error) {
	var results []categoryTotal
	err := database.DB.Model(&models.CarbonActivity{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("category, COALESCE(SUM(co2_kg), 0) as co2_kg").
		Group("category").
		Scan(&results).Error
	return results, err
}

type dailyRow struct {
	Day   time.Time `gorm:"column:day"`
	Total float64   `gorm:"column:total_kg"`
}

type dailyTotal struct {
	Date    string  `json:"date"`
	TotalKg float64 `json:"total_kg"`
}

// GetDailyBreakdown returns the authenticated user's CO2 totals for each of the
// last N days (default 7, max 90), oldest first, filling 0 for days with no
// logged activity.
// GET /api/v1/carbon/daily?days=7
func (h *CarbonHandler) GetDailyBreakdown(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	days, err := strconv.Atoi(c.DefaultQuery("days", "7"))
	if err != nil || days <= 0 || days > 90 {
		days = 7
	}

	// Both the DB-side bucketing and the Go-side zero-fill below must agree
	// on a single timezone — DATE(recorded_at) buckets by whatever timezone
	// the DB session happens to be in, so it's pinned to UTC explicitly here
	// to match the UTC-based keys generated below, rather than relying on
	// the DB session's timezone matching the Go server's local timezone.
	now := time.Now().UTC()
	startDate := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -(days - 1))

	var rows []dailyRow
	if err := database.DB.Model(&models.CarbonActivity{}).
		Select("DATE(recorded_at AT TIME ZONE 'UTC') as day, COALESCE(SUM(co2_kg), 0) as total_kg").
		Where("user_id = ? AND recorded_at >= ?", userID, startDate).
		Group("DATE(recorded_at AT TIME ZONE 'UTC')").
		Scan(&rows).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute daily breakdown", err)
		return
	}

	totalsByDate := make(map[string]float64, len(rows))
	for _, r := range rows {
		totalsByDate[r.Day.Format("2006-01-02")] = r.Total
	}

	breakdown := make([]dailyTotal, 0, days)
	for i := 0; i < days; i++ {
		key := startDate.AddDate(0, 0, i).Format("2006-01-02")
		breakdown = append(breakdown, dailyTotal{Date: key, TotalKg: totalsByDate[key]})
	}

	utils.Success(c, http.StatusOK, "daily breakdown fetched", breakdown)
}

// GetOptions returns the available sub-types (with units) for every activity
// category, so the frontend can build category/sub-type dropdowns dynamically.
// GET /api/v1/carbon/options
func (h *CarbonHandler) GetOptions(c *gin.Context) {
	options := make(map[models.ActivityCategory][]services.EmissionFactor)
	for _, category := range services.AllCategories() {
		options[category] = services.AvailableSubTypes(category)
	}
	utils.Success(c, http.StatusOK, "carbon options fetched", options)
}
