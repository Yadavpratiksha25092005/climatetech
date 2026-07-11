package services

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

type NewsService struct {
	APIKey string
	Client *http.Client
}

func NewNewsService(apiKey string) *NewsService {
	return &NewsService{
		APIKey: apiKey,
		Client: &http.Client{Timeout: 10 * time.Second},
	}
}

type NewsArticle struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	URL         string `json:"url"`
	ImageURL    string `json:"image_url"`
	SourceName  string `json:"source_name"`
	PublishedAt string `json:"published_at"`
}

type newsAPIResponse struct {
	Status   string `json:"status"`
	Message  string `json:"message"`
	Articles []struct {
		Source struct {
			Name string `json:"name"`
		} `json:"source"`
		Title       string `json:"title"`
		Description string `json:"description"`
		URL         string `json:"url"`
		URLToImage  string `json:"urlToImage"`
		PublishedAt string `json:"publishedAt"`
	} `json:"articles"`
}

// GetClimateNews fetches page N (1-indexed, 20 per page) of climate/sustainability
// news from NewsAPI's "everything" endpoint, sorted by most recently published.
func (s *NewsService) GetClimateNews(page int) ([]NewsArticle, error) {
	if s.APIKey == "" {
		return nil, fmt.Errorf("news api key is not configured")
	}
	if page <= 0 {
		page = 1
	}

	// A tightly-scoped OR query keeps results on-topic (environment/climate)
	// rather than pulling in generic "green"-adjacent business or politics
	// coverage that a looser query would match.
	query := `(environment OR "climate change" OR "renewable energy" OR pollution OR "global warming" OR sustainability OR "carbon emissions" OR biodiversity OR conservation)`

	params := url.Values{}
	params.Set("q", query)
	params.Set("language", "en")
	params.Set("sortBy", "publishedAt")
	params.Set("pageSize", "20")
	params.Set("page", strconv.Itoa(page))
	params.Set("apiKey", s.APIKey)

	requestURL := "https://newsapi.org/v2/everything?" + params.Encode()

	resp, err := s.Client.Get(requestURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Status is checked before decoding so a non-200 response with a
	// non-JSON body (an upstream proxy/WAF error page, for instance) is
	// reported as the real HTTP status instead of masked as a decode
	// failure.
	var result newsAPIResponse
	if resp.StatusCode != http.StatusOK {
		msg := ""
		if jsonErr := json.Unmarshal(body, &result); jsonErr == nil {
			msg = result.Message
		}
		if msg == "" {
			msg = fmt.Sprintf("news api returned status %d", resp.StatusCode)
		}
		return nil, fmt.Errorf("%s", msg)
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	articles := make([]NewsArticle, 0, len(result.Articles))
	for _, a := range result.Articles {
		// NewsAPI represents takedown/removed content with literal "[Removed]"
		// placeholders instead of omitting the article — skip those.
		if a.Title == "" || a.Title == "[Removed]" {
			continue
		}
		articles = append(articles, NewsArticle{
			Title:       a.Title,
			Description: a.Description,
			URL:         a.URL,
			ImageURL:    a.URLToImage,
			SourceName:  a.Source.Name,
			PublishedAt: a.PublishedAt,
		})
	}
	return articles, nil
}
