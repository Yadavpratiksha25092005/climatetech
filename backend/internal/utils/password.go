package utils

import (
	"errors"

	"golang.org/x/crypto/bcrypt"
)

// ErrPasswordTooLong is returned for a password over bcrypt's 72-byte input
// limit. bcrypt silently ignores anything past that limit rather than
// erroring, so without this check two passwords differing only after byte 72
// would hash identically and both be accepted as correct.
var ErrPasswordTooLong = errors.New("password must be at most 72 bytes")

func HashPassword(password string) (string, error) {
	if len(password) > 72 {
		return "", ErrPasswordTooLong
	}
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}
