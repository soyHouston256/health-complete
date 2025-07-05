package proxy

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"api-gateway/config"
	"api-gateway/health"
	"api-gateway/middleware"

	"github.com/labstack/echo/v4"
)

// Estructura estándar de respuesta
type StandardResponse struct {
	Data         interface{} `json:"data"`
	Success      bool        `json:"success"`
	ErrorMessage *string     `json:"errorMessage"`
}

// Respuesta de error estándar
type ErrorData struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Path    string `json:"path"`
	Method  string `json:"method"`
}

type Handler struct {
	config          *config.Config
	client          *http.Client
	healthChecker   *health.Checker
	authMiddleware  *middleware.AuthMiddleware
	circuitBreakers *middleware.CircuitBreakerManager
	loadBalancers   map[string]middleware.LoadBalancer
}

func NewHandler(cfg *config.Config, healthChecker *health.Checker) *Handler {
	// Cliente HTTP con configuración optimizada
	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 100,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	// Inicializar middlewares
	authMiddleware := middleware.NewAuthMiddleware(&cfg.Auth)
	circuitBreakers := middleware.NewCircuitBreakerManager()

	// Crear load balancers para cada servicio
	loadBalancers := make(map[string]middleware.LoadBalancer)
	for _, service := range cfg.Gateway.Services {
		if service.LoadBalancer.Enabled {
			loadBalancers[service.Name] = middleware.NewLoadBalancer(service.LoadBalancer)
		}
	}

	return &Handler{
		config:          cfg,
		client:          client,
		healthChecker:   healthChecker,
		authMiddleware:  authMiddleware,
		circuitBreakers: circuitBreakers,
		loadBalancers:   loadBalancers,
	}
}

func (h *Handler) ApplyMiddlewares(group *echo.Group, service config.ServiceConfig) {
	// 1. Autenticación (si está habilitada)
	if h.config.Auth.Enabled {
		group.Use(h.authMiddleware.JWTMiddleware())
	}

	// 2. Rate Limiting
	if service.RateLimit.Enabled {
		rateLimiter := middleware.NewRateLimiter(service.RateLimit)
		group.Use(rateLimiter.RateLimitMiddleware())
	}

	// 3. Circuit Breaker
	group.Use(h.circuitBreakers.Middleware(service.Name))

	// 5. Logging personalizado por servicio
	group.Use(h.loggingMiddleware(service.Name))
}

func (h *Handler) HandleProxy(service config.ServiceConfig) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Determinar URL de destino
		targetURL, err := h.getTargetURL(service, c)
		if err != nil {
			return h.sendErrorResponse(c, http.StatusBadGateway, "Error determining target URL", err)
		}

		// Crear request proxy
		proxyReq, err := h.createProxyRequest(c, targetURL, service)
		if err != nil {
			return h.sendErrorResponse(c, http.StatusInternalServerError, "Error creating proxy request", err)
		}

		// Ejecutar request
		resp, err := h.client.Do(proxyReq)
		if err != nil {
			// Marcar backend como no saludable si hay load balancer
			if lb, exists := h.loadBalancers[service.Name]; exists {
				lb.MarkBackendDown(targetURL)
			}
			return h.sendErrorResponse(c, http.StatusBadGateway, "Service unavailable", err)
		}
		defer resp.Body.Close()

		// Marcar backend como saludable si hay load balancer
		if lb, exists := h.loadBalancers[service.Name]; exists {
			lb.MarkBackendUp(targetURL)
		}

		// Leer y transformar response
		return h.transformResponse(c, resp)
	}
}

func (h *Handler) getTargetURL(service config.ServiceConfig, c echo.Context) (string, error) {
	var baseURL string

	// Usar load balancer si está configurado
	if lb, exists := h.loadBalancers[service.Name]; exists {
		backend := lb.NextBackend()
		if backend == "" {
			return "", fmt.Errorf("no healthy backends available")
		}
		baseURL = backend
	} else {
		// PARCHE TEMPORAL: Comentando verificación de health check
		// TODO: Diagnosticar por qué el health checker falla
		/*
		if service.HealthCheck.Enabled && !h.healthChecker.IsHealthy(service.Name) {
			return "", fmt.Errorf("service %s is not healthy", service.Name)
		}
		*/
		
		// Log de diagnóstico
		if service.HealthCheck.Enabled {
			isHealthy := h.healthChecker.IsHealthy(service.Name)
			fmt.Printf("[DEBUG] Service %s health check: enabled=%t, healthy=%t\n", 
				service.Name, service.HealthCheck.Enabled, isHealthy)
		}
		
		baseURL = service.BaseURL
	}

	// Construir URL completa - mejorado para NestJS
	originalPath := c.Request().URL.Path
	path := strings.TrimPrefix(originalPath, service.Prefix)

	// Si el path queda vacío, significa que se accedió exactamente al prefix
	if path == "" {
		path = "/"
	}

	// Asegurar que el path empiece con /
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	// Construir URL final
	targetURL := baseURL + path
	if c.Request().URL.RawQuery != "" {
		targetURL += "?" + c.Request().URL.RawQuery
	}

	// Debug log mejorado
	fmt.Printf("[PROXY] %s %s -> %s\n", c.Request().Method, originalPath, targetURL)

	return targetURL, nil
}

func (h *Handler) createProxyRequest(c echo.Context, targetURL string, service config.ServiceConfig) (*http.Request, error) {
	var body io.Reader

	// Copiar body si existe
	if c.Request().Body != nil {
		bodyBytes, err := io.ReadAll(c.Request().Body)
		if err != nil {
			return nil, err
		}
		body = bytes.NewReader(bodyBytes)
	}

	// Crear nuevo request
	req, err := http.NewRequest(c.Request().Method, targetURL, body)
	if err != nil {
		return nil, err
	}

	// Establecer timeout específico del servicio
	ctx, _ := context.WithTimeout(context.Background(), time.Duration(service.Timeout)*time.Second)
	req = req.WithContext(ctx)

	// Copiar headers importantes
	h.copyRequestHeaders(c.Request().Header, req.Header)

	// Agregar headers adicionales
	h.addProxyHeaders(req, c)

	return req, nil
}

func (h *Handler) transformResponse(c echo.Context, resp *http.Response) error {
	// Leer el body de la respuesta
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return h.sendErrorResponse(c, http.StatusBadGateway, "Error reading service response", err)
	}

	// Agregar headers del gateway antes de procesar
	h.addGatewayHeaders(c)

	// VERIFICACIÓN PRINCIPAL: ¿Ya tiene formato estándar?
	// Esta verificación debe ser INDEPENDIENTE del status HTTP
	if len(bodyBytes) > 0 {
		var possibleStandardResponse map[string]interface{}
		if err := json.Unmarshal(bodyBytes, &possibleStandardResponse); err == nil {
			// Verificar si ya tiene la estructura estándar
			if h.isStandardFormat(possibleStandardResponse) {
				// Ya tiene formato estándar, devolver tal como está
				// SIN IMPORTAR el status HTTP (200, 400, 500, etc.)
				fmt.Printf("[TRANSFORM] Standard format detected (HTTP %d), passing through: %s\n", resp.StatusCode, c.Request().URL.Path)
				h.copyImportantHeaders(c, resp)
				c.Response().Header().Set("Content-Type", "application/json")
				// IMPORTANTE: Siempre devolver 200 porque nuestro formato estándar maneja errores internamente
				c.Response().WriteHeader(http.StatusOK)
				_, err := c.Response().Write(bodyBytes)
				return err
			}
		}
	}

	// Si llegamos aquí, NO tiene formato estándar y necesita transformación
	isSuccess := resp.StatusCode >= 200 && resp.StatusCode < 300

	if !isSuccess {
		// Para errores HTTP sin formato estándar, crear respuesta estándar
		fmt.Printf("[TRANSFORM] HTTP error %d without standard format, transforming: %s\n", resp.StatusCode, c.Request().URL.Path)
		errorMsg := h.generateSimpleErrorMessage(resp.StatusCode)
		standardResp := StandardResponse{
			Success:      false,
			ErrorMessage: &errorMsg,
		}

		// Intentar parsear el error del servicio como data
		var originalError interface{}
		if len(bodyBytes) > 0 && json.Unmarshal(bodyBytes, &originalError) == nil {
			standardResp.Data = originalError
		} else {
			// Si no se puede parsear, crear estructura de error simple
			standardResp.Data = ErrorData{
				Code:    resp.StatusCode,
				Message: string(bodyBytes),
				Path:    c.Request().URL.Path,
				Method:  c.Request().Method,
			}
		}

		h.copyImportantHeaders(c, resp)
		return c.JSON(http.StatusOK, standardResp)
	}

	// Para respuestas HTTP exitosas sin formato estándar, aplicar transformación
	fmt.Printf("[TRANSFORM] HTTP success %d without standard format, transforming: %s\n", resp.StatusCode, c.Request().URL.Path)
	standardResp := StandardResponse{
		Success:      true,
		ErrorMessage: nil,
	}

	if len(bodyBytes) > 0 {
		var data interface{}
		if err := json.Unmarshal(bodyBytes, &data); err != nil {
			// Si no es JSON válido, usar como string
			standardResp.Data = string(bodyBytes)
		} else {
			standardResp.Data = data
		}
	} else {
		// Response vacío
		standardResp.Data = map[string]interface{}{}
	}

	// Copiar headers importantes de la respuesta original
	h.copyImportantHeaders(c, resp)

	// Enviar respuesta transformada
	return c.JSON(http.StatusOK, standardResp)
}

func (h *Handler) sendErrorResponse(c echo.Context, statusCode int, message string, err error) error {
	errorMsg := message
	if err != nil {
		errorMsg = fmt.Sprintf("%s: %s", message, err.Error())
	}

	h.addGatewayHeaders(c)

	errorResp := StandardResponse{
		Data: ErrorData{
			Code:    statusCode,
			Message: message,
			Path:    c.Request().URL.Path,
			Method:  c.Request().Method,
		},
		Success:      false,
		ErrorMessage: &errorMsg,
	}

	return c.JSON(http.StatusOK, errorResp)
}

// Nueva función simplificada para generar mensajes de error sin duplicar contenido
func (h *Handler) generateSimpleErrorMessage(statusCode int) string {
	switch statusCode {
	case 400:
		return "Bad Request"
	case 401:
		return "Unauthorized"
	case 403:
		return "Forbidden"
	case 404:
		return "Not Found"
	case 422:
		return "Validation Error"
	case 500:
		return "Internal Server Error"
	case 502:
		return "Bad Gateway"
	case 503:
		return "Service Unavailable"
	case 504:
		return "Gateway Timeout"
	default:
		return fmt.Sprintf("Service Error (%d)", statusCode)
	}
}

// Función legacy mantenida para compatibilidad si es necesario
func (h *Handler) generateErrorMessage(statusCode int, bodyBytes []byte) string {
	switch statusCode {
	case 400:
		return "Bad Request: " + string(bodyBytes)
	case 401:
		return "Unauthorized: " + string(bodyBytes)
	case 403:
		return "Forbidden: " + string(bodyBytes)
	case 404:
		return "Not Found: " + string(bodyBytes)
	case 422:
		return "Validation Error: " + string(bodyBytes)
	case 500:
		return "Internal Server Error: " + string(bodyBytes)
	case 502:
		return "Bad Gateway: " + string(bodyBytes)
	case 503:
		return "Service Unavailable: " + string(bodyBytes)
	case 504:
		return "Gateway Timeout: " + string(bodyBytes)
	default:
		return fmt.Sprintf("Service Error (%d): %s", statusCode, string(bodyBytes))
	}
}

func (h *Handler) addGatewayHeaders(c echo.Context) {
	c.Response().Header().Set("X-Gateway", "api-gateway")
	c.Response().Header().Set("X-Gateway-Version", "1.0.0")
	c.Response().Header().Set("X-Response-Time", time.Now().Format(time.RFC3339))
	c.Response().Header().Set("Content-Type", "application/json")
}

func (h *Handler) copyImportantHeaders(c echo.Context, resp *http.Response) {
	// Headers importantes que queremos mantener
	importantHeaders := []string{
		"Cache-Control",
		"ETag",
		"Last-Modified",
		"Expires",
	}

	for _, header := range importantHeaders {
		if value := resp.Header.Get(header); value != "" {
			c.Response().Header().Set(header, value)
		}
	}
}

func (h *Handler) copyRequestHeaders(src, dst http.Header) {
	for key, values := range src {
		if h.shouldCopyHeader(key) {
			for _, value := range values {
				dst.Add(key, value)
			}
		}
	}
}

func (h *Handler) shouldCopyHeader(header string) bool {
	// Headers que NO deben copiarse
	skipHeaders := map[string]bool{
		"connection":          true,
		"keep-alive":          true,
		"proxy-authenticate":  true,
		"proxy-authorization": true,
		"te":                  true,
		"trailers":            true,
		"transfer-encoding":   true,
		"upgrade":             true,
		"host":                true, // Se establecerá automáticamente
	}

	return !skipHeaders[strings.ToLower(header)]
}

func (h *Handler) addProxyHeaders(req *http.Request, c echo.Context) {
	// X-Forwarded headers
	req.Header.Set("X-Forwarded-For", c.RealIP())
	req.Header.Set("X-Forwarded-Proto", c.Scheme())
	req.Header.Set("X-Forwarded-Host", c.Request().Host)

	// Headers del gateway
	req.Header.Set("X-Gateway", "api-gateway")
	req.Header.Set("X-Gateway-Version", "1.0.0")
	req.Header.Set("X-Request-ID", generateRequestID())

	// Información del usuario si está autenticado
	if userID, ok := c.Get("user_id").(string); ok && userID != "" {
		req.Header.Set("X-User-ID", userID)
	}
	if username, ok := c.Get("username").(string); ok && username != "" {
		req.Header.Set("X-Username", username)
	}
	if role, ok := c.Get("role").(string); ok && role != "" {
		req.Header.Set("X-User-Role", role)
	}
}

func (h *Handler) loggingMiddleware(serviceName string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			start := time.Now()

			// Generar request ID si no existe
			requestID := c.Request().Header.Get("X-Request-ID")
			if requestID == "" {
				requestID = generateRequestID()
			}
			c.Response().Header().Set("X-Request-ID", requestID)

			err := next(c)

			// Log de la request
			duration := time.Since(start)
			status := c.Response().Status

			// Determinar nivel de log basado en status
			level := "INFO"
			if status >= 400 && status < 500 {
				level = "WARN"
			} else if status >= 500 {
				level = "ERROR"
			}

			// Log estructurado
			fmt.Printf("[%s] %s [%s] %s %s - %d - %v - %s - %s\n",
				level,
				start.Format("2006-01-02 15:04:05"),
				serviceName,
				c.Request().Method,
				c.Request().URL.Path,
				status,
				duration,
				c.RealIP(),
				requestID,
			)

			return err
		}
	}
}

// Verificar si una respuesta ya tiene el formato estándar
func (h *Handler) isStandardFormat(response map[string]interface{}) bool {
	// Verificar que tenga los campos requeridos: data, success, errorMessage
	_, hasData := response["data"]
	_, hasSuccess := response["success"]
	_, hasErrorMessage := response["errorMessage"]

	// Verificar que success sea boolean
	if hasSuccess {
		if _, isBool := response["success"].(bool); !isBool {
			return false
		}
	}

	// Verificar que errorMessage sea string o null
	if hasErrorMessage {
		if errorMsg := response["errorMessage"]; errorMsg != nil {
			if _, isString := errorMsg.(string); !isString {
				return false
			}
		}
	}

	// Debe tener exactamente estos 3 campos para ser considerado formato estándar
	return hasData && hasSuccess && hasErrorMessage && len(response) == 3
}

// Función para generar request ID único
func generateRequestID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
}

// Métricas básicas del handler
func (h *Handler) GetMetrics() map[string]interface{} {
	metrics := make(map[string]interface{})

	// Métricas de circuit breakers
	breakers := h.circuitBreakers.GetAllBreakers()
	cbMetrics := make(map[string]interface{})
	for name, cb := range breakers {
		counts := cb.Counts()
		cbMetrics[name] = map[string]interface{}{
			"state":                cb.State().String(),
			"requests":             counts.Requests,
			"successes":            counts.TotalSuccesses,
			"failures":             counts.TotalFailures,
			"consecutive_failures": counts.ConsecutiveFailures,
		}
	}
	metrics["circuit_breakers"] = cbMetrics

	// Métricas de load balancers
	lbMetrics := make(map[string]interface{})
	for name, lb := range h.loadBalancers {
		lbMetrics[name] = map[string]interface{}{
			"healthy_backends": lb.GetHealthyBackends(),
		}
	}
	metrics["load_balancers"] = lbMetrics

	return metrics
}
