#!/bin/bash

# Test script actualizado para tu configuración real
BASE_URL="http://localhost:8001"

echo "🧪 Testing tu API Gateway con configuración actualizada..."
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

# Test 2: Health Check de todos los servicios
echo -e "${BLUE}📊 2. Health Check de todos los servicios${NC}"
curl -s -X GET "$BASE_URL/health/services" | jq . 2>/dev/null || curl -s -X GET "$BASE_URL/health/services"
echo ""

# Test 3: Lead Service Health Check
echo -e "${BLUE}🎯 3. Test Lead Service Health Check${NC}"
echo "Probando: $BASE_URL/api/lead/health"
curl -s -X GET "$BASE_URL/api/lead/health" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5
echo ""

# Test 4: reCAPTCHA Service Health Check
echo -e "${BLUE}🔒 4. Test reCAPTCHA Service Health Check${NC}"
echo "Probando: $BASE_URL/ms-validate-recaptcha/api/health"
curl -s -X GET "$BASE_URL/ms-validate-recaptcha/api/health" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5
echo ""

# Test 5: Lead Service Endpoint Raíz
echo -e "${BLUE}🏠 5. Test Lead Service Endpoint Raíz${NC}"
echo "Probando: $BASE_URL/api/lead/"
curl -s -X GET "$BASE_URL/api/lead/" \
  -H "Content-Type: application/json" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" | head -5
echo ""

# Test 6: Rate Limiting Test
echo -e "${BLUE}⚡ 6. Test de Rate Limiting (5 requests rápidas)${NC}"
for i in {1..5}; do
  echo "Request $i al Lead service:"
  curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" \
    -X GET "$BASE_URL/api/lead/health" -o /dev/null
  sleep 0.1
done
echo ""

# Test 7: Cache Test (requests repetidas)
echo -e "${BLUE}💾 7. Test de Cache (requests repetidas al Lead)${NC}"
echo "Primera request (MISS esperado):"
curl -s -X GET "$BASE_URL/api/lead/health" \
  -v 2>&1 | grep -E "(X-Cache|HTTP/)" | head -2

echo "Segunda request (HIT esperado si cache está habilitado):"
curl -s -X GET "$BASE_URL/api/lead/health" \
  -v 2>&1 | grep -E "(X-Cache|HTTP/)" | head -2
echo ""

# Test 8: Tests directos a servicios (bypass gateway)
echo -e "${BLUE}🎯 8. Tests directos a servicios (bypass gateway)${NC}"
echo "Lead service directo:"
curl -s -X GET "http://localhost:3000/api/health" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null

echo "reCAPTCHA service directo:"
curl -s -X GET "http://localhost:1323/ms-validate-recaptcha/api/health" \
  -w "Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null
echo ""

# Test 9: Logs del proxy
echo -e "${BLUE}📋 9. Verificar logs del proxy${NC}"
echo "Ejecuta este comando y observa los logs del gateway:"
echo "curl $BASE_URL/api/lead/health"
echo "curl $BASE_URL/ms-validate-recaptcha/api/health"
echo ""

echo -e "${GREEN}✅ Tests completados!${NC}"
echo ""
echo -e "${YELLOW}📊 Resumen de tu configuración:${NC}"
echo "  - Gateway: http://localhost:8001"
echo "  - Lead Service: /api/lead/* -> http://localhost:3000/api/*"
echo "  - reCAPTCHA Service: /ms-validate-recaptcha/api/* -> http://localhost:1323/ms-validate-recaptcha/api/*"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  - Ambos servicios deben estar corriendo en sus puertos respectivos"
echo "  - Observa los logs del gateway para ver el ruteo en acción"
echo "  - El cache está habilitado solo para el Lead service"
echo "  - Rate limiting: Lead (100 req/s), reCAPTCHA (50 req/s)"