#!/bin/bash

echo "🔧 Verificando las correcciones del API Gateway..."
echo ""

# Función para hacer requests con timeout
make_request() {
    local url=$1
    local description=$2
    echo "📡 Probando $description: $url"
    
    response=$(curl -s -w "HTTP_CODE:%{http_code}" --max-time 10 "$url")
    http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    if [ "$http_code" = "200" ]; then
        echo "✅ SUCCESS - $description"
        echo "   Response: $body"
    else
        echo "❌ FAILED - $description (HTTP $http_code)"
        echo "   Response: $body"
    fi
    echo ""
}

echo "🏥 1. Verificando health checks directos de microservicios..."
make_request "http://localhost:3000/health" "Lead Service Health"
make_request "http://localhost:8001/health" "Persona Service Health"
make_request "http://localhost:8002/health" "Poliza Service Health"
make_request "http://localhost:6000/health" "Gestor Service Health"
make_request "http://localhost:1323/recaptcha/health" "Recaptcha Service Health"

echo "🌐 2. Verificando API Gateway health..."
make_request "http://localhost:8000/health" "API Gateway Health"
make_request "http://localhost:8000/health/services" "API Gateway Services Health"

echo "🔗 3. Verificando proxy a través del API Gateway..."
make_request "http://localhost:8000/leads/" "Leads through Gateway"
make_request "http://localhost:8000/personas/" "Personas through Gateway"
make_request "http://localhost:8000/polizas/productos" "Polizas through Gateway"
make_request "http://localhost:8000/gestores/" "Gestores through Gateway"

echo "📊 4. Verificando métricas..."
make_request "http://localhost:8000/metrics" "Gateway Metrics"

echo ""
echo "🎯 Verificación completada!"
echo "💡 Si hay servicios no saludables, asegúrate de que todos los contenedores estén ejecutándose:"
echo "   docker-compose ps"
echo ""
echo "🐛 Para revisar logs del API Gateway:"
echo "   docker-compose logs api-gateway"
