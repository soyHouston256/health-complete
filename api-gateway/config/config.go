package config

import (
	"encoding/json"
	"os"
)

type Config struct {
	Gateway GatewayConfig `json:"gateway"`
	Auth    AuthConfig    `json:"auth"`
}

type GatewayConfig struct {
	Port     string          `json:"port"`
	Services []ServiceConfig `json:"services"`
}

type ServiceConfig struct {
	Name         string             `json:"name"`
	BaseURL      string             `json:"base_url"`
	Prefix       string             `json:"prefix"`
	Timeout      int                `json:"timeout"`
	RateLimit    RateLimitConfig    `json:"rate_limit"`
	LoadBalancer LoadBalancerConfig `json:"load_balancer"`
	HealthCheck  HealthCheckConfig  `json:"health_check"`
	Cache        CacheConfig        `json:"cache"`
}

type RateLimitConfig struct {
	RequestsPerSecond int  `json:"requests_per_second"`
	BurstSize         int  `json:"burst_size"`
	Enabled           bool `json:"enabled"`
}

type LoadBalancerConfig struct {
	Strategy string   `json:"strategy"` // round_robin, random, weighted, least_connections
	Backends []string `json:"backends"`
	Enabled  bool     `json:"enabled"`
}

type HealthCheckConfig struct {
	Enabled         bool   `json:"enabled"`
	Endpoint        string `json:"endpoint"`
	IntervalSeconds int    `json:"interval_seconds"`
	TimeoutSeconds  int    `json:"timeout_seconds"`
}

type CacheConfig struct {
	Enabled bool `json:"enabled"`
	TTL     int  `json:"ttl_seconds"`
}

type AuthConfig struct {
	Enabled       bool   `json:"enabled"`
	JWTSecret     string `json:"jwt_secret"`
	TokenExpiry   int    `json:"token_expiry_hours"`
	RefreshExpiry int    `json:"refresh_expiry_hours"`
}

func LoadConfig(path string) (*Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var config Config
	decoder := json.NewDecoder(file)
	err = decoder.Decode(&config)
	if err != nil {
		return nil, err
	}

	// Aplicar valores por defecto
	config.applyDefaults()

	return &config, nil
}

func (c *Config) applyDefaults() {
	if c.Gateway.Port == "" {
		c.Gateway.Port = "8000"
	}

	for i := range c.Gateway.Services {
		service := &c.Gateway.Services[i]

		if service.Timeout == 0 {
			service.Timeout = 30
		}

		if !service.RateLimit.Enabled {
			service.RateLimit.RequestsPerSecond = 100
			service.RateLimit.BurstSize = 200
		}

		if service.HealthCheck.IntervalSeconds == 0 {
			service.HealthCheck.IntervalSeconds = 30
		}

		if service.HealthCheck.TimeoutSeconds == 0 {
			service.HealthCheck.TimeoutSeconds = 5
		}

		if service.Cache.TTL == 0 {
			service.Cache.TTL = 300 // 5 minutos
		}
	}
}
