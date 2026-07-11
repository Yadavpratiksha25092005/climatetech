package services

import (
	"fmt"

	"climatetech-backend/internal/models"
)

// EmissionFactor describes one loggable sub-type within a category: the unit
// the user enters a quantity in, and the kg CO2 emitted per unit of that quantity.
type EmissionFactor struct {
	SubType string  `json:"sub_type"`
	Unit    string  `json:"unit"`
	Factor  float64 `json:"factor_kg_co2_per_unit"`
}

// emissionFactors holds indicative kg-CO2-per-unit figures for each category's
// sub-types. These are approximations for estimating a personal footprint,
// not audited emission-accounting figures.
var emissionFactors = map[models.ActivityCategory][]EmissionFactor{
	models.CategoryTransportation: {
		{SubType: "car_petrol", Unit: "km", Factor: 0.192},
		{SubType: "car_diesel", Unit: "km", Factor: 0.171},
		{SubType: "car_electric", Unit: "km", Factor: 0.053},
		{SubType: "motorbike", Unit: "km", Factor: 0.103},
		{SubType: "bus", Unit: "km", Factor: 0.105},
		{SubType: "train", Unit: "km", Factor: 0.041},
		{SubType: "flight_domestic", Unit: "km", Factor: 0.246},
		{SubType: "flight_international", Unit: "km", Factor: 0.195},
	},
	models.CategoryElectricity: {
		{SubType: "grid", Unit: "kWh", Factor: 0.475},
		{SubType: "solar", Unit: "kWh", Factor: 0.041},
	},
	models.CategoryFuel: {
		{SubType: "petrol", Unit: "liter", Factor: 2.31},
		{SubType: "diesel", Unit: "liter", Factor: 2.68},
		{SubType: "lpg", Unit: "kg", Factor: 1.51},
		{SubType: "cng", Unit: "kg", Factor: 2.02},
	},
	models.CategoryFood: {
		{SubType: "beef", Unit: "kg", Factor: 27.0},
		{SubType: "lamb", Unit: "kg", Factor: 39.2},
		{SubType: "pork", Unit: "kg", Factor: 12.1},
		{SubType: "chicken", Unit: "kg", Factor: 6.9},
		{SubType: "fish", Unit: "kg", Factor: 6.1},
		{SubType: "dairy", Unit: "kg", Factor: 3.2},
		{SubType: "vegetables", Unit: "kg", Factor: 2.0},
		{SubType: "rice", Unit: "kg", Factor: 4.0},
	},
	models.CategoryWaste: {
		{SubType: "landfill", Unit: "kg", Factor: 0.58},
		{SubType: "recycled", Unit: "kg", Factor: 0.21},
		{SubType: "composted", Unit: "kg", Factor: 0.10},
	},
	models.CategoryWater: {
		{SubType: "tap_water", Unit: "m3", Factor: 0.344},
		{SubType: "hot_water", Unit: "m3", Factor: 0.6},
	},
}

// AllCategories returns every activity category the emission service supports,
// in a stable order.
func AllCategories() []models.ActivityCategory {
	return []models.ActivityCategory{
		models.CategoryTransportation,
		models.CategoryElectricity,
		models.CategoryFuel,
		models.CategoryFood,
		models.CategoryWaste,
		models.CategoryWater,
	}
}

// AvailableSubTypes returns the sub-types (with unit and emission factor)
// available for a category. Returns nil for an unknown category.
func AvailableSubTypes(category models.ActivityCategory) []EmissionFactor {
	return emissionFactors[category]
}

// CalculateEmission looks up the emission factor for subType within category.
// found is false when the category is valid but the sub-type isn't recognized
// (e.g. a user-typed custom entry) — that's a valid outcome, not an error, and
// co2Kg/unit are zero-valued in that case. err is only set for a genuinely
// unknown/invalid category, since every request must have a real category.
func CalculateEmission(category models.ActivityCategory, subType string, quantity float64) (co2Kg float64, unit string, found bool, err error) {
	factors, ok := emissionFactors[category]
	if !ok {
		return 0, "", false, fmt.Errorf("unknown category: %s", category)
	}
	for _, f := range factors {
		if f.SubType == subType {
			return quantity * f.Factor, f.Unit, true, nil
		}
	}
	return 0, "", false, nil
}
