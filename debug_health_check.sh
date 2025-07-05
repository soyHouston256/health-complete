#!/bin/bash

echo "🔍 Diagnóstico específico del problema Health Check"
echo "=================================================="
echo ""

echo "1. 🏥 Verificando health endpoint del servicio lead directamente:"
echo "   Desde el host:"
curl -s http://localhost:3000/health || echo "❌ No responde"
echo ""

echo "2. 🐳 Verificando desde dentro del contenedor API Gateway:"
echo "   Probando conectividad red interna..."
docker-compose exec api-gateway ping -c 2 ms-gestion-lead 2>/dev/null || echo "❌ No puede hacer ping a ms-gestion-lead"
echo ""

echo "3. 🌐 Verificando health check desde API Gateway:"
echo "   Probando URL que usa el health checker..."
docker-compose exec api-gateway curl -s http://ms-gestion-lead:3000/health 2>/dev/null || echo "❌ No puede acceder al health endpoint"
echo ""

echo "4. 📊 Estado de los contenedores:"
docker-compose ps

echo ""
echo "5. 🔍 Logs recientes del health checker en API Gateway:"
docker-compose logs api-gateway | grep -E "(Health|health|HEALTH)" | tail -10

echo ""
echo "6. 🧪 Verificando endpoints disponibles en lead service:"
echo "   /health endpoint:"
curl -s http://localhost:3000/health | jq '.' 2>/dev/null || echo "❌ /health no responde o no es JSON"
echo ""
echo "   Root endpoint:"
curl -s http://localhost:3000/ | jq '.' 2>/dev/null || echo "❌ / no responde o no es JSON"

echo ""
echo "7. 🔗 Verificando la configuración del API Gateway:"
echo "   Health check URL configurada para lead:"
docker-compose exec api-gateway cat config/config.json | jq '.gateway.services[] | select(.name=="lead") | .health_check'

echo ""
echo "8. 🌐 Verificando red Docker:"
docker network ls | grep pacifico
docker network inspect $(docker-compose ps -q api-gateway | head -1) 2>/dev/null | jq -r '.[0].NetworkSettings.Networks | keys[]' || echo "No se puede inspeccionar red"

echo ""
echo "9. 📈 Estado del health checker en el API Gateway:"
curl -s http://localhost:8000/health/services | jq '.data.services.lead' 2>/dev/null || echo "❌ No se puede obtener estado del servicio lead"
