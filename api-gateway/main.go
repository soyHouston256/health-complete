package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"api-gateway/config"
	"api-gateway/health"
	"api-gateway/proxy"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

// Estructura estándar de respuesta para el gateway
type GatewayResponse struct {
	Data         interface{} `json:"data"`
	Success      bool        `json:"success"`
	ErrorMessage *string     `json:"errorMessage"`
}

type APIGateway struct {
	config        *config.Config
	echo          *echo.Echo
	proxyHandler  *proxy.Handler
	healthChecker *health.Checker
}

func NewAPIGateway(configPath string) (*APIGateway, error) {
	// Cargar configuración
	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		return nil, fmt.Errorf("error loading config: %w", err)
	}

	// Crear instancia de Echo
	e := echo.New()

	// Middleware básico
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Health checker
	healthChecker := health.NewChecker()

	// Proxy handler
	proxyHandler := proxy.NewHandler(cfg, healthChecker)

	gateway := &APIGateway{
		config:        cfg,
		echo:          e,
		proxyHandler:  proxyHandler,
		healthChecker: healthChecker,
	}

	// Configurar rutas
	gateway.setupRoutes()

	return gateway, nil
}

func (gw *APIGateway) setupRoutes() {
	// Health check del gateway
	gw.echo.GET("/health", gw.healthCheck)
	gw.echo.GET("/health/services", gw.servicesHealth)
	gw.echo.GET("/metrics", gw.getMetrics)

	// Configurar servicios
	for _, service := range gw.config.Gateway.Services {
		gw.setupServiceRoutes(service)

		// Agregar al health checker si está habilitado
		if service.HealthCheck.Enabled {
			healthURL := service.BaseURL + service.HealthCheck.Endpoint
			interval := time.Duration(service.HealthCheck.IntervalSeconds) * time.Second
			gw.healthChecker.AddService(service.Name, healthURL, interval)
		}
	}
}

func (gw *APIGateway) setupServiceRoutes(service config.ServiceConfig) {
	group := gw.echo.Group(service.Prefix)

	// Aplicar middlewares del proxy handler
	gw.proxyHandler.ApplyMiddlewares(group, service)

	// Ruta principal del proxy
	group.Any("/*", func(c echo.Context) error {
		path := strings.TrimPrefix(c.Request().URL.Path, service.Prefix)
		if path == "" {
			path = "/"
		}
		return gw.proxyHandler.HandleProxy(service)(c)
	})
}

func (gw *APIGateway) healthCheck(c echo.Context) error {
	healthData := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"services":  len(gw.config.Gateway.Services),
		"version":   "1.0.0",
		"uptime":    time.Since(startTime).String(),
	}

	response := GatewayResponse{
		Data:         healthData,
		Success:      true,
		ErrorMessage: nil,
	}

	return c.JSON(200, response)
}

func (gw *APIGateway) servicesHealth(c echo.Context) error {
	healthStatus := make(map[string]interface{})
	allHealthy := true

	for _, service := range gw.config.Gateway.Services {
		if service.HealthCheck.Enabled {
			isHealthy := gw.healthChecker.IsHealthy(service.Name)
			if !isHealthy {
				allHealthy = false
			}
			healthStatus[service.Name] = map[string]interface{}{
				"healthy":    isHealthy,
				"last_check": gw.healthChecker.GetLastCheck(service.Name),
				"status":     getHealthStatus(isHealthy),
			}
		} else {
			healthStatus[service.Name] = map[string]interface{}{
				"healthy":      true,
				"health_check": "disabled",
				"status":       "unknown",
			}
		}
	}

	servicesData := map[string]interface{}{
		"services":       healthStatus,
		"timestamp":      time.Now().Format(time.RFC3339),
		"overall_status": getOverallStatus(allHealthy),
		"total_services": len(gw.config.Gateway.Services),
	}

	var errorMessage *string
	if !allHealthy {
		errorMsg := "Some services are not healthy"
		errorMessage = &errorMsg
	}

	response := GatewayResponse{
		Data:         servicesData,
		Success:      allHealthy,
		ErrorMessage: errorMessage,
	}

	return c.JSON(200, response)
}

func (gw *APIGateway) getMetrics(c echo.Context) error {
	// Obtener métricas del proxy handler
	proxyMetrics := gw.proxyHandler.GetMetrics()

	// Agregar métricas del gateway
	gatewayMetrics := map[string]interface{}{
		"uptime_seconds":  time.Since(startTime).Seconds(),
		"total_services":  len(gw.config.Gateway.Services),
		"gateway_version": "1.0.0",
		"timestamp":       time.Now().Format(time.RFC3339),
	}

	// Combinar métricas
	metricsData := map[string]interface{}{
		"gateway": gatewayMetrics,
		"proxy":   proxyMetrics,
	}

	response := GatewayResponse{
		Data:         metricsData,
		Success:      true,
		ErrorMessage: nil,
	}

	return c.JSON(200, response)
}

func (gw *APIGateway) Start() error {
	// Iniciar health checker
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	gw.healthChecker.Start(ctx)

	// Canal para recibir señales del sistema
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Iniciar servidor en goroutine
	go func() {
		port := gw.config.Gateway.Port
		if port == "" {
			port = "8000"
		}

		fmt.Printf("🚀 API Gateway starting on port %s\n", port)
		fmt.Println("📋 Configured services:")
		for _, service := range gw.config.Gateway.Services {
			fmt.Printf("  - %s: %s -> %s\n", service.Name, service.Prefix, service.BaseURL)
		}

		if err := gw.echo.Start(":" + port); err != nil {
			log.Printf("Server startup error: %v", err)
		}
	}()

	// Esperar señal de terminación
	<-quit
	fmt.Println("\n🛑 Shutting down API Gateway...")

	// Graceful shutdown
	ctx, cancel = context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := gw.echo.Shutdown(ctx); err != nil {
		return fmt.Errorf("server forced to shutdown: %w", err)
	}

	fmt.Println("✅ API Gateway stopped gracefully")
	return nil
}

var startTime = time.Now()

func getHealthStatus(healthy bool) string {
	if healthy {
		return "operational"
	}
	return "down"
}

func getOverallStatus(allHealthy bool) string {
	if allHealthy {
		return "all_systems_operational"
	}
	return "degraded_performance"
}

func main() {
	configPath := "config/config.json"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	gateway, err := NewAPIGateway(configPath)
	if err != nil {
		log.Fatal("Failed to create API Gateway:", err)
	}

	if err := gateway.Start(); err != nil {
		log.Fatal("Failed to start API Gateway:", err)
	}
}
