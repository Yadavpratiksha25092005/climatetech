-- Adds the composite indexes matching this project's actual hot query
-- shapes (see internal/models/carbon_activity.go, climate_data.go, alert.go
-- for the corresponding GORM composite-index tags). Purely additive — safe
-- to run against the existing AutoMigrate-created schema with no data or
-- column changes.
CREATE INDEX IF NOT EXISTS idx_carbon_user_recorded ON carbon_activities (user_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_climate_user_recorded ON climate_data (user_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_alert_user_read ON alerts (user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_alert_user_type_created ON alerts (user_id, alert_type, created_at);
