#!/bin/bash

# Test script para tu API Gateway
# Servicios: Lead (puerto 3000) y Captcha (puerto 1323)

BASE_URL="http://localhost:8001"  # Tu gateway está en puerto 8001

echo "🧪 Testing tu API Gateway..."
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Health Check del Gateway
echo -e "${BLUE}📊 1. Health Check del Gateway${NC}"
curl -s -X GET "$BASE_URL/health" | jq . 2>/dev/null || curl -s -X GET "$BASE_URL/health"
echo ""

# Test 2: Health Check de tus Servicios
echo -e "${BLUE}📊 2. Health Check de tus Servicios (Lead + Captcha)${NC}"
curl -s -X GET "$BASE_URL/health/services" | jq . 2>/dev/null || curl -s -X GET "$BASE_URL/health/services"
echo ""

# Test 3: Test del servicio Lead health check
echo -e "${BLUE}🎯 3. Test del servicio Lead health check${NC}"
echo "Probando: $BASE_URL/api/lead/health"
curl -s -X GET "$BASE_URL/api/lead/health" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5 || echo "❌ Servicio Lead health no responde"
echo ""

# Test 4: Test del endpoint raíz del servicio Lead
echo -e "${BLUE}🏠 4. Test del endpoint raíz del servicio Lead${NC}"
echo "Probando: $BASE_URL/api/lead/"
curl -s -X GET "$BASE_URL/api/lead/" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5 || echo "❌ Servicio Lead raíz no responde"
echo ""

# Test 5: Test del servicio Captcha 
echo -e "${BLUE}🔒 5. Test del servicio Captcha (reCAPTCHA)${NC}"
echo "Probando: $BASE_URL/api/recaptcha/"
curl -s -X GET "$BASE_URL/api/recaptcha/" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" || echo "❌ Servicio Captcha no responde"
echo ""

# Test 6: Test de verificación de Captcha
echo -e "${BLUE}🔐 6. Test de verificación Captcha${NC}"
curl -s -X POST "$BASE_URL/api/recaptcha/verify" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "test-captcha-token-123",
    "action": "submit_form"
  }' \
  -w "Status: %{http_code}, Time: %{time_total}s\n" || echo "❌ Captcha verify falló"
echo ""

# Test 7: Rate Limiting (múltiples requests rápidas)
echo -e "${BLUE}⚡ 7. Test de Rate Limiting (5 requests rápidas al Lead)${NC}"
for i in {1..5}; do
  echo "Request $i:"
  curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" \
    -X GET "$BASE_URL/api/lead/" -o /dev/null
  sleep 0.1
done
echo ""

# Test 8: Test de Cache (GET requests repetidas)
echo -e "${BLUE}💾 8. Test de Cache (requests repetidas)${NC}"
echo "Primera request (debería ser MISS):"
curl -s -X GET "$BASE_URL/api/lead/" \
  -H "Accept: application/json" \
  -v 2>&1 | grep -E "(X-Cache|HTTP/)" || echo "Sin headers de cache"

echo "Segunda request (debería ser HIT si el cache está funcionando):"
curl -s -X GET "$BASE_URL/api/lead/" \
  -H "Accept: application/json" \
  -v 2>&1 | grep -E "(X-Cache|HTTP/)" || echo "Sin headers de cache"
echo ""

# Test 9: Test con API Key (si auth está habilitado)
echo -e "${BLUE}🔐 9. Test con API Key${NC}"
curl -s -X GET "$BASE_URL/api/lead/" \
  -H "X-API-Key: dev-key-lead-123" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" || echo "❌ API Key test falló"
echo ""

# Test 10: Tests directos a servicios (bypass gateway)
echo -e "${BLUE}🎯 10. Tests directos a servicios (bypass gateway)${NC}"
echo "Lead service health directo:"
curl -s -X GET "http://localhost:3000/api/health" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null || echo "❌ Lead health directo no responde"

echo "Lead service raíz directo (puerto 3000):"
curl -s -X GET "http://localhost:3000/" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null || echo "❌ Lead service directo no responde"

echo "Captcha service directo (puerto 1323):"
curl -s -X GET "http://localhost:1323/" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null || echo "❌ Captcha service directo no responde"
echo ""

echo -e "${GREEN}✅ Tests completados!${NC}"
echo ""
echo -e "${YELLOW}📊 Resumen de tu configuración:${NC}"
echo "  - Gateway: http://localhost:8001"
echo "  - Lead Service: http://localhost:3000 -> /api/lead/*"
echo "  - Captcha Service: http://localhost:1323 -> /api/recaptcha/*"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  - Si los servicios no responden, asegúrate de que estén corriendo"
echo "  - Para habilitar auth, cambia 'enabled: true' en config/config.json"
echo "  - Para ver logs detallados, ejecuta el gateway en modo debug"
echo "  - El cache funciona solo para requests GET"
echo "  - Rate limiting está configurado: Lead (100 req/s), Captcha (50 req/s)"
echo ""
echo -e "${BLUE}🚀 Comandos útiles:${NC}"
echo "  - Iniciar Redis: docker run -d -p 6379:6379 redis:alpine"
echo "  - Ver logs: tail -f logs/gateway.log"
echo "  - Compilar: go build -o api-gateway"
echo "  - Ejecutar: ./api-gateway"