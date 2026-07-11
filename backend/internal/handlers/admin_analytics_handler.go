package handlers

import (
	"net/http"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AdminAnalyticsHandler struct{}

func NewAdminAnalyticsHandler() *AdminAnalyticsHandler {
	return &AdminAnalyticsHandler{}
}

type carbonCategoryBreakdown struct {
	Category string  `json:"category"`
	CO2Kg    float64 `json:"co2_kg"`
}

// GetCarbonOverview returns platform-wide carbon tracking stats. Every
// number here comes from a DB aggregate (SUM/GROUP BY/COUNT/COUNT DISTINCT)
// — never a full-table load into Go, regardless of how many activities exist.
// GET /api/v1/admin/carbon-overview
func (h *AdminAnalyticsHandler) GetCarbonOverview(c *gin.Context) {
	var totalCO2 float64
	if err := database.DB.Model(&models.CarbonActivity{}).
		Select("COALESCE(SUM(co2_kg), 0)").
		Scan(&totalCO2).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute total CO2", err)
		return
	}

	var breakdown []carbonCategoryBreakdown
	if err := database.DB.Model(&models.CarbonActivity{}).
		Select("category, COALESCE(SUM(co2_kg), 0) as co2_kg").
		Group("category").
		Scan(&breakdown).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute category breakdown", err)
		return
	}

	var totalEntries int64
	if err := database.DB.Model(&models.CarbonActivity{}).Count(&totalEntries).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count log entries", err)
		return
	}

	var activeUserCount int64
	if err := database.DB.Model(&models.CarbonActivity{}).
		Distinct("user_id").
		Count(&activeUserCount).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count active users", err)
		return
	}

	utils.Success(c, http.StatusOK, "carbon overview fetched", gin.H{
		"total_co2_kg":       totalCO2,
		"category_breakdown": breakdown,
		"total_log_entries":  totalEntries,
		"active_user_count":  activeUserCount,
	})
}
