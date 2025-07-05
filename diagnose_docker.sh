#!/bin/bash

echo "🐳 Diagnóstico completo: Ejecución directa vs Docker"
echo "======================================================"
echo ""

# Función para hacer requests con timeout y análisis detallado
make_request() {
    local url=$1
    local description=$2
    local expected_format=$3
    
    echo "📡 Probando $description"
    echo "   URL: $url"
    
    response=$(curl -s -w "HTTP_CODE:%{http_code}|TIME:%{time_total}" --max-time 10 "$url" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "   ❌ CONEXIÓN FALLIDA - No se pudo conectar"
        echo ""
        return
    fi
    
    http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    time_total=$(echo "$response" | grep -o "TIME:[0-9\.]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*|TIME:[0-9\.]*//')
    
    if [ "$http_code" = "200" ]; then
        echo "   ✅ SUCCESS (${time_total}s)"
        echo "   Response: $body"
        
        # Verificar formato si se especifica
        if [ "$expected_format" = "standard" ]; then
            if echo "$body" | jq -e '.data and .success and has("errorMessage")' >/dev/null 2>&1; then
                echo "   ✅ Formato estándar correcto"
            else
                echo "   ⚠️  Formato no estándar detectado"
            fi
        fi
    else
        echo "   ❌ FAILED (HTTP $http_code)"
        echo "   Response: $body"
    fi
    echo ""
}

echo "🏥 1. Health Checks - Microservicios individuales"
echo "================================================="
make_request "http://localhost:3000/health" "Lead Service (NestJS)" "basic"
make_request "http://localhost:8001/health" "Persona Service (Go)" "standard"
make_request "http://localhost:8002/health" "Poliza Service (FastAPI)" "standard"
make_request "http://localhost:6000/health" "Gestor Service (FastAPI)" "standard"
make_request "http://localhost:1323/recaptcha/health" "Recaptcha Service (Go)" "basic"

echo "🌐 2. API Gateway Health"
echo "========================"
make_request "http://localhost:8000/health" "Gateway Health" "standard"
make_request "http://localhost:8000/health/services" "Gateway Services Health" "standard"

echo "🔗 3. Proxy a través del API Gateway"
echo "====================================="
make_request "http://localhost:8000/leads/" "Leads Root" "standard"
make_request "http://localhost:8000/leads/health" "Leads Health via Gateway" "standard"
make_request "http://localhost:8000/personas/" "Personas Root" "standard"
make_request "http://localhost:8000/polizas/productos" "Polizas Productos" "standard"
make_request "http://localhost:8000/gestores/" "Gestores Root" "standard"

echo "🐳 4. Verificación de Docker"
echo "============================="
echo "📊 Estado de contenedores:"
docker-compose ps

echo ""
echo "🌐 Red Docker:"
docker network ls | grep pacifico

echo ""
echo "🔍 Logs recientes de servicios clave:"
echo ""
echo "--- API Gateway ---"
docker-compose logs --tail=5 api-gateway 2>/dev/null || echo "API Gateway no está ejecutándose"

echo ""
echo "--- MS Lead ---"
docker-compose logs --tail=5 ms-gestion-lead 2>/dev/null || echo "MS Lead no está ejecutándose"

echo ""
echo "📋 Health checks Docker Compose:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "🎯 Resumen del diagnóstico:"
echo "=========================="
echo "1. Si los microservicios individuales fallan → Problema de configuración Docker"
echo "2. Si el Gateway falla → Problema de configuración del Gateway"
echo "3. Si el proxy falla → Problema de routing/health checks"
echo ""
echo "💡 Comandos útiles:"
echo "   - Ver logs completos: docker-compose logs [servicio]"
echo "   - Reiniciar un servicio: docker-compose restart [servicio]"
echo "   - Rebuilding: docker-compose build [servicio]"
echo "   - Ver red: docker inspect pacifico_network"
