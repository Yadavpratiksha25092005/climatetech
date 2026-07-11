package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type GeminiService struct {
	APIKey string
	Model  string
	Client *http.Client
}

func NewGeminiService(apiKey, model string) *GeminiService {
	return &GeminiService{
		APIKey: apiKey,
		Model:  model,
		Client: &http.Client{Timeout: 20 * time.Second},
	}
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiRequest struct {
	Contents []geminiContent `json:"contents"`
}

type geminiResponse struct {
	Candidates []struct {
		Content geminiContent `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

// GenerateInsights sends prompt to the Gemini API and returns the model's raw text reply.
func (s *GeminiService) GenerateInsights(prompt string) (string, error) {
	if s.APIKey == "" {
		return "", fmt.Errorf("gemini api key is not configured")
	}

	// Model-only URL — the API key travels in a header instead of the query
	// string below, so it never lands in access logs or proxy logs that
	// record request URLs.
	url := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent",
		s.Model,
	)

	reqBody, err := json.Marshal(geminiRequest{
		Contents: []geminiContent{{Parts: []geminiPart{{Text: prompt}}}},
	})
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(reqBody))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", s.APIKey)

	resp, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// Status is checked before unmarshaling so a real API error (429, 502,
	// or any non-JSON error/proxy page) is reported as what it actually is
	// instead of surfacing as a generic decode failure.
	if resp.StatusCode != http.StatusOK {
		var errResp geminiResponse
		if err := json.Unmarshal(body, &errResp); err == nil && errResp.Error != nil {
			return "", fmt.Errorf("gemini api error (status %d): %s", resp.StatusCode, errResp.Error.Message)
		}
		return "", fmt.Errorf("gemini api returned status %d: %s", resp.StatusCode, string(body))
	}

	var result geminiResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to decode gemini response: %w", err)
	}

	if len(result.Candidates) == 0 || len(result.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("gemini returned no candidates")
	}

	return result.Candidates[0].Content.Parts[0].Text, nil
}
