// cmd/migrate is a standalone, explicit schema-bootstrap tool — run it once
// against a brand-new database (a fresh RDS instance with no tables yet)
// before the first deploy of the main server, or after adding a new
// GORM model/field that needs a corresponding column. It intentionally
// is NOT invoked automatically by cmd/server: schema changes on a
// production database should be a deliberate, reviewed step (a CI job or a
// one-off ECS task), not something that silently happens on every container
// boot.
//
// After this bootstrap step, day-to-day incremental schema changes are
// handled by the versioned SQL migrations in internal/database/migrations,
// which cmd/server *does* apply automatically at startup (that mechanism is
// safe for concurrent instances — see internal/database/migrate.go).
package main

import (
	"log"

	"climatetech-backend/internal/config"
	"climatetech-backend/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	cfg := config.Load()

	dsn := "host=" + cfg.DBHost +
		" port=" + cfg.DBPort +
		" user=" + cfg.DBUser +
		" password=" + cfg.DBPassword +
		" dbname=" + cfg.DBName +
		" sslmode=" + cfg.DBSSLMode

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to postgres: %v", err)
	}

	log.Println("bootstrapping schema via AutoMigrate (one-off — see cmd/migrate doc comment)...")
	err = db.AutoMigrate(
		&models.User{},
		&models.ClimateData{},
		&models.CarbonActivity{},
		&models.Alert{},
		&models.Seller{},
		&models.Listing{},
		&models.Challenge{},
		&models.UserChallenge{},
		&models.ChallengeCheckInLog{},
		&models.HiddenNewsArticle{},
	)
	if err != nil {
		log.Fatalf("schema bootstrap failed: %v", err)
	}

	log.Println("schema bootstrap complete")
}
