package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"api-gateway/config"

	"github.com/labstack/echo/v4"
	"golang.org/x/time/rate"
)

type RateLimiter struct {
	limiters map[string]*rate.Limiter
	mutex    sync.RWMutex
	config   config.RateLimitConfig
}

func NewRateLimiter(config config.RateLimitConfig) *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
		config:   config,
	}
}

func (rl *RateLimiter) RateLimitMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Si rate limiting está deshabilitado, continuar
			if !rl.config.Enabled {
				return next(c)
			}

			// Obtener identificador del cliente (IP + User Agent para más precisión)
			clientID := rl.getClientID(c)

			// Obtener o crear rate limiter para este cliente
			limiter := rl.getLimiter(clientID)

			// Verificar si puede procesar la request
			if !limiter.Allow() {
				// Calcular tiempo de espera hasta la próxima request permitida
				reservation := limiter.Reserve()
				delay := reservation.Delay()
				reservation.Cancel() // Cancelar la reserva ya que vamos a rechazar

				// Headers informativos
				c.Response().Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", rl.config.RequestsPerSecond))
				c.Response().Header().Set("X-RateLimit-Remaining", "0")
				c.Response().Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", time.Now().Add(delay).Unix()))
				c.Response().Header().Set("Retry-After", fmt.Sprintf("%.0f", delay.Seconds()))

				return echo.NewHTTPError(http.StatusTooManyRequests, map[string]interface{}{
					"error":       "Rate limit exceeded",
					"retry_after": fmt.Sprintf("%.2f seconds", delay.Seconds()),
					"limit":       rl.config.RequestsPerSecond,
				})
			}

			// Request permitida, agregar headers informativos
			remaining := rl.config.BurstSize - 1 // Aproximación
			c.Response().Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", rl.config.RequestsPerSecond))
			c.Response().Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			c.Response().Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", time.Now().Add(time.Minute).Unix()))

			return next(c)
		}
	}
}

func (rl *RateLimiter) getClientID(c echo.Context) string {
	// Prioridad: Usuario autenticado > IP + User-Agent > IP
	if userID, ok := c.Get("user_id").(string); ok && userID != "" {
		return "user:" + userID
	}

	ip := c.RealIP()
	userAgent := c.Request().UserAgent()

	// Usar hash simple para combinar IP y User-Agent
	return fmt.Sprintf("ip:%s:ua:%s", ip, userAgent[:min(len(userAgent), 50)])
}

func (rl *RateLimiter) getLimiter(clientID string) *rate.Limiter {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	limiter, exists := rl.limiters[clientID]
	if !exists {
		// Crear nuevo rate limiter para este cliente
		limiter = rate.NewLimiter(
			rate.Limit(rl.config.RequestsPerSecond),
			rl.config.BurstSize,
		)
		rl.limiters[clientID] = limiter
	}

	return limiter
}

// Limpiar rate limiters inactivos periódicamente
func (rl *RateLimiter) StartCleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	go func() {
		for range ticker.C {
			rl.cleanup()
		}
	}()
}

func (rl *RateLimiter) cleanup() {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	time.Now()
	for clientID, limiter := range rl.limiters {
		// Si el limiter permite el burst completo, probablemente no se ha usado recientemente
		if limiter.Tokens() == float64(rl.config.BurstSize) {
			// Verificar si no se ha usado en los últimos 10 minutos
			reservation := limiter.Reserve()
			if reservation.OK() && reservation.Delay() == 0 {
				delete(rl.limiters, clientID)
			}
			reservation.Cancel()
		}
	}
}

// Rate Limiter específico por endpoint
type EndpointRateLimiter struct {
	limiters map[string]*RateLimiter
	mutex    sync.RWMutex
}

func NewEndpointRateLimiter() *EndpointRateLimiter {
	return &EndpointRateLimiter{
		limiters: make(map[string]*RateLimiter),
	}
}

func (erl *EndpointRateLimiter) AddEndpoint(endpoint string, config config.RateLimitConfig) {
	erl.mutex.Lock()
	defer erl.mutex.Unlock()

	erl.limiters[endpoint] = NewRateLimiter(config)
}

func (erl *EndpointRateLimiter) EndpointRateLimitMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			endpoint := c.Request().Method + ":" + c.Path()

			erl.mutex.RLock()
			limiter, exists := erl.limiters[endpoint]
			erl.mutex.RUnlock()

			if exists {
				// Aplicar rate limiting específico del endpoint
				return limiter.RateLimitMiddleware()(next)(c)
			}

			// Si no hay configuración específica, continuar
			return next(c)
		}
	}
}

// Rate Limiter global con diferentes niveles
type TieredRateLimiter struct {
	global  *rate.Limiter
	premium *rate.Limiter
	basic   *rate.Limiter
}

func NewTieredRateLimiter(globalLimit, premiumLimit, basicLimit int) *TieredRateLimiter {
	return &TieredRateLimiter{
		global:  rate.NewLimiter(rate.Limit(globalLimit), globalLimit*2),
		premium: rate.NewLimiter(rate.Limit(premiumLimit), premiumLimit*2),
		basic:   rate.NewLimiter(rate.Limit(basicLimit), basicLimit*2),
	}
}

func (trl *TieredRateLimiter) TieredRateLimitMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Verificar límite global primero
			if !trl.global.Allow() {
				return echo.NewHTTPError(http.StatusTooManyRequests, "Global rate limit exceeded")
			}

			// Determinar tier del usuario
			tier := trl.getUserTier(c)

			var limiter *rate.Limiter
			switch tier {
			case "premium":
				limiter = trl.premium
			case "basic":
				limiter = trl.basic
			default:
				limiter = trl.basic
			}

			if !limiter.Allow() {
				return echo.NewHTTPError(http.StatusTooManyRequests,
					fmt.Sprintf("Rate limit exceeded for %s tier", tier))
			}

			return next(c)
		}
	}
}

func (trl *TieredRateLimiter) getUserTier(c echo.Context) string {
	// Implementar lógica para determinar el tier del usuario
	// Podría basarse en claims JWT, API key, base de datos, etc.
	if role, ok := c.Get("role").(string); ok {
		switch role {
		case "premium", "pro":
			return "premium"
		default:
			return "basic"
		}
	}
	return "basic"
}

func (rl *RateLimiter) getUserTier(c echo.Context) string {
	// Implementar lógica para determinar el tier del usuario
	// Podría basarse en claims JWT, API key, base de datos, etc.
	if role, ok := c.Get("role").(string); ok {
		switch role {
		case "premium", "pro":
			return "premium"
		default:
			return "basic"
		}
	}
	return "basic"
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
