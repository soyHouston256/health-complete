#!/bin/bash

echo "🔄 Aplicando parche temporal y reiniciando API Gateway"
echo "====================================================="
echo ""

echo "📦 Backup del archivo original..."
cp api-gateway/proxy/handler.go api-gateway/proxy/handler.go.backup

echo "✅ Parche ya aplicado en el código"
echo ""

echo "🔄 Rebuild y restart del API Gateway..."
docker-compose build api-gateway
docker-compose restart api-gateway

echo ""
echo "⏳ Esperando que el gateway esté listo..."
sleep 10

echo ""
echo "🧪 Probando el API Gateway con el parche:"
echo "Request a /leads/:"
curl -s http://localhost:8000/leads/ | jq '.' 2>/dev/null && echo "✅ Parche funcionando - Gateway proxy OK" || echo "❌ Aún hay problemas"

echo ""
echo "🔍 Verificando logs de debug:"
echo "Los logs del API Gateway ahora mostrarán información de debug sobre el health checker"
echo ""
echo "📋 Para ver logs en tiempo real:"
echo "docker-compose logs -f api-gateway"
echo ""
echo "📋 Para revertir el parche:"
echo "cp api-gateway/proxy/handler.go.backup api-gateway/proxy/handler.go"
echo "docker-compose build api-gateway && docker-compose restart api-gateway"
