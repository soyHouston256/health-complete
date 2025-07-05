#!/bin/bash

# Test script para el API Gateway con formato de respuesta estándar
BASE_URL="http://localhost:8001"

echo "🧪 Testing API Gateway con Formato de Respuesta Estándar..."
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para verificar formato de respuesta estándar
check_standard_format() {
    local response="$1"
    local test_name="$2"
    
    if echo "$response" | jq -e '.data and (.success | type) == "boolean" and (.errorMessage | type) == ("string" or "null")' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Formato estándar correcto${NC}"
        
        # Verificar si es exitoso o error
        success=$(echo "$response" | jq -r '.success')
        if [ "$success" = "true" ]; then
            echo -e "  ${GREEN}✅ Success: true${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Success: false${NC}"
            error_message=$(echo "$response" | jq -r '.errorMessage // "No error message"')
            echo -e "  ${YELLOW}   Error: $error_message${NC}"
        fi
    else
        echo -e "  ${RED}❌ Formato estándar incorrecto${NC}"
    fi
}

# Test 1: Health Check del Gateway
echo -e "${BLUE}📊 1. Health Check del Gateway${NC}"
echo "Probando: $BASE_URL/health"
response=$(curl -s -X GET "$BASE_URL/health")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Gateway Health"
echo ""

# Test 2: Health Check de todos los servicios
echo -e "${BLUE}📊 2. Health Check de todos los servicios${NC}"
echo "Probando: $BASE_URL/health/services"
response=$(curl -s -X GET "$BASE_URL/health/services")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Services Health"
echo ""

# Test 3: Métricas del Gateway
echo -e "${BLUE}📈 3. Métricas del Gateway${NC}"
echo "Probando: $BASE_URL/metrics"
response=$(curl -s -X GET "$BASE_URL/metrics")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Gateway Metrics"
echo ""

# Test 4: Lead Service Health Check
echo -e "${BLUE}🎯 4. Test Lead Service Health Check${NC}"
echo "Probando: $BASE_URL/api/lead/health"
response=$(curl -s -X GET "$BASE_URL/api/lead/health")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Lead Health"
echo ""

# Test 5: reCAPTCHA Service Health Check
echo -e "${BLUE}🔒 5. Test reCAPTCHA Service Health Check${NC}"
echo "Probando: $BASE_URL/ms-validate-recaptcha/api/health"
response=$(curl -s -X GET "$BASE_URL/ms-validate-recaptcha/api/health")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "reCAPTCHA Health"
echo ""

# Test 6: Test de endpoint inexistente (para verificar formato de error)
echo -e "${BLUE}❌ 6. Test de endpoint inexistente (formato de error)${NC}"
echo "Probando: $BASE_URL/api/lead/nonexistent"
response=$(curl -s -X GET "$BASE_URL/api/lead/nonexistent")
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Error Response"
echo ""

# Test 7: Test POST al Lead service
echo -e "${BLUE}📝 7. Test POST al Lead Service${NC}"
echo "Probando: $BASE_URL/api/lead/ (POST)"
response=$(curl -s -X POST "$BASE_URL/api/lead/" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "lastname": "Gateway Test",
    "email": "test@gateway.com",
    "phone": "123456789"
  }')
echo "$response" | jq . 2>/dev/null || echo "$response"
check_standard_format "$response" "Lead POST"
echo ""

# Test 8: Rate Limiting Test
echo -e "${BLUE}⚡ 8. Test de Rate Limiting (formato de error)${NC}"
echo "Enviando múltiples requests rápidas para activar rate limiting..."
for i in {1..6}; do
  echo "Request $i:"
  response=$(curl -s -X GET "$BASE_URL/api/lead/health")
  if echo "$response" | grep -q "Rate limit exceeded"; then
    echo -e "  ${YELLOW}⚡ Rate limit activado${NC}"
    check_standard_format "$response" "Rate Limit Error"
    break
  else
    echo -e "  ${GREEN}✅ Request $i exitosa${NC}"
  fi
  sleep 0.1
done
echo ""

# Test 9: Verificar estructura de datos específica
echo -e "${BLUE}🔍 9. Verificación detallada del formato${NC}"
echo "Verificando estructura de health check..."
response=$(curl -s -X GET "$BASE_URL/health")

# Verificar campos específicos
if echo "$response" | jq -e '.data.status' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Campo data.status presente${NC}"
else
    echo -e "  ${RED}❌ Campo data.status ausente${NC}"
fi

if echo "$response" | jq -e '.data.timestamp' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Campo data.timestamp presente${NC}"
else
    echo -e "  ${RED}❌ Campo data.timestamp ausente${NC}"
fi

if echo "$response" | jq -e '.data.uptime' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Campo data.uptime presente${NC}"
else
    echo -e "  ${RED}❌ Campo data.uptime ausente${NC}"
fi
echo ""

# Test 10: Comparación con servicios directos
echo -e "${BLUE}🔄 10. Comparación con servicios directos${NC}"
echo "Comparando respuestas gateway vs directo..."

echo "Lead service directo:"
direct_response=$(curl -s -X GET "http://localhost:3000/api/health" 2>/dev/null || echo '{"error": "service not available"}')
echo "$direct_response" | jq . 2>/dev/null || echo "$direct_response"

echo ""
echo "Lead service vía gateway:"
gateway_response=$(curl -s -X GET "$BASE_URL/api/lead/health" 2>/dev/null || echo '{"error": "gateway not available"}')
echo "$gateway_response" | jq . 2>/dev/null || echo "$gateway_response"

echo ""
echo "reCAPTCHA service directo:"
direct_recaptcha=$(curl -s -X GET "http://localhost:1323/ms-validate-recaptcha/api/health" 2>/dev/null || echo '{"error": "service not available"}')
echo "$direct_recaptcha" | jq . 2>/dev/null || echo "$direct_recaptcha"

echo ""
echo "reCAPTCHA service vía gateway:"
gateway_recaptcha=$(curl -s -X GET "$BASE_URL/ms-validate-recaptcha/api/health" 2>/dev/null || echo '{"error": "gateway not available"}')
echo "$gateway_recaptcha" | jq . 2>/dev/null || echo "$gateway_recaptcha"
echo ""

echo -e "${GREEN}✅ Tests completados!${NC}"
echo ""
echo -e "${YELLOW}📊 Resumen del Formato de Respuesta Estándar:${NC}"
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ Estructura Estándar de Respuesta:                              │"
echo "│ {                                                               │"
echo "│   \"data\": { /* datos del servicio */ },                        │"
echo "│   \"success\": boolean,                                          │"
echo "│   \"errorMessage\": string | null                               │"
echo "│ }                                                               │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo -e "${YELLOW}📍 Endpoints del Gateway:${NC}"
echo "  - Gateway Health: $BASE_URL/health"
echo "  - Services Health: $BASE_URL/health/services"
echo "  - Gateway Metrics: $BASE_URL/metrics"
echo "  - Lead Service: $BASE_URL/api/lead/*"
echo "  - reCAPTCHA Service: $BASE_URL/ms-validate-recaptcha/api/*"
echo ""
echo -e "${YELLOW}💡 Características implementadas:${NC}"
echo "  ✅ Formato de respuesta estándar consistente"
echo "  ✅ Transformación automática de respuestas de servicios"
echo "  ✅ Manejo de errores con formato estándar"
echo "  ✅ Headers de gateway en todas las respuestas"
echo "  ✅ Rate limiting con formato de error estándar"
echo "  ✅ Métricas y health checks con formato estándar"