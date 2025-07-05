package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"api-gateway/config"

	"github.com/golang-jwt/jwt/v4"
	"github.com/labstack/echo/v4"
)

type AuthMiddleware struct {
	config *config.AuthConfig
}

type Claims struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

func NewAuthMiddleware(config *config.AuthConfig) *AuthMiddleware {
	return &AuthMiddleware{
		config: config,
	}
}

func (am *AuthMiddleware) JWTMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Si la autenticación está deshabilitada, continuar
			if !am.config.Enabled {
				return next(c)
			}

			// Obtener token del header Authorization
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return echo.NewHTTPError(http.StatusUnauthorized, "Authorization header required")
			}

			// Verificar formato Bearer
			if !strings.HasPrefix(authHeader, "Bearer ") {
				return echo.NewHTTPError(http.StatusUnauthorized, "Invalid authorization format")
			}

			// Extraer token
			tokenString := strings.TrimPrefix(authHeader, "Bearer ")
			if tokenString == "" {
				return echo.NewHTTPError(http.StatusUnauthorized, "Token is required")
			}

			// Validar token
			claims, err := am.validateToken(tokenString)
			if err != nil {
				return echo.NewHTTPError(http.StatusUnauthorized, fmt.Sprintf("Invalid token: %v", err))
			}

			// Almacenar claims en el contexto
			c.Set("user_id", claims.UserID)
			c.Set("username", claims.Username)
			c.Set("role", claims.Role)
			c.Set("claims", claims)

			return next(c)
		}
	}
}

func (am *AuthMiddleware) APIKeyMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Si la autenticación está deshabilitada, continuar
			if !am.config.Enabled {
				return next(c)
			}

			// Obtener API Key del header
			apiKey := c.Request().Header.Get("X-API-Key")
			if apiKey == "" {
				// Intentar obtener de query parameter
				apiKey = c.QueryParam("api_key")
			}

			if apiKey == "" {
				return echo.NewHTTPError(http.StatusUnauthorized, "API Key required")
			}

			// Validar API Key
			if !am.validateAPIKey(apiKey) {
				return echo.NewHTTPError(http.StatusUnauthorized, "Invalid API Key")
			}

			// Almacenar información en el contexto
			c.Set("api_key", apiKey)
			c.Set("auth_method", "api_key")

			return next(c)
		}
	}
}

func (am *AuthMiddleware) validateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Verificar método de firma
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(am.config.JWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		// Verificar expiración
		if claims.ExpiresAt != nil && claims.ExpiresAt.Time.Before(time.Now()) {
			return nil, fmt.Errorf("token has expired")
		}
		return claims, nil
	}

	return nil, fmt.Errorf("invalid token claims")
}

func (am *AuthMiddleware) validateAPIKey(apiKey string) bool {
	// API Keys válidas para tu proyecto
	validKeys := map[string]bool{
		"dev-key-lead-123":     true,
		"dev-key-captcha-456":  true,
		"prod-key-lead-789":    true,
		"prod-key-captcha-012": true,
		"admin-key-345":        true,
	}
	
	return validKeys[apiKey]
}

// Generar token JWT para testing
func (am *AuthMiddleware) GenerateToken(userID, username, role string) (string, error) {
	claims := &Claims{
		UserID:   userID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(am.config.TokenExpiry) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "api-gateway",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(am.config.JWTSecret))
}

// Middleware para roles específicos
func (am *AuthMiddleware) RequireRole(requiredRole string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			if !am.config.Enabled {
				return next(c)
			}

			role, ok := c.Get("role").(string)
			if !ok {
				return echo.NewHTTPError(http.StatusForbidden, "Role information not found")
			}

			if role != requiredRole && role != "admin" {
				return echo.NewHTTPError(http.StatusForbidden, fmt.Sprintf("Required role: %s", requiredRole))
			}

			return next(c)
		}
	}
}