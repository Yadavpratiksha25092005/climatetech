package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

const newsCacheTTL = 30 * time.Minute

type NewsHandler struct {
	newsService *services.NewsService
}

func NewNewsHandler(newsService *services.NewsService) *NewsHandler {
	return &NewsHandler{newsService: newsService}
}

// GetNews returns a page of climate/sustainability news, serving from a
// 30-minute Redis cache when available so repeated requests for the same
// page don't all hit NewsAPI's rate limit.
// GET /api/v1/news?page=1
func (h *NewsHandler) GetNews(c *gin.Context) {
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page <= 0 {
		page = 1
	}

	cacheKey := fmt.Sprintf("news:page:%d", page)

	var articles []services.NewsArticle
	if cached, err := database.RedisClient.Get(database.Ctx, cacheKey).Result(); err == nil {
		if err := json.Unmarshal([]byte(cached), &articles); err != nil {
			articles = nil
		}
	}

	if articles == nil {
		articles, err = h.newsService.GetClimateNews(page)
		if err != nil {
			utils.Fail(c, http.StatusBadGateway, "failed to fetch climate news", err)
			return
		}

		if encoded, err := json.Marshal(articles); err == nil {
			// Best-effort cache write — a Redis hiccup here shouldn't fail the request.
			database.RedisClient.Set(database.Ctx, cacheKey, encoded, newsCacheTTL)
		}
	}

	visible, err := h.filterHiddenArticles(articles)
	if err != nil {
		// Best-effort: if the hidden-articles lookup fails, still show the
		// feed unfiltered rather than failing the whole request.
		log.Printf("failed to filter hidden articles, showing unfiltered feed: %v", err)
		visible = articles
	}

	utils.Success(c, http.StatusOK, "news fetched", gin.H{"articles": visible, "page": page})
}

// filterHiddenArticles removes any article an admin has hidden by URL — one
// query for every hidden URL, filtered in memory, never one query per article.
func (h *NewsHandler) filterHiddenArticles(articles []services.NewsArticle) ([]services.NewsArticle, error) {
	if len(articles) == 0 {
		return articles, nil
	}

	var hidden []models.HiddenNewsArticle
	if err := database.DB.Find(&hidden).Error; err != nil {
		return nil, err
	}
	if len(hidden) == 0 {
		return articles, nil
	}

	hiddenURLs := make(map[string]struct{}, len(hidden))
	for _, h := range hidden {
		hiddenURLs[h.ArticleURL] = struct{}{}
	}

	visible := make([]services.NewsArticle, 0, len(articles))
	for _, a := range articles {
		if _, isHidden := hiddenURLs[a.URL]; !isHidden {
			visible = append(visible, a)
		}
	}
	return visible, nil
}
