# Makefile para API Gateway

# Variables
BINARY_NAME=api-gateway
DOCKER_IMAGE=api-gateway:latest
DOCKER_COMPOSE=docker-compose
GO_VERSION=1.21

# Colores para output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

.PHONY: help build run clean test deps docker-build docker-run docker-stop dev

# Comando por defecto
help: ## Mostrar ayuda
	@echo "$(BLUE)API Gateway - Comandos disponibles:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

# Desarrollo
deps: ## Instalar dependencias
	@echo "$(YELLOW)📦 Instalando dependencias...$(NC)"
	go mod download
	go mod tidy

build: ## Construir binario
	@echo "$(YELLOW)🔨 Construyendo aplicación...$(NC)"
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o $(BINARY_NAME) .
	@echo "$(GREEN)✅ Build completado: $(BINARY_NAME)$(NC)"

run: build ## Ejecutar aplicación
	@echo "$(YELLOW)🚀 Iniciando API Gateway...$(NC)"
	./$(BINARY_NAME)

dev: ## Ejecutar en modo desarrollo con hot reload
	@echo "$(YELLOW)🔥 Iniciando en modo desarrollo...$(NC)"
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "$(RED)❌ Air no está instalado. Instalando...$(NC)"; \
		go install github.com/cosmtrek/air@latest; \
		air; \
	fi

clean: ## Limpiar archivos generados
	@echo "$(YELLOW)🧹 Limpiando archivos...$(NC)"
	go clean
	rm -f $(BINARY_NAME)
	docker system prune -f
	@echo "$(GREEN)✅ Limpieza completada$(NC)"

# Testing
test: ## Ejecutar tests
	@echo "$(YELLOW)🧪 Ejecutando tests...$(NC)"
	go test -v ./...

test-coverage: ## Ejecutar tests con coverage
	@echo "$(YELLOW)📊 Ejecutando tests con coverage...$(NC)"
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✅ Coverage report: coverage.html$(NC)"

test-race: ## Ejecutar tests con race detector
	@echo "$(YELLOW)🏃 Ejecutando tests con race detector...$(NC)"
	go test -race -v ./...

benchmark: ## Ejecutar benchmarks
	@echo "$(YELLOW)⚡ Ejecutando benchmarks...$(NC)"
	go test -bench=. -benchmem ./...

# Docker
docker-build: ## Construir imagen Docker
	@echo "$(YELLOW)🐳 Construyendo imagen Docker...$(NC)"
	docker build -t $(DOCKER_IMAGE) .
	@echo "$(GREEN)✅ Imagen Docker construida: $(DOCKER_IMAGE)$(NC)"

docker-run: ## Ejecutar con Docker Compose
	@echo "$(YELLOW)🚀 Iniciando servicios con Docker Compose...$(NC)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✅ Servicios iniciados$(NC)"
	@echo "$(BLUE)📍 API Gateway: http://localhost:8080$(NC)"
	@echo "$(BLUE)📍 Redis Commander: http://localhost:8081$(NC)"

docker-stop: ## Detener servicios Docker
	@echo "$(YELLOW)🛑 Deteniendo servicios...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✅ Servicios detenidos$(NC)"

docker-logs: ## Ver logs de Docker Compose
	@echo "$(YELLOW)📋 Mostrando logs...$(NC)"
	$(DOCKER_COMPOSE) logs -f

docker-restart: ## Reiniciar servicios Docker
	@echo "$(YELLOW)🔄 Reiniciando servicios...$(NC)"
	$(DOCKER_COMPOSE) restart

# Servicios de ejemplo
example-services: ## Ejecutar servicios de ejemplo
	@echo "$(YELLOW)🎯 Iniciando servicios de ejemplo...$(NC)"
	@cd examples/services/user-service && go run main.go &
	@cd examples/services/order-service && go run main.go &
	@cd examples/services/payment-service && go run main.go &
	@echo "$(GREEN)✅ Servicios de ejemplo iniciados$(NC)"

stop-examples: ## Detener servicios de ejemplo
	@echo "$(YELLOW)🛑 Deteniendo servicios de ejemplo...$(NC)"
	@pkill -f "go run main.go" || true
	@echo "$(GREEN)✅ Servicios de ejemplo detenidos$(NC)"

# Herramientas
install-tools: ## Instalar herramientas de desarrollo
	@echo "$(YELLOW)🔧 Instalando herramientas...$(NC)"
	go install github.com/cosmtrek/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/rakyll/hey@latest
	@echo "$(GREEN)✅ Herramientas instaladas$(NC)"

lint: ## Ejecutar linter
	@echo "$(YELLOW)🔍 Ejecutando linter...$(NC)"
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	else \
		echo "$(RED)❌ golangci-lint no está instalado. Ejecuta: make install-tools$(NC)"; \
	fi

format: ## Formatear código
	@echo "$(YELLOW)💅 Formateando código...$(NC)"
	go fmt ./...
	@echo "$(GREEN)✅ Código formateado$(NC)"

# Pruebas de carga
load-test: ## Ejecutar prueba de carga básica
	@echo "$(YELLOW)⚡ Ejecutando prueba de carga...$(NC)"
	@if command -v hey > /dev/null; then \
		hey -n 1000 -c 10 http://localhost:8001/health; \
	else \
		echo "$(RED)❌ hey no está instalado. Ejecuta: make install-tools$(NC)"; \
	fi

load-test-auth: ## Prueba de carga con autenticación
	@echo "$(YELLOW)🔐 Ejecutando prueba de carga con auth...$(NC)"
	@if command -v hey > /dev/null; then \
		hey -n 1000 -c 10 -H "Authorization: Bearer test-token" http://localhost:8001/api/lead/; \
	else \
		echo "$(RED)❌ hey no está instalado. Ejecuta: make install-tools$(NC)"; \
	fi

# Monitoreo
health: ## Verificar salud del gateway
	@echo "$(YELLOW)🏥 Verificando salud del gateway...$(NC)"
	@curl -s http://localhost:8001/health | jq . || echo "$(RED)❌ Gateway no responde$(NC)"

health-services: ## Verificar salud de servicios
	@echo "$(YELLOW)🏥 Verificando salud de servicios...$(NC)"
	@curl -s http://localhost:8001/health/services | jq . || echo "$(RED)❌ No se pudo obtener estado de servicios$(NC)"

logs: ## Ver logs en tiempo real (requiere Docker)
	@echo "$(YELLOW)📋 Mostrando logs del gateway...$(NC)"
	$(DOCKER_COMPOSE) logs -f api-gateway

# Configuración
config-validate: ## Validar configuración
	@echo "$(YELLOW)✅ Validando configuración...$(NC)"
	@if [ -f config/config.json ]; then \
		cat config/config.json | jq . > /dev/null && echo "$(GREEN)✅ Configuración válida$(NC)"; \
	else \
		echo "$(RED)❌ Archivo config/config.json no encontrado$(NC)"; \
	fi

config-example: ## Crear configuración de ejemplo
	@echo "$(YELLOW)📝 Creando configuración de ejemplo...$(NC)"
	@cp config/config.json config/config.example.json
	@echo "$(GREEN)✅ Configuración de ejemplo creada: config/config.example.json$(NC)"

# Base de datos
redis-cli: ## Conectar a Redis CLI
	@echo "$(YELLOW)🔗 Conectando a Redis...$(NC)"
	docker exec -it $$(docker-compose ps -q redis) redis-cli

redis-flush: ## Limpiar cache de Redis
	@echo "$(YELLOW)🧹 Limpiando cache de Redis...$(NC)"
	docker exec -it $$(docker-compose ps -q redis) redis-cli FLUSHALL
	@echo "$(GREEN)✅ Cache limpiado$(NC)"

# Documentación
docs: ## Generar documentación
	@echo "$(YELLOW)📚 Generando documentación...$(NC)"
	@if command -v godoc > /dev/null; then \
		echo "$(BLUE)📍 Documentación disponible en: http://localhost:6060/pkg/api-gateway/$(NC)"; \
		godoc -http=:6060; \
	else \
		echo "$(RED)❌ godoc no está instalado$(NC)"; \
	fi

# Release
version: ## Mostrar información de versión
	@echo "$(BLUE)📋 Información de versión:$(NC)"
	@echo "Go version: $$(go version)"
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
	@echo "Build date: $$(date)"

# Todo en uno
all: clean deps build test ## Ejecutar pipeline completo

setup: deps install-tools ## Configuración inicial completa
	@echo "$(GREEN)🎉 Configuración inicial completada$(NC)"
	@echo "$(BLUE)📍 Ejecuta 'make dev' para iniciar en modo desarrollo$(NC)"
	@echo "$(BLUE)📍 Usa 'make test-services' para probar tus servicios$(NC)"

quick-start: docker-build docker-run ## Inicio rápido con Docker
	@echo "$(GREEN)🎉 API Gateway iniciado con Docker$(NC)"
	@echo "$(BLUE)📍 Gateway: http://localhost:8001$(NC)"
	@echo "$(BLUE)📍 Health: http://localhost:8001/health$(NC)"

# Comandos específicos para tus servicios
test-services: ## Probar tus servicios con formato estándar
	@echo "$(YELLOW)🧪 Probando servicios con formato estándar...$(NC)"
	@chmod +x examples/test_standard_format.sh
	@./examples/test_standard_format.sh

test-no-duplication: ## Verificar que NO hay duplicación en respuestas
	@echo "$(YELLOW)🔍 Verificando NO duplicación...$(NC)"
	@chmod +x examples/test_no_duplication.sh
	@./examples/test_no_duplication.sh

test-format: ## Verificar formato de respuesta estándar
	@echo "$(BLUE)🔍 Verificando formato de respuesta estándar...$(NC)"
	@echo "Health check:"
	@curl -s http://localhost:8001/health | jq '. | {success, data: .data.status, errorMessage}'
	@echo "Services health:"
	@curl -s http://localhost:8001/health/services | jq '. | {success, errorMessage}'

test-metrics: ## Ver métricas del gateway
	@echo "$(BLUE)📈 Obteniendo métricas del gateway...$(NC)"
	@curl -s http://localhost:8001/metrics | jq .

generate-token: ## Generar token JWT para testing
	@echo "$(YELLOW)🔐 Generando token JWT...$(NC)"
	@echo "Uso: make generate-token USER_ID=user123 USERNAME=john ROLE=user"
	@if [ -z "$(USER_ID)" ] || [ -z "$(USERNAME)" ] || [ -z "$(ROLE)" ]; then \
		echo "$(RED)❌ Faltan parámetros. Ejemplo:$(NC)"; \
		echo "make generate-token USER_ID=user123 USERNAME=john ROLE=user"; \
	else \
		cd examples && go run generate_token.go $(USER_ID) $(USERNAME) $(ROLE); \
	fi

test-lead: ## Test rápido del servicio Lead
	@echo "$(BLUE)🎯 Testing Lead service...$(NC)"
	@echo "Health check:"
	@curl -s -X GET http://localhost:8001/api/lead/health -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5
	@echo "Raíz:"
	@curl -s -X GET http://localhost:8001/api/lead/ -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5

test-captcha: ## Test rápido del servicio reCAPTCHA
	@echo "$(BLUE)🔒 Testing reCAPTCHA service...$(NC)"
	@curl -s -X GET http://localhost:8001/ms-validate-recaptcha/api/health -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5

enable-auth: ## Habilitar autenticación en el gateway
	@echo "$(YELLOW)🔐 Habilitando autenticación...$(NC)"
	@sed -i '' 's/"enabled": false/"enabled": true/' config/config.json
	@echo "$(GREEN)✅ Autenticación habilitada. Reinicia el gateway.$(NC)"

disable-auth: ## Deshabilitar autenticación en el gateway
	@echo "$(YELLOW)🔓 Deshabilitando autenticación...$(NC)"
	@sed -i '' 's/"enabled": true/"enabled": false/' config/config.json
	@echo "$(GREEN)✅ Autenticación deshabilitada. Reinicia el gateway.$(NC)"