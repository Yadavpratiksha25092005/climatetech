package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type SellerStatus string

const (
	SellerStatusPending  SellerStatus = "pending"
	SellerStatusApproved SellerStatus = "approved"
	SellerStatusRejected SellerStatus = "rejected"
)

// Seller is a marketplace seller profile — at most one per user, subject to
// admin approval before the user can post listings.
type Seller struct {
	ID            uuid.UUID    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID        uuid.UUID    `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`
	ShopName      string       `gorm:"type:varchar(150);not null" json:"shop_name"`
	OwnerName     string       `gorm:"type:varchar(150);not null" json:"owner_name"`
	Address       string       `gorm:"type:text;not null" json:"address"`
	City          string       `gorm:"type:varchar(100);not null" json:"city"`
	ShopCategory  string       `gorm:"type:varchar(50);not null" json:"shop_category"`
	Description   string       `gorm:"type:text" json:"description"`
	ShopPhotoURLs StringArray  `gorm:"type:text" json:"shop_photo_urls"`
	Status        SellerStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (s *Seller) BeforeCreate(tx *gorm.DB) (err error) {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	if s.Status == "" {
		s.Status = SellerStatusPending
	}
	return
}
