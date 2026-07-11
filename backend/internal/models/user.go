package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Role string

const (
	RoleUser         Role = "user"
	RoleOrganization Role = "organization"
	RoleAdmin        Role = "admin"
)

type User struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Name         string    `gorm:"type:varchar(150);not null" json:"name"`
	Email        string    `gorm:"type:varchar(150);uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"type:text;not null" json:"-"`
	Role         Role      `gorm:"type:varchar(20);not null;default:'user'" json:"role"`
	Avatar       string    `gorm:"type:text" json:"avatar,omitempty"`
	Phone        string    `gorm:"type:varchar(20)" json:"phone,omitempty"`
	IsActive     bool      `gorm:"default:true" json:"is_active"`
	FCMToken     string    `gorm:"type:text" json:"-"`
	TotalPoints  int       `gorm:"not null;default:0" json:"-"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (u *User) BeforeCreate(tx *gorm.DB) (err error) {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	if u.Role == "" {
		u.Role = RoleUser
	}
	return
}

// Public-safe representation returned by the API (never expose PasswordHash)
type UserResponse struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	Role        Role      `json:"role"`
	Avatar      string    `json:"avatar,omitempty"`
	TotalPoints int       `json:"total_points"`
	Badges      []string  `json:"badges"`
	CreatedAt   time.Time `json:"created_at"`
}

func (u *User) ToResponse() UserResponse {
	return UserResponse{
		ID:          u.ID,
		Name:        u.Name,
		Email:       u.Email,
		Role:        u.Role,
		Avatar:      u.Avatar,
		TotalPoints: u.TotalPoints,
		Badges:      GetBadges(u.TotalPoints),
		CreatedAt:   u.CreatedAt,
	}
}
