package handlers

import (
	"net/http"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm/clause"
)

type AdminNewsHandler struct{}

func NewAdminNewsHandler() *AdminNewsHandler {
	return &AdminNewsHandler{}
}

type hideArticleRequest struct {
	ArticleURL string `json:"article_url" binding:"required,url,max=2000"`
}

// HideArticle hides a news article from the public feed by URL. Idempotent
// via ON CONFLICT DO NOTHING against the unique index — hiding an
// already-hidden URL succeeds without erroring or creating a duplicate row.
// DELETE /api/v1/admin/news
func (h *AdminNewsHandler) HideArticle(c *gin.Context) {
	var req hideArticleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	hidden := models.HiddenNewsArticle{ArticleURL: req.ArticleURL}
	if err := database.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&hidden).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to hide article", err)
		return
	}

	utils.Success(c, http.StatusOK, "article hidden", nil)
}
