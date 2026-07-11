package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
)

// StringArray persists a []string as a JSON-encoded text column. This project
// doesn't use a Postgres-array-aware driver type, so a simple JSON text
// column keeps things dependency-free and portable.
type StringArray []string

func (a StringArray) Value() (driver.Value, error) {
	if a == nil {
		return "[]", nil
	}
	b, err := json.Marshal([]string(a))
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = StringArray{}
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("unsupported type for StringArray scan")
	}

	if len(bytes) == 0 {
		*a = StringArray{}
		return nil
	}

	var result []string
	if err := json.Unmarshal(bytes, &result); err != nil {
		return err
	}
	*a = StringArray(result)
	return nil
}
