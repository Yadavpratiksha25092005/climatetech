package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// FCMService sends push notifications via the FCM HTTP v1 API. It degrades
// gracefully (SendPushNotification becomes a no-op) whenever credentials
// weren't loaded, so a missing/invalid service account file never prevents
// the backend from starting or breaks features that trigger notifications.
type FCMService struct {
	projectID   string
	tokenSource oauth2.TokenSource
	client      *http.Client
}

// NewFCMService loads a Firebase service account JSON from credentialsPath and
// builds a reusable, self-refreshing OAuth2 token source from it. On any
// failure (path unset, unreadable, unparseable), it logs a warning and returns
// a disabled service rather than erroring, since push notifications are a
// nice-to-have and must never block backend startup.
func NewFCMService(credentialsPath string) *FCMService {
	if credentialsPath == "" {
		log.Println("FIREBASE_CREDENTIALS_PATH not set — push notifications disabled")
		return &FCMService{}
	}

	raw, err := os.ReadFile(credentialsPath)
	if err != nil {
		log.Printf("could not read firebase credentials file at %q, push notifications disabled: %v", credentialsPath, err)
		return &FCMService{}
	}

	var meta struct {
		ProjectID string `json:"project_id"`
	}
	if err := json.Unmarshal(raw, &meta); err != nil {
		log.Printf("could not parse firebase credentials file at %q, push notifications disabled: %v", credentialsPath, err)
		return &FCMService{}
	}
	if meta.ProjectID == "" {
		// A distinct branch from the unmarshal error above — logging this
		// case with the (nil) unmarshal err would print a misleading
		// "disabled: <nil>" even though parsing succeeded fine.
		log.Printf("firebase credentials file at %q has no project_id, push notifications disabled", credentialsPath)
		return &FCMService{}
	}

	creds, err := google.CredentialsFromJSON(context.Background(), raw, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil {
		log.Printf("could not build google credentials from %q, push notifications disabled: %v", credentialsPath, err)
		return &FCMService{}
	}

	log.Printf("FCM push notifications enabled for firebase project %q", meta.ProjectID)
	return &FCMService{
		projectID:   meta.ProjectID,
		tokenSource: creds.TokenSource,
		client:      &http.Client{Timeout: 10 * time.Second},
	}
}

// Enabled reports whether valid Firebase credentials were loaded.
func (s *FCMService) Enabled() bool {
	return s.tokenSource != nil
}

type fcmMessage struct {
	Message fcmMessagePayload `json:"message"`
}

type fcmMessagePayload struct {
	Token        string            `json:"token"`
	Notification map[string]string `json:"notification"`
}

// SendPushNotification sends a single-device push notification via the FCM
// HTTP v1 API. It's a safe no-op if the service is disabled or fcmToken is
// empty — callers don't need to check Enabled() themselves.
func (s *FCMService) SendPushNotification(fcmToken, title, body string) error {
	if !s.Enabled() || fcmToken == "" {
		return nil
	}

	// TokenSource caches and only performs a network round-trip when the
	// cached access token has actually expired, so this is cheap to call
	// on every push rather than something callers need to ration.
	token, err := s.tokenSource.Token()
	if err != nil {
		return fmt.Errorf("failed to get fcm access token: %w", err)
	}

	payload := fcmMessage{
		Message: fcmMessagePayload{
			Token:        fcmToken,
			Notification: map[string]string{"title": title, "body": body},
		},
	}
	reqBody, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.projectID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(reqBody))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token.AccessToken)

	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("fcm api returned status %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
