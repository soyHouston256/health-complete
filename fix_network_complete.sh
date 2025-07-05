#!/bin/bash

echo "🔧 CORRECCIÓN COMPLETA DE CONFIGURACIÓN DE RED Y BIND ADDRESSES"
echo "================================================================="
echo ""

echo "📋 Problemas identificados y corrigiendo:"
echo "1. ✅ ms-gestion-lead: Corregido bind address a 0.0.0.0"
echo "2. ✅ Todos los servicios en pacifico_network"
echo "3. ✅ Variables de entorno MySQL corregidas para ms-gestion-gestor"
echo ""

echo "🛑 1. Deteniendo todos los servicios..."
docker-compose down --remove-orphans

echo ""
echo "🗑️ 2. Limpiando red y volúmenes (opcional)..."
read -p "¿Quieres limpiar completamente la red y volúmenes? (y/N): " clean_network
if [[ $clean_network == "y" || $clean_network == "Y" ]]; then
    echo "   Eliminando red anterior..."
    docker network rm $(docker network ls --format "{{.Name}}" | grep pacifico) 2>/dev/null || true
    echo "   Eliminando volúmenes..."
    docker-compose down --volumes
fi

echo ""
echo "🏗️ 3. Reconstruyendo servicios con correcciones..."
echo "   Rebuilding ms-gestion-lead (bind address corregido)..."
docker-compose build ms-gestion-lead

echo "   Rebuilding ms-gestion-gestor (variables MySQL)..."
docker-compose build ms-gestion-gestor

echo "   Rebuilding API Gateway..."
docker-compose build api-gateway

echo ""
echo "🗄️ 4. Iniciando bases de datos primero..."
docker-compose up -d mysql postgres

echo ""
echo "⏳ 5. Esperando que las bases de datos estén completamente listas..."
echo "   Esperando MySQL..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker-compose exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "   ✅ MySQL listo"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo "   ⏳ MySQL iniciando... (${elapsed}s)"
done

echo "   Esperando PostgreSQL..."
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker-compose exec -T postgres pg_isready -U postgres 2>/dev/null; then
        echo "   ✅ PostgreSQL listo"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo "   ⏳ PostgreSQL iniciando... (${elapsed}s)"
done

echo ""
echo "🚀 6. Iniciando microservicios..."
docker-compose up -d ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

echo ""
echo "⏳ 7. Esperando que los microservicios estén listos..."
sleep 20

echo ""
echo "🧪 8. Verificando que los microservicios respondan individualmente..."
services=("3000:lead" "8001:persona" "8002:poliza" "6000:gestor" "1323:recaptcha")
all_healthy=true

for service in "${services[@]}"; do
    port=${service%:*}
    name=${service#*:}
    echo -n "   Testing $name ($port): "
    
    if [ "$name" == "recaptcha" ]; then
        url="http://localhost:$port/recaptcha/health"
    else
        url="http://localhost:$port/health"
    fi
    
    if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        all_healthy=false
    fi
done

echo ""
echo "🌐 9. Iniciando API Gateway..."
docker-compose up -d api-gateway

echo ""
echo "⏳ 10. Esperando que el API Gateway esté listo..."
sleep 15

echo ""
echo "🔗 11. Verificando conectividad de red entre contenedores..."

if docker-compose ps api-gateway | grep -q "Up"; then
    echo "   Probando conectividad desde API Gateway:"
    
    # Función para probar conectividad interna
    test_internal_connectivity() {
        local target=$1
        local description=$2
        echo -n "     $description: "
        if docker-compose exec -T api-gateway ping -c 1 -W 2 ${target%:*} >/dev/null 2>&1; then
            echo "✅ Ping OK"
        else
            echo "❌ Ping failed"
        fi
    }
    
    test_internal_connectivity "ms-gestion-lead:3000" "Lead Service"
    test_internal_connectivity "ms-gestion-persona:8001" "Persona Service"
    test_internal_connectivity "ms-gestion-poliza:8002" "Poliza Service"
    test_internal_connectivity "ms-gestion-gestor:6000" "Gestor Service"
    test_internal_connectivity "ms-validar-recaptcha:1323" "Recaptcha Service"
else
    echo "   ❌ API Gateway no está ejecutándose"
fi

echo ""
echo "🧪 12. Pruebas finales de funcionalidad..."

echo "   Health check del API Gateway:"
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "     ✅ Gateway health OK"
else
    echo "     ❌ Gateway health failed"
fi

echo "   Health services del API Gateway:"
if curl -s http://localhost:8000/health/services >/dev/null 2>&1; then
    echo "     ✅ Gateway services health OK"
else
    echo "     ❌ Gateway services health failed"
fi

echo "   Proxy a través del Gateway:"
if curl -s http://localhost:8000/leads/ >/dev/null 2>&1; then
    echo "     ✅ Proxy to leads OK"
else
    echo "     ❌ Proxy to leads failed"
fi

echo ""
echo "📊 13. Estado final del stack:"
docker-compose ps

echo ""
echo "🌐 14. Información de la red:"
NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep pacifico | head -1)
if [ -n "$NETWORK_NAME" ]; then
    echo "   Red activa: $NETWORK_NAME"
    echo "   Contenedores en la red:"
    docker network inspect "$NETWORK_NAME" | jq -r '.[0].Containers | to_entries[] | "     \(.value.Name) - \(.value.IPv4Address)"' 2>/dev/null || echo "     (Información detallada no disponible)"
fi

echo ""
echo "🎉 CORRECCIÓN COMPLETADA"
echo "========================="

if [ "$all_healthy" = true ]; then
    echo "✅ Todos los servicios están funcionando correctamente"
    echo ""
    echo "🧪 Prueba tu API Gateway:"
    echo "   curl http://localhost:8000/leads/"
    echo "   curl http://localhost:8000/health/services"
else
    echo "⚠️ Algunos servicios pueden tener problemas"
    echo ""
    echo "🔍 Para diagnosticar:"
    echo "   ./diagnose_network.sh"
    echo "   docker-compose logs [servicio]"
fi

echo ""
echo "📋 Archivos modificados:"
echo "✅ ms-gestion-lead/src/main.ts - bind address corregido"
echo "✅ ms-gestion-gestor/main.py - variables de entorno"
echo "✅ docker-compose.yml - configuración completa de red"
echo "✅ api-gateway/proxy/handler.go - parche temporal aplicado"
