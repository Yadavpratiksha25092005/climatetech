package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"net/http"
	"strings"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// benchmarkDailyKg is an indicative average daily personal CO2 footprint
// (across the categories this app tracks) used only to scale the 0-100 eco
// score — not an authoritative emissions-accounting figure.
const benchmarkDailyKg = 6.0

type InsightsHandler struct {
	geminiService *services.GeminiService
}

func NewInsightsHandler(geminiService *services.GeminiService) *InsightsHandler {
	return &InsightsHandler{geminiService: geminiService}
}

type recommendation struct {
	IconHint string `json:"icon_hint"`
	Title    string `json:"title"`
	Message  string `json:"message"`
}

type insightsResponse struct {
	Score              int              `json:"score"`
	WeeklyCO2Kg        float64          `json:"weekly_co2_kg"`
	WeeklyTrendPercent float64          `json:"weekly_trend_percent"`
	MonthlyProjectedKg float64          `json:"monthly_projected_kg"`
	HighestCategory    string           `json:"highest_category"`
	AQI                int              `json:"aqi"`
	Temperature        float64          `json:"temperature"`
	Recommendations    []recommendation `json:"recommendations"`
	Source             string           `json:"source"`
}

// insightContext bundles the computed metrics that both the rule-based
// fallback and the Gemini prompt build their recommendations from.
type insightContext struct {
	Score           int
	WeeklyCO2Kg     float64
	TrendPercent    float64
	ProjectedKg     float64
	HighestCategory string
	AQI             int
	Temperature     float64
}

// GetInsights computes an eco score, weekly trend, monthly projection, and
// highest-emission category from the user's carbon activity, then attaches
// 3-4 recommendations — AI-generated via Gemini when available, otherwise a
// rule-based fallback so the feature never breaks.
// GET /api/v1/insights
func (h *InsightsHandler) GetInsights(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	startOfWeek := startOfDay.AddDate(0, 0, -int(now.Weekday()))
	startOfPrevWeek := startOfWeek.AddDate(0, 0, -7)
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	weekTotal, err := co2TotalSince(userID, startOfWeek)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute weekly total", err)
		return
	}
	prevWeekTotal, err := co2TotalBetween(userID, startOfPrevWeek, startOfWeek)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute previous week's total", err)
		return
	}
	monthTotal, err := co2TotalSince(userID, startOfMonth)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute monthly total", err)
		return
	}
	breakdown, err := categoryTotalsSince(userID, startOfMonth)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute category breakdown", err)
		return
	}

	daysElapsed := now.Day()
	daysInMonth := time.Date(now.Year(), now.Month()+1, 0, 0, 0, 0, 0, now.Location()).Day()
	var avgDaily, projected float64
	if daysElapsed > 0 {
		avgDaily = monthTotal / float64(daysElapsed)
		projected = avgDaily * float64(daysInMonth)
	}

	var trendPercent float64
	if prevWeekTotal > 0 {
		trendPercent = ((weekTotal - prevWeekTotal) / prevWeekTotal) * 100
	}

	var highestCategory string
	if len(breakdown) > 0 {
		top := breakdown[0]
		for _, b := range breakdown[1:] {
			if b.CO2Kg > top.CO2Kg {
				top = b
			}
		}
		highestCategory = top.Category
	}

	score := computeEcoScore(avgDaily)

	var latestClimate models.ClimateData
	var aqi int
	var temperature float64
	if err := database.DB.
		Where("user_id = ?", userID).
		Order("recorded_at DESC, created_at DESC").
		First(&latestClimate).Error; err == nil {
		aqi = latestClimate.AQI
		temperature = latestClimate.Temperature
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		// A user with no climate data logged yet is expected and fine to
		// default to 0; a real DB error here shouldn't silently vanish into
		// the same "0" — the rest of the response is still useful, so this
		// is logged rather than failing the whole insights request over one
		// secondary field.
		log.Printf("insights: failed to load latest climate data for user %s: %v", userID, err)
	}

	ctx := insightContext{
		Score:           score,
		WeeklyCO2Kg:     weekTotal,
		TrendPercent:    trendPercent,
		ProjectedKg:     projected,
		HighestCategory: highestCategory,
		AQI:             aqi,
		Temperature:     temperature,
	}

	recommendations, source := h.buildRecommendations(ctx)

	utils.Success(c, http.StatusOK, "insights fetched", insightsResponse{
		Score:              score,
		WeeklyCO2Kg:        weekTotal,
		WeeklyTrendPercent: trendPercent,
		MonthlyProjectedKg: projected,
		HighestCategory:    highestCategory,
		AQI:                aqi,
		Temperature:        temperature,
		Recommendations:    recommendations,
		Source:             source,
	})
}

func co2TotalSince(userID uuid.UUID, since time.Time) (float64, error) {
	var total float64
	err := database.DB.Model(&models.CarbonActivity{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("COALESCE(SUM(co2_kg), 0)").
		Scan(&total).Error
	return total, err
}

func co2TotalBetween(userID uuid.UUID, from, to time.Time) (float64, error) {
	var total float64
	err := database.DB.Model(&models.CarbonActivity{}).
		Where("user_id = ? AND recorded_at >= ? AND recorded_at < ?", userID, from, to).
		Select("COALESCE(SUM(co2_kg), 0)").
		Scan(&total).Error
	return total, err
}

func categoryTotalsSince(userID uuid.UUID, since time.Time) ([]categoryTotal, error) {
	var results []categoryTotal
	err := database.DB.Model(&models.CarbonActivity{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("category, COALESCE(SUM(co2_kg), 0) as co2_kg").
		Group("category").
		Scan(&results).Error
	return results, err
}

// computeEcoScore scales a user's average daily CO2 (kg) against an
// indicative benchmark into a 0-100 score, where lower emissions score higher.
func computeEcoScore(avgDailyKg float64) int {
	if avgDailyKg <= 0 {
		return 100
	}
	ratio := avgDailyKg / benchmarkDailyKg
	score := 100 - (ratio * 50)
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	return int(math.Round(score))
}

// buildRecommendations tries Gemini first and falls back to rule-based tips
// on any failure, so the insights feature never breaks.
func (h *InsightsHandler) buildRecommendations(ctx insightContext) ([]recommendation, string) {
	if h.geminiService != nil {
		recs, err := h.generateAIRecommendations(ctx)
		if err == nil && len(recs) > 0 {
			return recs, "ai"
		}
		if err != nil {
			log.Printf("gemini insights generation failed, falling back to rule-based: %v", err)
		}
	}
	return ruleBasedRecommendations(ctx), "rule_based"
}

func (h *InsightsHandler) generateAIRecommendations(ctx insightContext) ([]recommendation, error) {
	text, err := h.geminiService.GenerateInsights(buildGeminiPrompt(ctx))
	if err != nil {
		return nil, err
	}

	var recs []recommendation
	if err := json.Unmarshal([]byte(extractJSONArray(text)), &recs); err != nil {
		return nil, fmt.Errorf("failed to parse gemini response: %w", err)
	}
	if len(recs) == 0 {
		return nil, fmt.Errorf("gemini returned no recommendations")
	}
	return recs, nil
}

// extractJSONArray pulls the outermost [...] out of a model reply, since
// Gemini sometimes wraps JSON in markdown code fences or adds commentary
// despite being instructed not to.
func extractJSONArray(text string) string {
	start := strings.Index(text, "[")
	end := strings.LastIndex(text, "]")
	if start == -1 || end == -1 || end < start {
		return text
	}
	return text[start : end+1]
}

func buildGeminiPrompt(ctx insightContext) string {
	trendDirection := "flat"
	if ctx.TrendPercent > 1 {
		trendDirection = "up"
	} else if ctx.TrendPercent < -1 {
		trendDirection = "down"
	}

	category := ctx.HighestCategory
	if category == "" {
		category = "none logged yet"
	}

	return fmt.Sprintf(`You are a friendly climate coach inside a carbon-footprint tracking app. Based on this user's data:
- Eco score: %d/100 (higher is better, lower emissions)
- This week's CO2: %.1f kg, trending %s (%.1f%% vs last week)
- Projected CO2 for this month: %.1f kg
- Highest-emission category this month: %s
- Current local air quality index (1-5, higher is worse): %d
- Current temperature: %.1f°C

Return ONLY a JSON array (no markdown, no code fences, no extra text) of 3-4 objects, each with exactly these keys:
"icon_hint" (one of: air, transport, electricity, food, trend_up, trend_down, start, water, waste),
"title" (a short 2-5 word heading),
"message" (1-2 warm, specific, actionable sentences).
Tailor the recommendations to the data above — reference the highest-emission category, the trend direction, and air quality/temperature where relevant.`,
		ctx.Score, ctx.WeeklyCO2Kg, trendDirection, ctx.TrendPercent, ctx.ProjectedKg, category, ctx.AQI, ctx.Temperature,
	)
}

// ruleBasedRecommendations is the deterministic fallback used whenever Gemini
// is unavailable, misconfigured, or returns something unparseable.
func ruleBasedRecommendations(ctx insightContext) []recommendation {
	if ctx.HighestCategory == "" {
		return []recommendation{{
			IconHint: "start",
			Title:    "Log your first activity",
			Message:  "Start tracking your daily activities — transportation, electricity, food — to get a personalized footprint score and tips.",
		}}
	}

	recs := []recommendation{{
		IconHint: categoryIconHint(ctx.HighestCategory),
		Title:    fmt.Sprintf("Cut back on %s", ctx.HighestCategory),
		Message:  categoryTip(ctx.HighestCategory),
	}}

	if ctx.TrendPercent > 5 {
		recs = append(recs, recommendation{
			IconHint: "trend_up",
			Title:    "Emissions trending up",
			Message: fmt.Sprintf(
				"Your footprint is up %.0f%% versus last week. Small swaps — walking short trips, batch-cooking — can bring it back down.",
				ctx.TrendPercent,
			),
		})
	} else if ctx.TrendPercent < -5 {
		recs = append(recs, recommendation{
			IconHint: "trend_down",
			Title:    "Great progress this week",
			Message: fmt.Sprintf(
				"You cut emissions by %.0f%% versus last week. Keep the momentum going!",
				-ctx.TrendPercent,
			),
		})
	}

	if ctx.AQI >= 4 {
		recs = append(recs, recommendation{
			IconHint: "air",
			Title:    "Air quality is poor",
			Message:  "Consider wearing a mask outdoors and keeping windows closed until air quality improves.",
		})
	}

	if ctx.ProjectedKg > 0 {
		recs = append(recs, recommendation{
			IconHint: "trend_up",
			Title:    "Monthly projection",
			Message: fmt.Sprintf(
				"At your current pace, you're on track for about %.0f kg CO2 this month. Small daily changes compound fast.",
				ctx.ProjectedKg,
			),
		})
	}

	if len(recs) > 4 {
		recs = recs[:4]
	}
	return recs
}

func categoryIconHint(category string) string {
	switch category {
	case "transportation", "fuel":
		return "transport"
	case "electricity":
		return "electricity"
	case "food":
		return "food"
	case "water":
		return "water"
	case "waste":
		return "waste"
	default:
		return "start"
	}
}

func categoryTip(category string) string {
	switch category {
	case "transportation":
		return "Try carpooling, cycling, or public transit for short trips — transportation is your biggest source this month."
	case "electricity":
		return "Switch off idle appliances and swap in LED bulbs where you can — electricity use is driving your footprint this month."
	case "fuel":
		return "Combine errands into fewer trips to cut down on driving — fuel is your top emission source this month."
	case "food":
		return "Try a plant-forward meal a few times a week — food choices are your biggest emission source this month."
	case "waste":
		return "Composting food scraps and recycling more can make a real dent — waste is your top contributor this month."
	case "water":
		return "Shorter showers and fixing leaks can help reduce hot water use — it's your biggest source this month."
	default:
		return "Keep logging your activities — personalized tips will appear once we see a pattern."
	}
}
