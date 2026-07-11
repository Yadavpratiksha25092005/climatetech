package database

import (
	"fmt"
	"log"
	"time"

	"climatetech-backend/internal/config"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func ConnectPostgres(cfg *config.Config) *gorm.DB {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)

	gormLogLevel := logger.Silent
	if cfg.AppEnv == "development" {
		gormLogLevel = logger.Info
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(gormLogLevel),
	})
	if err != nil {
		log.Fatalf("failed to connect to postgres: %v", err)
	}

	log.Println("connected to postgres successfully")

	// Go's database/sql defaults to unlimited open connections — dangerous
	// once this app is horizontally scaled behind an ALB, since N instances
	// all defaulting to "unlimited" can collectively exceed RDS's
	// max_connections. These bounds are deliberately conservative; tune
	// MaxOpenConns relative to (RDS max_connections / expected instance
	// count) for the target environment.
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("failed to access underlying sql.DB: %v", err)
	}
	sqlDB.SetMaxOpenConns(20)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)
	sqlDB.SetConnMaxIdleTime(5 * time.Minute)

	// Schema changes are applied via versioned SQL migrations (see
	// internal/database/migrations), not GORM AutoMigrate — AutoMigrate
	// running unconditionally on every container boot meant concurrent
	// instances starting during a rolling deploy could race on DDL, and
	// there was no reviewable history of what changed and when. The base
	// schema itself is created once via `cmd/migrate` (see its own comment)
	// on a brand-new environment; this call only applies anything added
	// since then.
	if err := runVersionedMigrations(db); err != nil {
		log.Fatalf("failed to run schema migrations: %v", err)
	}

	// Seed data is non-critical — a failure here shouldn't take down the
	// backend, just leave the challenges list empty until it's retried.
	if err := seedChallenges(db); err != nil {
		log.Printf("failed to seed default challenges: %v", err)
	}

	DB = db
	return db
}
