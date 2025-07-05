#!/bin/bash

# Quick Start Script para API Gateway
# Este script configura e inicia todo el entorno

echo "🚀 API Gateway - Quick Start"
echo "============================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar prerequisitos
echo -e "${BLUE}📋 Verificando prerequisitos...${NC}"

if ! command_exists go; then
    echo -e "${RED}❌ Go no está instalado. Instala Go 1.21+ desde https://golang.org/dl/${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker no está instalado. Instala Docker desde https://docker.com${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose no está instalado.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisitos verificados${NC}"
echo ""

# Opción de instalación
echo -e "${YELLOW}🤔 ¿Cómo quieres ejecutar el API Gateway?${NC}"
echo "1) Docker Compose (Recomendado - Todo automatizado)"
echo "2) Local Development (Go + Redis manual)"
echo "3) Solo instalar dependencias"
echo ""
read -p "Selecciona una opción (1-3): " choice

case $choice in
    1)
        echo -e "${BLUE}🐳 Ejecutando con Docker Compose...${NC}"
        echo ""
        
        # Construir y ejecutar con Docker Compose
        echo "📦 Construyendo imágenes..."
        docker-compose build
        
        echo "🚀 Iniciando servicios..."
        docker-compose up -d
        
        echo ""
        echo -e "${GREEN}✅ API Gateway iniciado con Docker Compose!${NC}"
        echo ""
        echo -e "${BLUE}📍 Endpoints disponibles:${NC}"
        echo "  - API Gateway: http://localhost:8080"
        echo "  - Gateway Health: http://localhost:8080/health"
        echo "  - Services Health: http://localhost:8080/health/services"
        echo "  - Redis Commander: http://localhost:8081"
        echo ""
        echo -e "${BLUE}🧪 Para probar el gateway:${NC}"
        echo "  chmod +x examples/requests/test_gateway.sh"
        echo "  ./examples/requests/test_gateway.sh"
        echo ""
        echo -e "${BLUE}📋 Para ver logs:${NC}"
        echo "  docker-compose logs -f api-gateway"
        echo ""
        echo -e "${BLUE}🛑 Para detener:${NC}"
        echo "  docker-compose down"
        ;;
    
    2)
        echo -e "${BLUE}💻 Configurando desarrollo local...${NC}"
        echo ""
        
        # Instalar dependencias
        echo "📦 Instalando dependencias de Go..."
        go mod tidy
        
        # Verificar Redis
        if ! docker ps | grep -q redis; then
            echo "🔧 Iniciando Redis con Docker..."
            docker run -d -p 6379:6379 --name redis-gateway redis:alpine
        else
            echo "✅ Redis ya está ejecutándose"
        fi
        
        # Iniciar servicios de ejemplo en background
        echo "🎯 Iniciando servicios de ejemplo..."
        
        cd examples/services/user-service
        go mod tidy
        go run main.go &
        USER_PID=$!
        cd ../../..
        
        cd examples/services/order-service
        go mod tidy
        go run main.go &
        ORDER_PID=$!
        cd ../../..
        
        cd examples/services/payment-service
        go mod tidy
        go run main.go &
        PAYMENT_PID=$!
        cd ../../..
        
        echo "⏳ Esperando que los servicios inicien..."
        sleep 5
        
        # Iniciar API Gateway
        echo "🚀 Iniciando API Gateway..."
        go run main.go &
        GATEWAY_PID=$!
        
        echo ""
        echo -e "${GREEN}✅ Entorno de desarrollo iniciado!${NC}"
        echo ""
        echo -e "${BLUE}📍 Servicios ejecutándose:${NC}"
        echo "  - API Gateway: http://localhost:8080 (PID: $GATEWAY_PID)"
        echo "  - User Service: http://localhost:3001 (PID: $USER_PID)"
        echo "  - Order Service: http://localhost:3002 (PID: $ORDER_PID)"
        echo "  - Payment Service: http://localhost:3003 (PID: $PAYMENT_PID)"
        echo "  - Redis: http://localhost:6379"
        echo ""
        echo -e "${BLUE}🛑 Para detener todos los servicios:${NC}"
        echo "  kill $GATEWAY_PID $USER_PID $ORDER_PID $PAYMENT_PID"
        echo "  docker stop redis-gateway"
        ;;
    
    3)
        echo -e "${BLUE}📦 Instalando dependencias...${NC}"
        echo ""
        
        # Instalar dependencias del gateway
        echo "🔧 Instalando dependencias del API Gateway..."
        go mod tidy
        
        # Instalar dependencias de servicios de ejemplo
        echo "🔧 Instalando dependencias de servicios de ejemplo..."
        cd examples/services/user-service && go mod tidy && cd ../../..
        cd examples/services/order-service && go mod tidy && cd ../../..
        cd examples/services/payment-service && go mod tidy && cd ../../..
        
        # Instalar herramientas de desarrollo
        echo "🛠️  Instalando herramientas de desarrollo..."
        go install github.com/cosmtrek/air@latest
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
        
        echo ""
        echo -e "${GREEN}✅ Dependencias instaladas!${NC}"
        echo ""
        echo -e "${BLUE}📝 Próximos pasos:${NC}"
        echo "  1. Inicia Redis: docker run -d -p 6379:6379 redis:alpine"
        echo "  2. Inicia servicios: make example-services"
        echo "  3. Inicia gateway: make dev"
        echo "  4. Prueba: ./examples/requests/test_gateway.sh"
        ;;
    
    *)
        echo -e "${RED}❌ Opción inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}💡 Tips útiles:${NC}"
echo "  - Usa 'make help' para ver todos los comandos disponibles"
echo "  - Edita 'config/config.json' para personalizar la configuración"
echo "  - Los servicios de ejemplo tienen comportamientos aleatorios para testing"
echo "  - Verifica los logs para ver rate limiting y circuit breakers en acción"
echo ""
echo -e "${GREEN}🎉 ¡Disfruta usando el API Gateway!${NC}"