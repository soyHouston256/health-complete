#!/bin/bash

# Script de inicio rápido para tu API Gateway
echo "🚀 Iniciando tu API Gateway personalizado..."
echo ""

# Verificar si Redis está corriendo
if ! docker ps | grep -q redis; then
    echo "📦 Iniciando Redis..."
    docker run -d -p 6379:6379 --name redis-gateway redis:alpine
    sleep 2
fi

# Compilar si es necesario
if [ ! -f "./api-gateway" ] || [ "main.go" -nt "./api-gateway" ]; then
    echo "🔨 Compilando API Gateway..."
    go build -o api-gateway
fi

echo "✅ Configuración lista!"
echo ""
echo "📋 Tu configuración:"
echo "  - Gateway: http://localhost:8001"
echo "  - Lead Service: /api/lead/* -> http://localhost:3000"
echo "  - Captcha Service: /api/recaptcha/* -> http://localhost:1323"
echo ""
echo "🚀 Iniciando gateway..."
echo "   (Presiona Ctrl+C para detener)"
echo ""

./api-gateway