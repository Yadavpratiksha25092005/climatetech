package database

import (
	"embed"
	"errors"
	"log"

	"github.com/golang-migrate/migrate/v4"
	pgmigrate "github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"gorm.io/gorm"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

// runVersionedMigrations applies every pending SQL migration under
// internal/database/migrations using golang-migrate. This replaces
// GORM AutoMigrate as the schema-change mechanism going forward: changes are
// explicit, reviewable SQL files tracked in a schema_migrations table
// (rather than an implicit reflect-based diff run on every single container
// boot), and golang-migrate's Postgres driver takes an advisory lock for the
// duration of the migration — so multiple ECS/App Runner instances starting
// concurrently during a deploy can't race on DDL the way unconditional
// AutoMigrate could.
//
// The base schema itself (tables that already exist from this project's
// earlier AutoMigrate-based history) is intentionally NOT redefined here —
// see cmd/migrate for the one-off bootstrap step used for brand-new
// environments. This function only applies incremental, versioned changes.
func runVersionedMigrations(db *gorm.DB) error {
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	driver, err := pgmigrate.WithInstance(sqlDB, &pgmigrate.Config{})
	if err != nil {
		return err
	}

	source, err := iofs.New(migrationFiles, "migrations")
	if err != nil {
		return err
	}

	m, err := migrate.NewWithInstance("iofs", source, "postgres", driver)
	if err != nil {
		return err
	}

	if err := m.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			log.Println("no pending schema migrations")
			return nil
		}
		return err
	}

	log.Println("schema migrations applied successfully")
	return nil
}
