package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ClimateData struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	// Composite index matching (user_id, recorded_at) — every handler that
	// reads this table filters by user_id and orders/filters by recorded_at
	// (history, latest reading for the AI summary, report generation).
	UserID       uuid.UUID `gorm:"type:uuid;not null;index:idx_climate_user_recorded,priority:1" json:"user_id"`
	Latitude     float64   `json:"latitude"`
	Longitude    float64   `json:"longitude"`
	LocationName string    `json:"location_name"`

	Temperature float64 `json:"temperature"`
	FeelsLike   float64 `json:"feels_like"`
	Humidity    int     `json:"humidity"`
	WindSpeed   float64 `json:"wind_speed"`
	WindDeg     int     `json:"wind_deg"`
	Pressure    int     `json:"pressure"`
	Visibility  int     `json:"visibility"`
	RainVolume  float64 `json:"rain_volume"`
	DewPoint    float64 `json:"dew_point"`
	WeatherMain string  `json:"weather_main"`
	WeatherDesc string  `json:"weather_description"`
	WeatherIcon string  `json:"weather_icon"`

	AQI  int     `json:"aqi"`
	PM25 float64 `json:"pm2_5"`
	PM10 float64 `json:"pm10"`
	CO   float64 `json:"co"`
	NO2  float64 `json:"no2"`
	O3   float64 `json:"o3"`

	RecordedAt time.Time      `gorm:"index:idx_climate_user_recorded,priority:2" json:"recorded_at"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (c *ClimateData) BeforeCreate(tx *gorm.DB) (err error) {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.RecordedAt.IsZero() {
		c.RecordedAt = time.Now()
	}
	return
}

// AQILabel converts OpenWeather's 1-5 index into a human-readable label.
func (c *ClimateData) AQILabel() string {
	switch c.AQI {
	case 1:
		return "Good"
	case 2:
		return "Fair"
	case 3:
		return "Moderate"
	case 4:
		return "Poor"
	case 5:
		return "Very Poor"
	default:
		return "Unknown"
	}
}
