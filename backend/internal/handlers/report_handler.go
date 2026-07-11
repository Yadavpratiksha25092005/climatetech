package handlers

import (
	"bytes"
	"database/sql"
	"fmt"
	"net/http"
	"strings"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jung-kurt/gofpdf"
)

type ReportHandler struct{}

func NewReportHandler() *ReportHandler {
	return &ReportHandler{}
}

type reportData struct {
	UserName                      string
	PeriodLabel                   string
	RangeStart                    time.Time
	RangeEnd                      time.Time
	TotalCO2Kg                    float64
	CategoryBreakdown             []categoryTotal
	AvgTemperatureC               float64
	HasClimateData                bool
	AQILabel                      string
	AlertCount                    int64
	PointsEarnedThisPeriod        int
	BadgesEarnedThisPeriod        []string
	ChallengesCompletedThisPeriod int64
	GeneratedAt                   time.Time
}

// GenerateReport builds a single-page PDF combining the authenticated user's
// carbon footprint, climate, and achievement data for the requested period
// and streams it back as a downloadable attachment.
// GET /api/v1/reports/generate?period=week|month
func (h *ReportHandler) GenerateReport(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	period := c.DefaultQuery("period", "week")
	if period != "week" && period != "month" {
		period = "week"
	}

	now := time.Now()
	var rangeStart time.Time
	var periodLabel string
	if period == "month" {
		rangeStart = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
		periodLabel = "This Month"
	} else {
		startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
		rangeStart = startOfDay.AddDate(0, 0, -int(now.Weekday()))
		periodLabel = "This Week"
	}

	var user models.User
	if err := database.DB.First(&user, "id = ?", userID).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch user", err)
		return
	}

	totalCO2, err := co2TotalSince(userID, rangeStart)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute carbon total", err)
		return
	}
	breakdown, err := categoryTotalsSince(userID, rangeStart)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute carbon breakdown", err)
		return
	}

	climateSummary, err := summarizeClimateSince(userID, rangeStart)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch climate history", err)
		return
	}

	var alertCount int64
	if err := database.DB.Model(&models.Alert{}).
		Where("user_id = ? AND created_at >= ?", userID, rangeStart).
		Count(&alertCount).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count alerts", err)
		return
	}

	var pointsEarnedThisPeriod int
	if err := database.DB.Model(&models.ChallengeCheckInLog{}).
		Where("user_id = ? AND checked_in_at >= ?", userID, rangeStart).
		Select("COALESCE(SUM(points_awarded), 0)").
		Scan(&pointsEarnedThisPeriod).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute points earned this period", err)
		return
	}

	var challengesCompletedThisPeriod int64
	if err := database.DB.Model(&models.UserChallenge{}).
		Where("user_id = ? AND status = ? AND last_check_in_date >= ?", userID, models.UserChallengeStatusCompleted, rangeStart).
		Count(&challengesCompletedThisPeriod).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count challenges completed this period", err)
		return
	}

	// Badges "earned this period" are whichever thresholds the user crossed
	// during the window — derived by diffing GetBadges at the user's points
	// as of the start of the period against their current points, rather
	// than falling back to the all-time badge list.
	startOfPeriodPoints := user.TotalPoints - pointsEarnedThisPeriod
	if startOfPeriodPoints < 0 {
		startOfPeriodPoints = 0
	}
	badgesEarnedThisPeriod := newlyUnlockedBadges(startOfPeriodPoints, user.TotalPoints)

	pdfBytes, err := buildReportPDF(reportData{
		UserName:                      user.Name,
		PeriodLabel:                   periodLabel,
		RangeStart:                    rangeStart,
		RangeEnd:                      now,
		TotalCO2Kg:                    totalCO2,
		CategoryBreakdown:             breakdown,
		AvgTemperatureC:               climateSummary.AvgTemperature,
		HasClimateData:                climateSummary.HasData,
		AQILabel:                      climateSummary.AQILabel,
		AlertCount:                    alertCount,
		PointsEarnedThisPeriod:        pointsEarnedThisPeriod,
		BadgesEarnedThisPeriod:        badgesEarnedThisPeriod,
		ChallengesCompletedThisPeriod: challengesCompletedThisPeriod,
		GeneratedAt:                   now,
	})
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to generate report", err)
		return
	}

	filename := fmt.Sprintf("climatetech-report-%s.pdf", now.Format("2006-01-02"))
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filename))
	c.Data(http.StatusOK, "application/pdf", pdfBytes)
}

type climateSummary struct {
	AvgTemperature float64
	AQILabel       string
	HasData        bool
}

// summarizeClimateSince computes the average temperature and the most
// frequently recorded AQI label for a user's climate readings since a given
// time, entirely via SQL aggregates (AVG, COUNT/GROUP BY) rather than
// fetching every row into Go just to average/tally it in application code —
// this was previously an unbounded Find() that loaded the whole period's
// climate history for a single average calculation.
func summarizeClimateSince(userID uuid.UUID, since time.Time) (climateSummary, error) {
	var avgResult struct {
		AvgTemp sql.NullFloat64
		Count   int64
	}
	if err := database.DB.Model(&models.ClimateData{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("AVG(temperature) as avg_temp, COUNT(*) as count").
		Scan(&avgResult).Error; err != nil {
		return climateSummary{}, err
	}

	if avgResult.Count == 0 {
		return climateSummary{AQILabel: "No data", HasData: false}, nil
	}

	var mostFrequentAQI int
	if err := database.DB.Model(&models.ClimateData{}).
		Where("user_id = ? AND recorded_at >= ?", userID, since).
		Select("aqi").
		Group("aqi").
		Order("COUNT(*) DESC").
		Limit(1).
		Scan(&mostFrequentAQI).Error; err != nil {
		return climateSummary{}, err
	}

	label := (&models.ClimateData{AQI: mostFrequentAQI}).AQILabel()
	return climateSummary{
		AvgTemperature: avgResult.AvgTemp.Float64,
		AQILabel:       label,
		HasData:        true,
	}, nil
}

// newlyUnlockedBadges returns the badges present at currentPoints but not
// yet present at startPoints — i.e. the ones actually crossed/unlocked
// during the period, rather than the full all-time badge list.
func newlyUnlockedBadges(startPoints, currentPoints int) []string {
	hadAtStart := make(map[string]bool)
	for _, b := range models.GetBadges(startPoints) {
		hadAtStart[b] = true
	}

	newBadges := make([]string, 0)
	for _, b := range models.GetBadges(currentPoints) {
		if !hadAtStart[b] {
			newBadges = append(newBadges, b)
		}
	}
	return newBadges
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	// Rune-aware, not byte-aware — a byte slice (s[:1]) would split a
	// multi-byte UTF-8 leading character and corrupt it.
	r := []rune(s)
	return strings.ToUpper(string(r[0])) + string(r[1:])
}

// buildReportPDF renders the report as a single-page A4 PDF and returns the
// raw bytes — no temp files are created, so there is nothing to clean up.
func buildReportPDF(data reportData) ([]byte, error) {
	pdf := gofpdf.New("P", "mm", "A4", "")
	pdf.SetTitle("ClimateTech Report", false)
	tr := pdf.UnicodeTranslatorFromDescriptor("")

	pdf.SetFooterFunc(func() {
		pdf.SetY(-15)
		pdf.SetFont("Arial", "I", 8)
		pdf.SetTextColor(120, 120, 120)
		pdf.CellFormat(0, 10, tr(fmt.Sprintf("Generated on %s", data.GeneratedAt.Format("Jan 2, 2006 15:04"))), "", 0, "C", false, 0, "")
	})

	pdf.AddPage()

	pdf.SetFont("Arial", "B", 20)
	pdf.SetTextColor(20, 110, 80)
	pdf.CellFormat(0, 10, "ClimateTech Report", "", 1, "L", false, 0, "")

	pdf.SetTextColor(0, 0, 0)
	pdf.SetFont("Arial", "", 11)
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Prepared for: %s", data.UserName)), "", 1, "L", false, 0, "")
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Period: %s (%s - %s)", data.PeriodLabel, data.RangeStart.Format("Jan 2, 2006"), data.RangeEnd.Format("Jan 2, 2006"))), "", 1, "L", false, 0, "")
	pdf.Ln(6)

	sectionTitle := func(title string) {
		pdf.SetFont("Arial", "B", 14)
		pdf.SetTextColor(20, 110, 80)
		pdf.CellFormat(0, 9, title, "", 1, "L", false, 0, "")
		pdf.SetTextColor(0, 0, 0)
		pdf.Ln(1)
	}

	// Carbon Footprint
	sectionTitle("Carbon Footprint")
	pdf.SetFont("Arial", "", 11)
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Total CO2 emitted: %.2f kg", data.TotalCO2Kg)), "", 1, "L", false, 0, "")
	pdf.Ln(2)

	if len(data.CategoryBreakdown) > 0 {
		pdf.SetFont("Arial", "B", 10)
		pdf.CellFormat(90, 7, "Category", "1", 0, "L", false, 0, "")
		pdf.CellFormat(40, 7, "CO2 (kg)", "1", 1, "R", false, 0, "")
		pdf.SetFont("Arial", "", 10)
		for _, row := range data.CategoryBreakdown {
			pdf.CellFormat(90, 7, tr(capitalize(row.Category)), "1", 0, "L", false, 0, "")
			pdf.CellFormat(40, 7, fmt.Sprintf("%.2f", row.CO2Kg), "1", 1, "R", false, 0, "")
		}
	} else {
		pdf.SetFont("Arial", "I", 10)
		pdf.CellFormat(0, 7, "No carbon activity logged in this period.", "", 1, "L", false, 0, "")
	}
	pdf.Ln(8)

	// Climate Summary
	sectionTitle("Climate Summary")
	pdf.SetFont("Arial", "", 11)
	if data.HasClimateData {
		pdf.CellFormat(0, 7, tr(fmt.Sprintf("Average temperature: %.1f°C", data.AvgTemperatureC)), "", 1, "L", false, 0, "")
		pdf.CellFormat(0, 7, tr(fmt.Sprintf("Most frequent air quality: %s", data.AQILabel)), "", 1, "L", false, 0, "")
	} else {
		pdf.SetFont("Arial", "I", 10)
		pdf.CellFormat(0, 7, "No climate readings recorded in this period.", "", 1, "L", false, 0, "")
		pdf.SetFont("Arial", "", 11)
	}
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Climate alerts triggered: %d", data.AlertCount)), "", 1, "L", false, 0, "")
	pdf.Ln(8)

	// Achievements (all period-scoped, not lifetime totals)
	sectionTitle("Achievements")
	pdf.SetFont("Arial", "", 11)
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Points earned this period: %d", data.PointsEarnedThisPeriod)), "", 1, "L", false, 0, "")
	pdf.CellFormat(0, 7, tr(fmt.Sprintf("Challenges completed this period: %d", data.ChallengesCompletedThisPeriod)), "", 1, "L", false, 0, "")
	if len(data.BadgesEarnedThisPeriod) > 0 {
		pdf.CellFormat(0, 7, tr(fmt.Sprintf("Badges earned this period: %s", strings.Join(data.BadgesEarnedThisPeriod, ", "))), "", 1, "L", false, 0, "")
	} else {
		pdf.SetFont("Arial", "I", 11)
		pdf.CellFormat(0, 7, "Badges earned this period: none", "", 1, "L", false, 0, "")
	}

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
