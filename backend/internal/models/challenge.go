package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Challenge is a community climate-action challenge users can join and check
// into daily (e.g. "Cycle to Work" for 7 days).
type Challenge struct {
	ID               uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Title            string    `gorm:"type:varchar(150);not null" json:"title"`
	Description      string    `gorm:"type:text" json:"description"`
	BenefitInfo      string    `gorm:"type:text" json:"benefit_info"`
	Category         string    `gorm:"type:varchar(50);not null" json:"category"`
	IconHint         string    `gorm:"type:varchar(30);not null" json:"icon_hint"`
	PointsPerCheckIn int       `gorm:"not null;default:10" json:"points_per_check_in"`
	DurationDays     int       `gorm:"not null;default:7" json:"duration_days"`
	IsActive         bool      `gorm:"not null;default:true;index" json:"is_active"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (c *Challenge) BeforeCreate(tx *gorm.DB) (err error) {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return
}
