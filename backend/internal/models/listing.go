package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ListingCondition string

const (
	ConditionNew  ListingCondition = "new"
	ConditionUsed ListingCondition = "used"
)

// Listing is a single marketplace classified ad, owned by a Seller.
type Listing struct {
	ID          uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	SellerID    uuid.UUID        `gorm:"type:uuid;not null;index" json:"seller_id"`
	Title       string           `gorm:"type:varchar(200);not null" json:"title"`
	Description string           `gorm:"type:text" json:"description"`
	Price       float64          `gorm:"not null" json:"price"`
	Category    string           `gorm:"type:varchar(50);not null;index" json:"category"`
	ImageURLs   StringArray      `gorm:"type:text" json:"image_urls"`
	Condition   ListingCondition `gorm:"type:varchar(10);not null;default:'used'" json:"condition"`
	Location    string           `gorm:"type:varchar(150)" json:"location"`
	IsActive    bool             `gorm:"not null;default:true;index" json:"is_active"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (l *Listing) BeforeCreate(tx *gorm.DB) (err error) {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	if l.Condition == "" {
		l.Condition = ConditionUsed
	}
	return
}
