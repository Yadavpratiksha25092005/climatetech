package utils

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

// IsUniqueViolation reports whether err is a Postgres unique-constraint
// violation (SQLSTATE 23505). Used to turn a check-then-create TOCTOU race
// into the correct 409 response instead of a generic 500 when two
// concurrent requests both pass the pre-check and only one insert can win.
func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
