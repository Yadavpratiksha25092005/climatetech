package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

type WeatherService struct {
	APIKey string
	Client *http.Client
}

func NewWeatherService(apiKey string) *WeatherService {
	return &WeatherService{
		APIKey: apiKey,
		Client: &http.Client{Timeout: 10 * time.Second},
	}
}

type CurrentWeatherResponse struct {
	Name string `json:"name"`
	Main struct {
		Temp      float64 `json:"temp"`
		FeelsLike float64 `json:"feels_like"`
		Humidity  int     `json:"humidity"`
		Pressure  int     `json:"pressure"`
	} `json:"main"`
	Wind struct {
		Speed float64 `json:"speed"`
		Deg   int     `json:"deg"`
	} `json:"wind"`
	Weather []struct {
		Main        string `json:"main"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
	} `json:"weather"`
	Visibility int `json:"visibility"`
	Rain       struct {
		OneHour float64 `json:"1h"`
	} `json:"rain"`
}

type AirPollutionResponse struct {
	List []struct {
		Main struct {
			AQI int `json:"aqi"`
		} `json:"main"`
		Components struct {
			CO   float64 `json:"co"`
			NO2  float64 `json:"no2"`
			O3   float64 `json:"o3"`
			PM25 float64 `json:"pm2_5"`
			PM10 float64 `json:"pm10"`
		} `json:"components"`
	} `json:"list"`
}

type ForecastResponse struct {
	List []ForecastItem `json:"list"`
	City struct {
		Name string `json:"name"`
	} `json:"city"`
}

type ForecastItem struct {
	DT   int64 `json:"dt"`
	Main struct {
		Temp      float64 `json:"temp"`
		FeelsLike float64 `json:"feels_like"`
		Humidity  int     `json:"humidity"`
	} `json:"main"`
	Wind struct {
		Speed float64 `json:"speed"`
		Deg   int     `json:"deg"`
	} `json:"wind"`
	Weather []struct {
		Main        string `json:"main"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
	} `json:"weather"`
	Pop   float64 `json:"pop"`
	DtTxt string  `json:"dt_txt"`
}

func (s *WeatherService) GetCurrentWeather(lat, lon float64) (*CurrentWeatherResponse, error) {
	if s.APIKey == "" {
		return nil, fmt.Errorf("weather api key is not configured")
	}

	url := fmt.Sprintf(
		"https://api.openweathermap.org/data/2.5/weather?lat=%f&lon=%f&appid=%s&units=metric",
		lat, lon, s.APIKey,
	)

	resp, err := s.Client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("weather api returned status %d", resp.StatusCode)
	}

	var result CurrentWeatherResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (s *WeatherService) GetAirPollution(lat, lon float64) (*AirPollutionResponse, error) {
	if s.APIKey == "" {
		return nil, fmt.Errorf("weather api key is not configured")
	}

	url := fmt.Sprintf(
		"https://api.openweathermap.org/data/2.5/air_pollution?lat=%f&lon=%f&appid=%s",
		lat, lon, s.APIKey,
	)

	resp, err := s.Client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("air pollution api returned status %d", resp.StatusCode)
	}

	var result AirPollutionResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetForecast returns 3-hour interval forecasts for the next 5 days
// (OpenWeather's free "5 day / 3 hour forecast" endpoint).
func (s *WeatherService) GetForecast(lat, lon float64) (*ForecastResponse, error) {
	if s.APIKey == "" {
		return nil, fmt.Errorf("weather api key is not configured")
	}

	url := fmt.Sprintf(
		"https://api.openweathermap.org/data/2.5/forecast?lat=%f&lon=%f&appid=%s&units=metric",
		lat, lon, s.APIKey,
	)

	resp, err := s.Client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("forecast api returned status %d", resp.StatusCode)
	}

	var result ForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}

type GeoLocation struct {
	Name    string  `json:"name"`
	State   string  `json:"state"`
	Country string  `json:"country"`
	Lat     float64 `json:"lat"`
	Lon     float64 `json:"lon"`
}

// SearchCity resolves a free-text place name (e.g. "Tokyo" or "Navi Mumbai")
// to up to 5 matching lat/lon locations worldwide, using OpenWeather's
// Geocoding API — this is what lets the forecast screen look up weather
// anywhere, not just the user's current GPS position.
func (s *WeatherService) SearchCity(query string) ([]GeoLocation, error) {
	if s.APIKey == "" {
		return nil, fmt.Errorf("weather api key is not configured")
	}

	geoURL := fmt.Sprintf(
		"https://api.openweathermap.org/geo/1.0/direct?q=%s&limit=5&appid=%s",
		url.QueryEscape(query), s.APIKey,
	)

	resp, err := s.Client.Get(geoURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("geocoding api returned status %d", resp.StatusCode)
	}

	var results []GeoLocation
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, err
	}
	return results, nil
}
