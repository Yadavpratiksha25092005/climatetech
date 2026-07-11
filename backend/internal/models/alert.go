package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AlertType string

const (
	AlertTypePoorAirQuality AlertType = "poor_air_quality"
	AlertTypeHeatWave       AlertType = "heat_wave"
	AlertTypeHeavyRain      AlertType = "heavy_rain"
	AlertTypeAdminBroadcast AlertType = "admin_broadcast"
)

type Alert struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	// Two composite indexes cover this table's actual query shapes:
	// (user_id, is_read) for GetUnreadCount, and (user_id, alert_type,
	// created_at) for the recent-alert dedup check in checkAndSendAlerts.
	// The single-column indexes below remain for any other ad-hoc filter.
	UserID    uuid.UUID `gorm:"type:uuid;not null;index;index:idx_alert_user_read,priority:1;index:idx_alert_user_type_created,priority:1" json:"user_id"`
	AlertType AlertType `gorm:"type:varchar(30);not null;index;index:idx_alert_user_type_created,priority:2" json:"alert_type"`
	Severity  string    `gorm:"type:varchar(20);not null" json:"severity"`
	Title     string    `gorm:"type:varchar(150);not null" json:"title"`
	Message   string    `gorm:"type:text;not null" json:"message"`
	IsRead    bool      `gorm:"not null;default:false;index;index:idx_alert_user_read,priority:2" json:"is_read"`

	CreatedAt time.Time      `gorm:"index:idx_alert_user_type_created,priority:3" json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (a *Alert) BeforeCreate(tx *gorm.DB) (err error) {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return
}
