#!/bin/bash

echo "🎯 Aplicando todas las correcciones para la transición Docker"
echo "=============================================================="
echo ""

echo "📋 Resumen de correcciones aplicadas:"
echo "1. ✅ Circuit Breaker panic fix"
echo "2. ✅ Health check endpoints unificados a /health"
echo "3. ✅ URLs de servicio captcha corregidas"
echo "4. ✅ Variables de entorno MySQL para ms-gestion-gestor"
echo "5. ✅ Health checks en docker-compose.yml corregidos"
echo "6. ✅ Dependencias de base de datos agregadas"
echo ""

echo "🛑 1. Deteniendo todo el stack..."
docker-compose down --remove-orphans

echo ""
echo "🧹 2. Limpiando imágenes previas (opcional)..."
read -p "¿Quieres limpiar las imágenes Docker previas? (y/N): " clean_images
if [[ $clean_images == "y" || $clean_images == "Y" ]]; then
    docker-compose build --no-cache
else
    echo "   Usando caché existente..."
fi

echo ""
echo "🗄️ 3. Iniciando bases de datos..."
docker-compose up -d mysql postgres

echo "   Esperando que MySQL esté listo..."
until docker-compose exec mysql mysqladmin ping -h localhost --silent; do
    echo "   ⏳ MySQL iniciando..."
    sleep 2
done
echo "   ✅ MySQL listo"

echo "   Esperando que PostgreSQL esté listo..."
until docker-compose exec postgres pg_isready -U postgres; do
    echo "   ⏳ PostgreSQL iniciando..."
    sleep 2
done
echo "   ✅ PostgreSQL listo"

echo ""
echo "🚀 4. Construyendo e iniciando microservicios..."
docker-compose build ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha
docker-compose up -d ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

echo ""
echo "⏳ 5. Esperando que los microservicios estén listos..."
sleep 15

echo "   Verificando health checks de microservicios..."
for service in ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-gestion-gestor ms-validar-recaptcha; do
    echo "   Checking $service..."
    if docker-compose ps $service | grep -q "Up (healthy)"; then
        echo "   ✅ $service healthy"
    else
        echo "   ⚠️ $service not healthy yet"
        docker-compose logs --tail=3 $service
    fi
done

echo ""
echo "🌐 6. Construyendo e iniciando API Gateway..."
docker-compose build api-gateway
docker-compose up -d api-gateway

echo ""
echo "⏳ 7. Esperando que el API Gateway esté listo..."
sleep 10

echo ""
echo "📊 8. Estado final del stack:"
docker-compose ps

echo ""
echo "🧪 9. Pruebas rápidas..."

# Test directo a microservicios
echo ""
echo "   Testing microservices directly:"
curl -s http://localhost:3000/health | jq '.' 2>/dev/null && echo "   ✅ Lead service OK" || echo "   ❌ Lead service failed"
curl -s http://localhost:8001/health | jq '.' 2>/dev/null && echo "   ✅ Persona service OK" || echo "   ❌ Persona service failed"
curl -s http://localhost:8002/health | jq '.' 2>/dev/null && echo "   ✅ Poliza service OK" || echo "   ❌ Poliza service failed"
curl -s http://localhost:6000/health | jq '.' 2>/dev/null && echo "   ✅ Gestor service OK" || echo "   ❌ Gestor service failed"
curl -s http://localhost:1323/recaptcha/health | jq '.' 2>/dev/null && echo "   ✅ Recaptcha service OK" || echo "   ❌ Recaptcha service failed"

# Test API Gateway
echo ""
echo "   Testing API Gateway:"
curl -s http://localhost:8000/health | jq '.' 2>/dev/null && echo "   ✅ Gateway health OK" || echo "   ❌ Gateway health failed"
curl -s http://localhost:8000/health/services | jq '.' 2>/dev/null && echo "   ✅ Gateway services health OK" || echo "   ❌ Gateway services health failed"

# Test proxy
echo ""
echo "   Testing proxy through gateway:"
curl -s http://localhost:8000/leads/ | jq '.' 2>/dev/null && echo "   ✅ Proxy to leads OK" || echo "   ❌ Proxy to leads failed"

echo ""
echo "🎉 ¡Correcciones completadas!"
echo ""
echo "📝 Próximos pasos:"
echo "1. Ejecutar: chmod +x diagnose_docker.sh && ./diagnose_docker.sh"
echo "2. Si hay problemas, revisar logs: docker-compose logs [servicio]"
echo "3. Probar endpoint específico: curl http://localhost:8000/leads/"
echo ""
echo "🐛 Troubleshooting:"
echo "- Ver logs de un servicio: docker-compose logs [servicio]"
echo "- Reiniciar un servicio: docker-compose restart [servicio]"
echo "- Ver red: docker network inspect [nombre]_pacifico_network"
echo "- Entrar a un contenedor: docker-compose exec [servicio] sh"
