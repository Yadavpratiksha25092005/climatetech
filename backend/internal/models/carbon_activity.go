package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ActivityCategory string

const (
	CategoryTransportation ActivityCategory = "transportation"
	CategoryElectricity    ActivityCategory = "electricity"
	CategoryFuel           ActivityCategory = "fuel"
	CategoryFood           ActivityCategory = "food"
	CategoryWaste          ActivityCategory = "waste"
	CategoryWater          ActivityCategory = "water"
)

type CarbonActivity struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	// Composite index matching the (user_id, recorded_at) filter+order every
	// handler in this package queries by (history, summary, daily breakdown,
	// insights, reports) — a single-column index on user_id alone still
	// forces a sort/scan over that user's full row set for the recorded_at
	// range and ORDER BY.
	UserID   uuid.UUID        `gorm:"type:uuid;not null;index:idx_carbon_user_recorded,priority:1" json:"user_id"`
	Category ActivityCategory `gorm:"type:varchar(30);not null;index" json:"category"`
	SubType  string           `gorm:"not null" json:"sub_type"`
	Quantity float64          `json:"quantity"`
	Unit     string           `json:"unit"`
	CO2Kg    float64          `gorm:"column:co2_kg" json:"co2_kg"`
	IsCustom bool             `json:"is_custom"`
	Notes    string           `json:"notes"`

	RecordedAt time.Time      `gorm:"index:idx_carbon_user_recorded,priority:2" json:"recorded_at"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (c *CarbonActivity) BeforeCreate(tx *gorm.DB) (err error) {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.RecordedAt.IsZero() {
		c.RecordedAt = time.Now()
	}
	return
}
