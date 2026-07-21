package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
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
)

// parseLatLon reads and range-validates the 'lat'/'lon' query params shared
// by GetCurrentClimate and GetForecast. Without the range check, an
// out-of-range value (e.g. lat=99999) still parses as a valid float and gets
// forwarded to the weather API and persisted, polluting climate history with
// geographically meaningless coordinates.
func parseLatLon(c *gin.Context) (lat, lon float64, err error) {
	lat, err = strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil || lat < -90 || lat > 90 {
		return 0, 0, errors.New("valid 'lat' query param is required (range -90 to 90)")
	}
	lon, err = strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil || lon < -180 || lon > 180 {
		return 0, 0, errors.New("valid 'lon' query param is required (range -180 to 180)")
	}
	return lat, lon, nil
}

// maxConcurrentAlertChecks bounds how many checkAndSendAlerts goroutines can
// run at once. Without a cap, a burst of requests to GetCurrentClimate (e.g.
// a spike in app opens) would spawn one goroutine per request with no
// upper bound, each holding a DB connection from the pool — a classic
// goroutine-leak-under-load pattern even though each individual goroutine
// does eventually exit.
const maxConcurrentAlertChecks = 50

type ClimateHandler struct {
	weatherService *services.WeatherService
	geminiService  *services.GeminiService
	fcmService     *services.FCMService
	alertSem       chan struct{}
}

func NewClimateHandler(weatherService *services.WeatherService, geminiService *services.GeminiService, fcmService *services.FCMService) *ClimateHandler {
	return &ClimateHandler{
		weatherService: weatherService,
		geminiService:  geminiService,
		fcmService:     fcmService,
		alertSem:       make(chan struct{}, maxConcurrentAlertChecks),
	}
}

// GetCurrentClimate fetches live weather + AQI for a lat/lon, saves it, and returns it.
// GET /api/v1/climate/current?lat=..&lon=..
func (h *ClimateHandler) GetCurrentClimate(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	lat, lon, err := parseLatLon(c)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, err.Error(), err)
		return
	}

	weather, err := h.weatherService.GetCurrentWeather(lat, lon)
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to fetch weather data", err)
		return
	}

	pollution, err := h.weatherService.GetAirPollution(lat, lon)
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to fetch air quality data", err)
		return
	}

	record := models.ClimateData{
		UserID:       userID,
		Latitude:     lat,
		Longitude:    lon,
		LocationName: weather.Name,
		Temperature:  weather.Main.Temp,
		FeelsLike:    weather.Main.FeelsLike,
		Humidity:     weather.Main.Humidity,
		WindSpeed:    weather.Wind.Speed,
		WindDeg:      weather.Wind.Deg,
		Pressure:     weather.Main.Pressure,
		Visibility:   weather.Visibility,
		RainVolume:   weather.Rain.OneHour,
		DewPoint:     calculateDewPoint(weather.Main.Temp, weather.Main.Humidity),
	}

	if len(weather.Weather) > 0 {
		record.WeatherMain = weather.Weather[0].Main
		record.WeatherDesc = weather.Weather[0].Description
		record.WeatherIcon = weather.Weather[0].Icon
	}

	if len(pollution.List) > 0 {
		item := pollution.List[0]
		record.AQI = item.Main.AQI
		record.PM25 = item.Components.PM25
		record.PM10 = item.Components.PM10
		record.CO = item.Components.CO
		record.NO2 = item.Components.NO2
		record.O3 = item.Components.O3
	}

	if err := database.DB.Create(&record).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to save climate data", err)
		return
	}

	// Alert checks (including the FCM push) run in the background so a slow
	// notification dispatch never delays this response, and a panic here can
	// never take down the request-handling goroutine. Bounded by alertSem
	// (see maxConcurrentAlertChecks) rather than spawned unconditionally, so
	// a burst of requests can't pile up an unbounded number of goroutines
	// each holding a DB connection.
	select {
	case h.alertSem <- struct{}{}:
		go func() {
			defer func() { <-h.alertSem }()
			h.checkAndSendAlerts(userID, record)
		}()
	default:
		log.Printf("alert check queue full, skipping background alert check for user %s", userID)
	}

	utils.Success(c, http.StatusOK, "climate data fetched", gin.H{
		"record":    record,
		"aqi_label": record.AQILabel(),
	})
}

// alertCandidate is a threshold breach waiting to be deduped and, if new,
// saved + pushed.
type alertCandidate struct {
	alertType models.AlertType
	severity  string
	title     string
	message   string
}

// checkAndSendAlerts evaluates the just-saved reading against fixed climate
// thresholds and, for each newly-breached one, saves an Alert and pushes a
// notification if the user has a registered device. It never lets a failure
// here propagate to the HTTP response — this always runs after the response
// path has already succeeded (see GetCurrentClimate).
func (h *ClimateHandler) checkAndSendAlerts(userID uuid.UUID, record models.ClimateData) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("recovered from panic while checking climate alerts for user %s: %v", userID, r)
		}
	}()

	var candidates []alertCandidate

	if record.AQI >= 4 {
		candidates = append(candidates, alertCandidate{
			alertType: models.AlertTypePoorAirQuality,
			severity:  "warning",
			title:     "Poor air quality nearby",
			message:   fmt.Sprintf("Air quality is poor (AQI %d) near %s. Consider limiting outdoor activity.", record.AQI, record.LocationName),
		})
	}
	if record.Temperature >= 40 {
		candidates = append(candidates, alertCandidate{
			alertType: models.AlertTypeHeatWave,
			severity:  "danger",
			title:     "Heat wave warning",
			message:   fmt.Sprintf("It's %.0f°C near %s. Stay hydrated and avoid peak sun hours.", record.Temperature, record.LocationName),
		})
	}
	if record.RainVolume > 10 {
		candidates = append(candidates, alertCandidate{
			alertType: models.AlertTypeHeavyRain,
			severity:  "warning",
			title:     "Heavy rain expected",
			message:   fmt.Sprintf("%.1fmm of rain in the last hour near %s. Watch for local flooding.", record.RainVolume, record.LocationName),
		})
	}

	if len(candidates) == 0 {
		return
	}

	// Fetched once up front rather than per-candidate — a single reading can
	// trip more than one threshold (e.g. a heat wave during heavy rain), and
	// the token doesn't change between candidates within this run.
	fcmToken := h.lookupFCMToken(userID)

	for _, candidate := range candidates {
		h.maybeSendAlert(userID, candidate, fcmToken)
	}
}

func (h *ClimateHandler) lookupFCMToken(userID uuid.UUID) string {
	if h.fcmService == nil || !h.fcmService.Enabled() {
		return ""
	}

	var user models.User
	if err := database.DB.Select("fcm_token").First(&user, "id = ?", userID).Error; err != nil {
		log.Printf("failed to load fcm token for user %s: %v", userID, err)
		return ""
	}
	return user.FCMToken
}

// maybeSendAlert skips the candidate if the same alert type already fired for
// this user in the last 3 hours; otherwise it saves the alert and pushes a
// notification (if fcmToken is non-empty). Push failures are logged, not
// propagated — a user should still see the alert in-app even if delivery of
// the push itself fails.
func (h *ClimateHandler) maybeSendAlert(userID uuid.UUID, candidate alertCandidate, fcmToken string) {
	since := time.Now().Add(-3 * time.Hour)

	var count int64
	if err := database.DB.Model(&models.Alert{}).
		Where("user_id = ? AND alert_type = ? AND created_at >= ?", userID, candidate.alertType, since).
		Count(&count).Error; err != nil {
		log.Printf("failed to check recent alerts for user %s: %v", userID, err)
		return
	}
	if count > 0 {
		return
	}

	alert := models.Alert{
		UserID:    userID,
		AlertType: candidate.alertType,
		Severity:  candidate.severity,
		Title:     candidate.title,
		Message:   candidate.message,
	}
	if err := database.DB.Create(&alert).Error; err != nil {
		log.Printf("failed to save alert for user %s: %v", userID, err)
		return
	}

	if fcmToken == "" {
		return
	}

	if err := h.fcmService.SendPushNotification(fcmToken, candidate.title, candidate.message); err != nil {
		log.Printf("failed to push alert notification to user %s: %v", userID, err)
	}
}

// GetClimateHistory returns the authenticated user's recent climate records.
// GET /api/v1/climate/history?limit=20
func (h *ClimateHandler) GetClimateHistory(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	limit, err := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if err != nil || limit <= 0 || limit > 100 {
		limit = 20
	}

	var records []models.ClimateData
	if err := database.DB.
		Where("user_id = ?", userID).
		Order("recorded_at DESC, created_at DESC").
		Limit(limit).
		Find(&records).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch climate history", err)
		return
	}

	utils.Success(c, http.StatusOK, "climate history fetched", records)
}

// GetForecast returns the next N 3-hour forecast slots (default 8 = next 24 hours).
// GET /api/v1/climate/forecast?lat=..&lon=..&count=8
func (h *ClimateHandler) GetForecast(c *gin.Context) {
	lat, lon, err := parseLatLon(c)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, err.Error(), err)
		return
	}

	count, err := strconv.Atoi(c.DefaultQuery("count", "8"))
	if err != nil || count <= 0 || count > 40 {
		count = 8
	}

	forecast, err := h.weatherService.GetForecast(lat, lon)
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to fetch forecast data", err)
		return
	}

	items := forecast.List
	if len(items) > count {
		items = items[:count]
	}

	utils.Success(c, http.StatusOK, "forecast fetched", gin.H{
		"location": forecast.City.Name,
		"items":    items,
	})
}

// SearchLocations resolves a free-text place name to matching lat/lon
// locations worldwide, so the client can fetch weather/forecast for any city.
// GET /api/v1/climate/search?q=tokyo
func (h *ClimateHandler) SearchLocations(c *gin.Context) {
	query := strings.TrimSpace(c.Query("q"))
	if query == "" || len(query) > 100 {
		utils.Fail(c, http.StatusBadRequest, "valid 'q' query param is required", nil)
		return
	}

	results, err := h.weatherService.SearchCity(query)
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to search locations", err)
		return
	}

	utils.Success(c, http.StatusOK, "locations fetched", results)
}

type weatherSummaryResponse struct {
	WeatherSummary     string `json:"weather_summary"`
	ActivitySuggestion string `json:"activity_suggestion"`
	Source             string `json:"source"`
}

// weatherSummaryFields mirrors the JSON object Gemini is instructed to return.
type weatherSummaryFields struct {
	WeatherSummary     string `json:"weather_summary"`
	ActivitySuggestion string `json:"activity_suggestion"`
}

// GetWeatherSummary returns a short AI-generated (or rule-based fallback)
// weather summary and activity suggestion based on the user's most recently
// saved climate reading. It never fails the request — if there's no reading
// yet, or Gemini is unavailable/misconfigured/unparseable, it degrades to a
// deterministic rule-based response instead.
// GET /api/v1/climate/ai-summary
func (h *ClimateHandler) GetWeatherSummary(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var latest models.ClimateData
	if err := database.DB.
		Where("user_id = ?", userID).
		Order("recorded_at DESC, created_at DESC").
		First(&latest).Error; err != nil {
		// A genuine DB error is logged so it isn't indistinguishable from
		// the expected "no reading logged yet" case — the response still
		// degrades gracefully either way, per this endpoint's contract of
		// never failing the request outright.
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			log.Printf("climate: failed to load latest climate data for user %s: %v", userID, err)
		}
		utils.Success(c, http.StatusOK, "weather summary fetched", weatherSummaryResponse{
			WeatherSummary:     "Log your location to get a personalized weather summary.",
			ActivitySuggestion: "Open the dashboard and allow location access to fetch current conditions.",
			Source:             "rule_based",
		})
		return
	}

	summary, suggestion, source := h.buildWeatherSummary(latest)

	utils.Success(c, http.StatusOK, "weather summary fetched", weatherSummaryResponse{
		WeatherSummary:     summary,
		ActivitySuggestion: suggestion,
		Source:             source,
	})
}

// buildWeatherSummary tries Gemini first and falls back to rule-based text on
// any failure, so the AI weather summary never breaks the dashboard.
func (h *ClimateHandler) buildWeatherSummary(data models.ClimateData) (summary, suggestion, source string) {
	if h.geminiService != nil {
		s, a, err := h.generateAIWeatherSummary(data)
		if err == nil {
			return s, a, "ai"
		}
		log.Printf("gemini weather summary failed, falling back to rule-based: %v", err)
	}
	return ruleBasedWeatherSummary(data), ruleBasedActivitySuggestion(data), "rule_based"
}

func (h *ClimateHandler) generateAIWeatherSummary(data models.ClimateData) (string, string, error) {
	text, err := h.geminiService.GenerateInsights(buildWeatherPrompt(data))
	if err != nil {
		return "", "", err
	}

	var fields weatherSummaryFields
	if err := json.Unmarshal([]byte(extractJSONObject(text)), &fields); err != nil {
		return "", "", fmt.Errorf("failed to parse gemini response: %w", err)
	}
	if fields.WeatherSummary == "" || fields.ActivitySuggestion == "" {
		return "", "", fmt.Errorf("gemini returned an incomplete weather summary")
	}
	return fields.WeatherSummary, fields.ActivitySuggestion, nil
}

// extractJSONObject pulls the outermost {...} out of a model reply, since
// Gemini sometimes wraps JSON in markdown code fences or adds commentary
// despite being instructed not to.
func extractJSONObject(text string) string {
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")
	if start == -1 || end == -1 || end < start {
		return text
	}
	return text[start : end+1]
}

func buildWeatherPrompt(data models.ClimateData) string {
	description := data.WeatherDesc
	if description == "" {
		description = data.WeatherMain
	}

	return fmt.Sprintf(`You are a friendly weather assistant inside a climate-tracking app. Based on this current weather reading:
- Temperature: %.1f°C (feels like %.1f°C)
- Conditions: %s
- Humidity: %d%%
- Wind speed: %.1f km/h
- Air quality index (1-5, higher is worse): %d
- PM2.5: %.1f µg/m³

Return ONLY a JSON object (no markdown, no code fences, no extra text) with exactly these keys:
"weather_summary" (1 friendly sentence describing the current weather),
"activity_suggestion" (1 actionable sentence about whether it's a good time for outdoor activity, considering air quality).`,
		data.Temperature, data.FeelsLike, description, data.Humidity, data.WindSpeed, data.AQI, data.PM25,
	)
}

// ruleBasedWeatherSummary is the deterministic fallback used whenever Gemini
// is unavailable, misconfigured, or returns something unparseable.
func ruleBasedWeatherSummary(data models.ClimateData) string {
	description := data.WeatherDesc
	if description == "" {
		description = "clear skies"
	}
	return fmt.Sprintf("It's %.0f°C with %s right now, feeling like %.0f°C.", data.Temperature, description, data.FeelsLike)
}

func ruleBasedActivitySuggestion(data models.ClimateData) string {
	if data.AQI >= 4 {
		return "Air quality is poor today. Consider wearing a mask outdoors and keeping windows closed."
	}
	if data.Temperature >= 35 {
		return "It's quite hot today. Stay hydrated and avoid peak sun hours between 12–3 PM."
	}
	return "Conditions look good today — a great day to walk or cycle instead of driving."
}

// calculateDewPoint uses the Magnus formula to estimate dew point (°C)
// from temperature (°C) and relative humidity (%).
func calculateDewPoint(tempC float64, humidity int) float64 {
	const a = 17.27
	const b = 237.7
	rh := float64(humidity)
	if rh <= 0 {
		rh = 1
	}
	// Guards two divisions from ever going by zero (an anomalous upstream
	// reading of exactly -237.7°C, or an alpha that happens to equal a) —
	// either would otherwise produce Inf/NaN, which gets persisted and then
	// breaks JSON marshaling of every later read of this record.
	if b+tempC == 0 {
		return 0
	}
	alpha := ((a * tempC) / (b + tempC)) + math.Log(rh/100)
	if a-alpha == 0 || math.IsNaN(alpha) {
		return 0
	}
	dewPoint := (b * alpha) / (a - alpha)
	if math.IsInf(dewPoint, 0) || math.IsNaN(dewPoint) {
		return 0
	}
	return dewPoint
}
