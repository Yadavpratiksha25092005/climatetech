package main

import (
	"context"
	"errors"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"climatetech-backend/internal/config"
	"climatetech-backend/internal/database"
	"climatetech-backend/internal/middleware"
	"climatetech-backend/internal/routes"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	// JSON structured logging — every log line (including middleware.Logger's
	// per-request lines and utils.Fail's 5xx error logs) is queryable in
	// CloudWatch Logs Insights by field, instead of grepping plain text.
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	database.ConnectPostgres(cfg)
	database.ConnectRedis(cfg)

	router := gin.New()

	// Pins which upstream hops are trusted for X-Forwarded-For/-Proto —
	// left unset, Gin trusts every proxy in the chain, which would let a
	// client spoof its own IP (breaking rate limiting and audit logging) by
	// simply setting X-Forwarded-For itself. Configure TRUSTED_PROXIES to
	// the load balancer's subnet in production.
	if len(cfg.TrustedProxies) > 0 {
		if err := router.SetTrustedProxies(cfg.TrustedProxies); err != nil {
			log.Fatalf("invalid TRUSTED_PROXIES: %v", err)
		}
	} else {
		if err := router.SetTrustedProxies(nil); err != nil {
			log.Fatalf("failed to clear trusted proxies: %v", err)
		}
	}

	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.Logger())
	router.Use(middleware.SecurityHeaders(cfg))
	router.Use(middleware.RequireHTTPS(cfg))
	router.Use(middleware.BodySizeLimit())

	router.Use(cors.New(cors.Config{
		AllowOrigins:     cfg.AllowedOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", middleware.RequestIDHeader},
		AllowCredentials: true,
	}))

	routes.RegisterRoutes(router, cfg)

	srv := &http.Server{
		Addr:              ":" + cfg.AppPort,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("climatetech backend running on port %s [%s]", cfg.AppPort, cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server failed to start: %v", err)
		}
	}()

	// Graceful shutdown: on SIGTERM (what ECS/Docker sends before killing a
	// container) or SIGINT, stop accepting new connections and give
	// in-flight requests up to 20s to finish, instead of dropping them
	// mid-response on every deploy/scale-in event.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutdown signal received, draining in-flight requests...")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown did not complete cleanly: %v", err)
	}
	log.Println("server stopped")
}
