package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type UserChallengeStatus string

const (
	UserChallengeStatusActive    UserChallengeStatus = "active"
	UserChallengeStatusCompleted UserChallengeStatus = "completed"
)

// UserChallenge tracks one user's progress on one challenge — at most one
// row per (user, challenge) pair, enforced by the composite unique index.
type UserChallenge struct {
	ID              uuid.UUID           `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID          uuid.UUID           `gorm:"type:uuid;not null;uniqueIndex:idx_user_challenge" json:"user_id"`
	ChallengeID     uuid.UUID           `gorm:"type:uuid;not null;uniqueIndex:idx_user_challenge" json:"challenge_id"`
	JoinedAt        time.Time           `json:"joined_at"`
	LastCheckInDate *time.Time          `json:"last_check_in_date"`
	TotalCheckIns   int                 `gorm:"not null;default:0" json:"total_check_ins"`
	Status          UserChallengeStatus `gorm:"type:varchar(20);not null;default:'active'" json:"status"`

	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (uc *UserChallenge) BeforeCreate(tx *gorm.DB) (err error) {
	if uc.ID == uuid.Nil {
		uc.ID = uuid.New()
	}
	if uc.JoinedAt.IsZero() {
		uc.JoinedAt = time.Now()
	}
	if uc.Status == "" {
		uc.Status = UserChallengeStatusActive
	}
	return
}
