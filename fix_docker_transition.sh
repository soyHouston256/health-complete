#!/bin/bash

echo "🔧 Aplicando correcciones para la transición a Docker"
echo "======================================================"
echo ""

echo "1. 🛑 Deteniendo todos los servicios..."
docker-compose down

echo ""
echo "2. 🏗️ Reconstruyendo servicios con correcciones..."

# Rebuild servicios clave
echo "   Rebuilding API Gateway..."
docker-compose build api-gateway

echo "   Rebuilding microservicios..."
docker-compose build ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-gestion-gestor ms-validar-recaptcha

echo ""
echo "3. 🗄️ Iniciando bases de datos primero..."
docker-compose up -d mysql postgres

echo ""
echo "4. ⏳ Esperando que las bases de datos estén listas..."
sleep 15

echo ""
echo "5. 🚀 Iniciando microservicios..."
docker-compose up -d ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

echo ""
echo "6. ⏳ Esperando que los microservicios estén listos..."
sleep 10

echo ""
echo "7. 🌐 Iniciando API Gateway..."
docker-compose up -d api-gateway

echo ""
echo "8. ⏳ Esperando que el API Gateway esté listo..."
sleep 10

echo ""
echo "9. 📊 Verificando estado final..."
docker-compose ps

echo ""
echo "10. 🔍 Verificando logs de errores..."
echo ""
echo "--- API Gateway ---"
docker-compose logs --tail=10 api-gateway | grep -E "(ERROR|PANIC|error|panic|failed|Failed)" || echo "Sin errores críticos"

echo ""
echo "--- MS Lead ---"
docker-compose logs --tail=5 ms-gestion-lead | grep -E "(ERROR|error|failed|Failed)" || echo "Sin errores críticos"

echo ""
echo "--- MS Persona ---"
docker-compose logs --tail=5 ms-gestion-persona | grep -E "(ERROR|error|failed|Failed)" || echo "Sin errores críticos"

echo ""
echo "✅ Correcciones aplicadas!"
echo ""
echo "💡 Siguiente paso: Ejecutar './diagnose_docker.sh' para verificar que todo funciona"
echo ""
echo "🐛 Si persisten problemas, revisa:"
echo "   - Variables de entorno en docker-compose.yml"
echo "   - Conectividad de red entre contenedores"
echo "   - Configuración de bases de datos"
echo "   - Logs detallados: docker-compose logs [servicio]"
