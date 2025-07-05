#!/bin/bash

echo "🚨 PARCHE TEMPORAL: Desactivando verificación de health check"
echo "============================================================"
echo ""

echo "Este parche desactiva temporalmente la verificación de health check"
echo "en el proxy handler para que puedas probar el API Gateway mientras"
echo "diagnosticamos el problema del health checker."
echo ""

# Backup del archivo original
cp /Users/maxhoustonramirezmartel/code/personales/mcp-folder/api-gateway/proxy/handler.go /Users/maxhoustonramirezmartel/code/personales/mcp-folder/api-gateway/proxy/handler.go.backup

echo "✅ Backup creado: handler.go.backup"

# Crear el parche temporal
cat > /tmp/handler_patch.go << 'EOF'
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
EOF

echo "🔧 Aplicando parche temporal..."

# Usar sed para reemplazar la función getTargetURL
sed -i.tmp '/func (h \*Handler) getTargetURL/,/^}$/c\
func (h *Handler) getTargetURL(service config.ServiceConfig, c echo.Context) (string, error) {\
	var baseURL string\
\
	// Usar load balancer si está configurado\
	if lb, exists := h.loadBalancers[service.Name]; exists {\
		backend := lb.NextBackend()\
		if backend == "" {\
			return "", fmt.Errorf("no healthy backends available")\
		}\
		baseURL = backend\
	} else {\
		// PARCHE TEMPORAL: Comentando verificación de health check\
		// TODO: Diagnosticar por qué el health checker falla\
		/*\
		if service.HealthCheck.Enabled && !h.healthChecker.IsHealthy(service.Name) {\
			return "", fmt.Errorf("service %s is not healthy", service.Name)\
		}\
		*/\
		\
		// Log de diagnóstico\
		if service.HealthCheck.Enabled {\
			isHealthy := h.healthChecker.IsHealthy(service.Name)\
			fmt.Printf("[DEBUG] Service %s health check: enabled=%t, healthy=%t\\n", \
				service.Name, service.HealthCheck.Enabled, isHealthy)\
		}\
		\
		baseURL = service.BaseURL\
	}\
\
	// Construir URL completa - mejorado para NestJS\
	originalPath := c.Request().URL.Path\
	path := strings.TrimPrefix(originalPath, service.Prefix)\
\
	// Si el path queda vacío, significa que se accedió exactamente al prefix\
	if path == "" {\
		path = "/"\
	}\
\
	// Asegurar que el path empiece con /\
	if !strings.HasPrefix(path, "/") {\
		path = "/" + path\
	}\
\
	// Construir URL final\
	targetURL := baseURL + path\
	if c.Request().URL.RawQuery != "" {\
		targetURL += "?" + c.Request().URL.RawQuery\
	}\
\
	// Debug log mejorado\
	fmt.Printf("[PROXY] %s %s -> %s\\n", c.Request().Method, originalPath, targetURL)\
\
	return targetURL, nil\
}' /Users/maxhoustonramirezmartel/code/personales/mcp-folder/api-gateway/proxy/handler.go

echo "✅ Parche aplicado"
echo ""
echo "🔄 Rebuild y restart del API Gateway..."
cd /Users/maxhoustonramirezmartel/code/personales/mcp-folder
docker-compose build api-gateway
docker-compose restart api-gateway

echo ""
echo "⏳ Esperando que el gateway esté listo..."
sleep 10

echo ""
echo "🧪 Probando el API Gateway con el parche:"
curl -s http://localhost:8000/leads/ | jq '.' 2>/dev/null && echo "✅ Parche funcionando" || echo "❌ Aún hay problemas"

echo ""
echo "📋 IMPORTANTE:"
echo "1. Este es un PARCHE TEMPORAL para diagnosticar"
echo "2. Ahora deberías poder hacer requests a través del gateway"
echo "3. Los logs mostrarán información de debug del health checker"
echo "4. Para revertir: cp handler.go.backup handler.go"
echo ""
echo "🔍 Siguiente paso: Ejecutar './debug_health_check.sh' para diagnosticar"
echo "    el problema real del health checker"
