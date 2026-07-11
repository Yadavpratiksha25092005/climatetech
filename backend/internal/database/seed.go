package database

import (
	"fmt"

	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"

	"gorm.io/gorm"
)

// seedChallenges inserts the 5 default community challenges if the table is
// empty, so a fresh environment always has something to join. The benefit
// text is computed from this app's own emission factors (see
// emission_service.go) rather than hardcoded, so it stays consistent if
// those factors are ever tuned.
func seedChallenges(db *gorm.DB) error {
	var count int64
	if err := db.Model(&models.Challenge{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	carPetrolFactor := factorFor(models.CategoryTransportation, "car_petrol")
	gridFactor := factorFor(models.CategoryElectricity, "grid")
	tapWaterFactor := factorFor(models.CategoryWater, "tap_water")
	landfillFactor := factorFor(models.CategoryWaste, "landfill")

	defaults := []models.Challenge{
		{
			Title:       "Plant a Tree",
			Description: "Plant a sapling and tend to it for a few days.",
			BenefitInfo: "A young tree can absorb roughly 21 kg of CO2 per year once established — one of the simplest lasting climate actions there is.",
			Category:    "environment",
			IconHint:    "park",
			// A short, high-value challenge rather than a week-long habit —
			// planting + a couple of days of care is the realistic loop here.
			PointsPerCheckIn: 20,
			DurationDays:     3,
			IsActive:         true,
		},
		{
			Title:            "No Plastic Week",
			Description:      "Avoid single-use plastic for a full week.",
			BenefitInfo:      fmt.Sprintf("Diverting waste from landfill instead of single-use plastic saves about %.2f kg of CO2 per kg diverted, based on this app's own waste emission factors.", landfillFactor),
			Category:         "waste",
			IconHint:         "recycle",
			PointsPerCheckIn: 10,
			DurationDays:     7,
			IsActive:         true,
		},
		{
			Title:            "Cycle to Work",
			Description:      "Swap a car commute for cycling.",
			BenefitInfo:      fmt.Sprintf("Cycling instead of driving a petrol car saves about %.3f kg of CO2 per kilometer, based on this app's own transportation emission factors.", carPetrolFactor),
			Category:         "transportation",
			IconHint:         "bike",
			PointsPerCheckIn: 10,
			DurationDays:     7,
			IsActive:         true,
		},
		{
			Title:            "Save Electricity",
			Description:      "Cut your electricity use for a week.",
			BenefitInfo:      fmt.Sprintf("Every kWh you don't draw from the grid saves about %.3f kg of CO2, based on this app's own electricity emission factors.", gridFactor),
			Category:         "electricity",
			IconHint:         "bolt",
			PointsPerCheckIn: 10,
			DurationDays:     7,
			IsActive:         true,
		},
		{
			Title:            "Water Conservation",
			Description:      "Reduce your water usage for a week.",
			BenefitInfo:      fmt.Sprintf("Every cubic meter of water you conserve saves about %.3f kg of CO2 from treatment and pumping, based on this app's own water emission factors.", tapWaterFactor),
			Category:         "water",
			IconHint:         "water_drop",
			PointsPerCheckIn: 10,
			DurationDays:     7,
			IsActive:         true,
		},
	}

	return db.Create(&defaults).Error
}

func factorFor(category models.ActivityCategory, subType string) float64 {
	for _, f := range services.AvailableSubTypes(category) {
		if f.SubType == subType {
			return f.Factor
		}
	}
	return 0
}
