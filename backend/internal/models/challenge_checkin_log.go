package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ChallengeCheckInLog records one point-awarding check-in event. UserChallenge
// only tracks current cumulative state (total_check_ins, last_check_in_date),
// so this append-only log is what lets reports compute how many points were
// earned within an arbitrary date range instead of only all-time totals.
type ChallengeCheckInLog struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID        uuid.UUID `gorm:"type:uuid;not null;index" json:"user_id"`
	ChallengeID   uuid.UUID `gorm:"type:uuid;not null;index" json:"challenge_id"`
	CheckedInAt   time.Time `gorm:"not null;index" json:"checked_in_at"`
	PointsAwarded int       `gorm:"not null" json:"points_awarded"`
}

func (l *ChallengeCheckInLog) BeforeCreate(tx *gorm.DB) (err error) {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	return
}
