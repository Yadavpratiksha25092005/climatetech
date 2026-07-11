package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// HiddenNewsArticle records an article URL an admin has hidden from the
// public news feed. NewsAPI results aren't stored locally (news_handler.go
// only caches raw API responses in Redis), so hiding works by filtering the
// live feed against this table rather than deleting any local article row.
type HiddenNewsArticle struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ArticleURL string    `gorm:"type:text;not null;uniqueIndex" json:"article_url"`
	HiddenAt   time.Time `json:"hidden_at"`
}

func (h *HiddenNewsArticle) BeforeCreate(tx *gorm.DB) (err error) {
	if h.ID == uuid.Nil {
		h.ID = uuid.New()
	}
	if h.HiddenAt.IsZero() {
		h.HiddenAt = time.Now()
	}
	return
}
