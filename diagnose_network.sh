#!/bin/bash

echo "🌐 DIAGNÓSTICO COMPLETO DE CONFIGURACIÓN DE RED DOCKER"
echo "======================================================="
echo ""

echo "📋 1. VERIFICACIÓN DE CONFIGURACIÓN DE RED EN DOCKER-COMPOSE"
echo "=============================================================="

echo "✅ Servicios configurados en pacifico_network:"
grep -A 1 "networks:" /Users/maxhoustonramirezmartel/code/personales/mcp-folder/docker-compose.yml | grep -E "(networks:|pacifico_network)" | wc -l
echo ""

echo "📊 Red configurada:"
grep -A 4 "networks:" /Users/maxhoustonramirezmartel/code/personales/mcp-folder/docker-compose.yml | tail -4
echo ""

echo "📋 2. ESTADO ACTUAL DE LA RED DOCKER"
echo "====================================="

echo "Redes Docker existentes:"
docker network ls | grep pacifico || echo "❌ Red pacifico no encontrada"
echo ""

echo "Información detallada de la red:"
NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep pacifico | head -1)
if [ -n "$NETWORK_NAME" ]; then
    echo "Red encontrada: $NETWORK_NAME"
    docker network inspect "$NETWORK_NAME" | jq -r '.[0] | {
        Name: .Name,
        Driver: .Driver,
        Subnet: .IPAM.Config[0].Subnet,
        Gateway: .IPAM.Config[0].Gateway
    }' 2>/dev/null || echo "Información básica de red disponible"
else
    echo "❌ No se encontró la red pacifico"
fi
echo ""

echo "📋 3. CONTENEDORES EN LA RED"
echo "============================"

echo "Contenedores activos en la red pacifico:"
if [ -n "$NETWORK_NAME" ]; then
    docker network inspect "$NETWORK_NAME" | jq -r '.[0].Containers | to_entries[] | "\(.value.Name) - \(.value.IPv4Address)"' 2>/dev/null || docker network inspect "$NETWORK_NAME" | grep -A 10 "Containers"
else
    echo "❌ No se puede inspeccionar - red no existe"
fi
echo ""

echo "📋 4. VERIFICACIÓN DE CONTENEDORES INDIVIDUALES"
echo "================================================"

echo "Estado de todos los contenedores del proyecto:"
docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"
echo ""

echo "📋 5. PRUEBAS DE CONECTIVIDAD ENTRE CONTENEDORES"
echo "================================================="

echo "🔍 Probando conectividad desde API Gateway a cada microservicio:"
echo ""

# Función para probar conectividad
test_connectivity() {
    local service_name=$1
    local target_url=$2
    local description=$3
    
    echo "Testing $description ($service_name -> $target_url):"
    
    # Verificar que el contenedor existe y está ejecutándose
    if ! docker-compose ps $service_name | grep -q "Up"; then
        echo "  ❌ Contenedor $service_name no está ejecutándose"
        return
    fi
    
    # Prueba de ping
    echo -n "  Ping: "
    if docker-compose exec -T api-gateway ping -c 1 -W 2 ${target_url%:*} >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
    fi
    
    # Prueba de conectividad HTTP
    echo -n "  HTTP: "
    if docker-compose exec -T api-gateway curl -s --max-time 5 "$target_url" >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
    fi
    
    echo ""
}

# Verificar que api-gateway esté ejecutándose
if docker-compose ps api-gateway | grep -q "Up"; then
    test_connectivity "ms-gestion-lead" "http://ms-gestion-lead:3000/health" "Lead Service"
    test_connectivity "ms-gestion-persona" "http://ms-gestion-persona:8001/health" "Persona Service" 
    test_connectivity "ms-gestion-poliza" "http://ms-gestion-poliza:8002/health" "Poliza Service"
    test_connectivity "ms-gestion-gestor" "http://ms-gestion-gestor:6000/health" "Gestor Service"
    test_connectivity "ms-validar-recaptcha" "http://ms-validar-recaptcha:1323/recaptcha/health" "Recaptcha Service"
else
    echo "❌ API Gateway no está ejecutándose, no se pueden hacer pruebas de conectividad"
fi

echo "📋 6. VERIFICACIÓN DE CONFIGURACIÓN DE HEALTH CHECK URLs"
echo "=========================================================="

echo "URLs configuradas en config.json vs URLs esperadas:"
echo ""

if docker-compose exec -T api-gateway test -f config/config.json; then
    echo "✅ config.json existe"
    echo ""
    echo "Health check URLs configuradas:"
    docker-compose exec -T api-gateway cat config/config.json | jq -r '.gateway.services[] | "\(.name): \(.base_url)\(.health_check.endpoint)"' 2>/dev/null || echo "❌ No se puede leer config.json"
else
    echo "❌ config.json no encontrado"
fi
echo ""

echo "📋 7. VERIFICACIÓN DE RESOLUCIÓN DNS"
echo "====================================="

echo "Probando resolución DNS desde API Gateway:"
services=("ms-gestion-lead" "ms-gestion-persona" "ms-gestion-poliza" "ms-gestion-gestor" "ms-validar-recaptcha" "mysql" "postgres")

for service in "${services[@]}"; do
    echo -n "$service: "
    if docker-compose exec -T api-gateway nslookup "$service" >/dev/null 2>&1; then
        echo "✅ Resuelve"
    else
        echo "❌ No resuelve"
    fi
done
echo ""

echo "📋 8. VERIFICACIÓN DE PUERTOS INTERNOS"
echo "======================================"

echo "Probando conectividad a puertos específicos desde API Gateway:"
port_tests=(
    "ms-gestion-lead:3000"
    "ms-gestion-persona:8001"
    "ms-gestion-poliza:8002"
    "ms-gestion-gestor:6000"
    "ms-validar-recaptcha:1323"
    "mysql:3306"
    "postgres:5432"
)

for port_test in "${port_tests[@]}"; do
    echo -n "$port_test: "
    if docker-compose exec -T api-gateway nc -z ${port_test%:*} ${port_test#*:} >/dev/null 2>&1; then
        echo "✅ Puerto abierto"
    else
        echo "❌ Puerto cerrado o no accesible"
    fi
done
echo ""

echo "📋 9. LOGS DE RED Y CONECTIVIDAD"
echo "================================"

echo "Logs recientes relacionados con conectividad:"
docker-compose logs api-gateway | grep -E "(connection|network|dial|timeout|refused)" | tail -5
echo ""

echo "🎯 RESUMEN DEL DIAGNÓSTICO"
echo "=========================="
echo ""
echo "Si encuentras problemas:"
echo ""
echo "1. ❌ Contenedores no están en la misma red:"
echo "   - Verificar que todos tengan 'networks: - pacifico_network'"
echo ""
echo "2. ❌ DNS no resuelve nombres de servicios:"
echo "   - Recrear la red: docker-compose down && docker-compose up -d"
echo ""
echo "3. ❌ Puertos no accesibles:"
echo "   - Verificar que los servicios estén bind a 0.0.0.0, no localhost"
echo ""
echo "4. ❌ Health checks fallan:"
echo "   - Verificar URLs en config.json"
echo "   - Verificar que endpoints /health existan"
echo ""
echo "🔧 Comandos útiles:"
echo "   - Recrear red: docker-compose down && docker-compose up -d"
echo "   - Inspeccionar red: docker network inspect \$(docker network ls | grep pacifico | awk '{print \$1}')"
echo "   - Logs específicos: docker-compose logs [servicio]"
echo "   - Entrar a contenedor: docker-compose exec [servicio] sh"
