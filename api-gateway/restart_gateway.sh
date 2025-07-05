#!/bin/bash

echo "🚀 Rebuild and restart API Gateway after fixes..."
echo ""

# Detener el API Gateway
echo "🛑 Stopping API Gateway..."
docker-compose stop api-gateway

echo ""
echo "🏗️ Rebuilding API Gateway with fixes..."
docker-compose build api-gateway

echo ""
echo "▶️ Starting API Gateway..."
docker-compose up -d api-gateway

echo ""
echo "⏳ Waiting for API Gateway to be ready..."
sleep 10

echo ""
echo "🔍 Checking API Gateway status..."
docker-compose ps api-gateway

echo ""
echo "📋 Recent logs:"
docker-compose logs --tail=20 api-gateway

echo ""
echo "✅ API Gateway restart completed!"
echo "💡 Run './verify_fixes.sh' to test the fixes"
