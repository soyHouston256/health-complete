#!/bin/bash

# Test script para verificar que NO hay duplicación en el formato de respuesta
BASE_URL="http://localhost:8001"

echo "🧪 Testing API Gateway - Verificación de NO Duplicación..."
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para verificar que NO hay duplicación
check_no_duplication() {
    local response="$1"
    local test_name="$2"
    
    echo -e "${BLUE}🔍 Verificando: $test_name${NC}"
    
    # Verificar formato básico
    if echo "$response" | jq -e '.data and (.success | type) == "boolean" and (.errorMessage | type) == ("string" or "null")' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Formato estándar presente${NC}"
        
        # Verificar que NO hay duplicación (data.data.success)
        if echo "$response" | jq -e '.data.data.success' > /dev/null 2>&1; then
            echo -e "  ${RED}❌ DUPLICACIÓN DETECTADA - data.data.success existe${NC}"
            echo "  Respuesta duplicada:"
            echo "$response" | jq '.data' | head -10
            return 1
        else
            echo -e "  ${GREEN}✅ NO hay duplicación - estructura correcta${NC}"
        fi
        
        # Verificar que NO hay anidamiento excesivo
        if echo "$response" | jq -e '.data.data.data' > /dev/null 2>&1; then
            echo -e "  ${RED}❌ ANIDAMIENTO EXCESIVO DETECTADO${NC}"
            return 1
        else
            echo -e "  ${GREEN}✅ NO hay anidamiento excesivo${NC}"
        fi
        
        # Mostrar estructura actual
        echo -e "  ${BLUE}📋 Estructura actual:${NC}"
        echo "$response" | jq '{success: .success, errorMessage: .errorMessage, data_keys: (.data | keys | length)}'
        
    else
        echo -e "  ${RED}❌ Formato estándar incorrecto${NC}"
        return 1
    fi
    
    echo ""
    return 0
}

# Test 1: Health Check del Gateway (debe ser formato estándar sin duplicación)
echo -e "${BLUE}📊 1. Health Check del Gateway${NC}"
response=$(curl -s -X GET "$BASE_URL/health")
check_no_duplication "$response" "Gateway Health Check"

# Test 2: Lead Service Health Check
echo -e "${BLUE}🎯 2. Lead Service Health Check${NC}"
echo "Endpoint: $BASE_URL/api/lead/health"
response=$(curl -s -X GET "$BASE_URL/api/lead/health")
echo "Response del servicio via gateway:"
echo "$response" | jq . 2>/dev/null || echo "$response"
check_no_duplication "$response" "Lead Health Check"

# Test 3: reCAPTCHA Service Health Check
echo -e "${BLUE}🔒 3. reCAPTCHA Service Health Check${NC}"
echo "Endpoint: $BASE_URL/ms-validate-recaptcha/api/health"
response=$(curl -s -X GET "$BASE_URL/ms-validate-recaptcha/api/health")
echo "Response del servicio via gateway:"
echo "$response" | jq . 2>/dev/null || echo "$response"
check_no_duplication "$response" "reCAPTCHA Health Check"

# Test 4: Comparación Directo vs Gateway
echo -e "${BLUE}🔄 4. Comparación Directo vs Gateway${NC}"

echo "🎯 Lead Service - Respuesta DIRECTA:"
direct_lead=$(curl -s -X GET "http://localhost:3000/api/health" 2>/dev/null || echo '{"error": "service not available"}')
echo "$direct_lead" | jq . 2>/dev/null || echo "$direct_lead"

echo ""
echo "🎯 Lead Service - Respuesta VIA GATEWAY:"
gateway_lead=$(curl -s -X GET "$BASE_URL/api/lead/health" 2>/dev/null || echo '{"error": "gateway not available"}')
echo "$gateway_lead" | jq . 2>/dev/null || echo "$gateway_lead"

echo ""
echo "🔒 reCAPTCHA Service - Respuesta DIRECTA:"
direct_recaptcha=$(curl -s -X GET "http://localhost:1323/ms-validate-recaptcha/api/health" 2>/dev/null || echo '{"error": "service not available"}')
echo "$direct_recaptcha" | jq . 2>/dev/null || echo "$direct_recaptcha"

echo ""
echo "🔒 reCAPTCHA Service - Respuesta VIA GATEWAY:"
gateway_recaptcha=$(curl -s -X GET "$BASE_URL/ms-validate-recaptcha/api/health" 2>/dev/null || echo '{"error": "gateway not available"}')
echo "$gateway_recaptcha" | jq . 2>/dev/null || echo "$gateway_recaptcha"

# Test 5: Verificar casos específicos de duplicación
echo ""
echo -e "${BLUE}🔍 5. Verificación específica de duplicación${NC}"

echo "Verificando que NO exista data.data.success en ninguna respuesta:"
if echo "$gateway_lead" | jq -e '.data.data.success' > /dev/null 2>&1; then
    echo -e "${RED}❌ PROBLEMA: Lead service tiene duplicación${NC}"
else
    echo -e "${GREEN}✅ Lead service sin duplicación${NC}"
fi

if echo "$gateway_recaptcha" | jq -e '.data.data.success' > /dev/null 2>&1; then
    echo -e "${RED}❌ PROBLEMA: reCAPTCHA service tiene duplicación${NC}"
else
    echo -e "${GREEN}✅ reCAPTCHA service sin duplicación${NC}"
fi

# Test 6: Test de POST para verificar respuestas complejas
echo ""
echo -e "${BLUE}📝 6. Test POST (verificar respuestas complejas)${NC}"
post_response=$(curl -s -X POST "$BASE_URL/api/lead/" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com"
  }')
echo "POST Response:"
echo "$post_response" | jq . 2>/dev/null || echo "$post_response"
check_no_duplication "$post_response" "POST Response"

# Test 7: Test de endpoint inexistente (error handling)
echo -e "${BLUE}❌ 7. Test Error Handling${NC}"
error_response=$(curl -s -X GET "$BASE_URL/api/lead/nonexistent")
echo "Error Response:"
echo "$error_response" | jq . 2>/dev/null || echo "$error_response"
check_no_duplication "$error_response" "Error Response"

echo ""
echo -e "${GREEN}✅ Verificación completada!${NC}"
echo ""
echo -e "${YELLOW}📊 Resumen de la verificación:${NC}"
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ ✅ Verificación de NO duplicación                               │"
echo "│                                                                 │"
echo "│ ❌ INCORRECTO (duplicado):                                      │"
echo "│ {                                                               │"
echo "│   \"data\": {                                                    │"
echo "│     \"data\": { /* contenido real */ },                         │"
echo "│     \"success\": true,                                          │"
echo "│     \"errorMessage\": null                                      │"
echo "│   },                                                            │"
echo "│   \"success\": true,                                            │"
echo "│   \"errorMessage\": null                                        │"
echo "│ }                                                               │"
echo "│                                                                 │"
echo "│ ✅ CORRECTO (sin duplicación):                                  │"
echo "│ {                                                               │"
echo "│   \"data\": { /* contenido real del servicio */ },             │"
echo "│   \"success\": true,                                            │"
echo "│   \"errorMessage\": null                                        │"
echo "│ }                                                               │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo -e "${YELLOW}💡 Si tus servicios YA devuelven el formato estándar:${NC}"
echo "  - El gateway debe detectarlo automáticamente"
echo "  - No debe hacer transformación adicional"
echo "  - Debe pasar la respuesta tal como está"
echo ""
echo -e "${YELLOW}🔧 Si encuentras duplicación:${NC}"
echo "  - Verifica que la función isStandardFormat() funcione correctamente"
echo "  - Los servicios deben devolver exactamente: {data, success, errorMessage}"
echo "  - Revisa los logs del gateway para ver la detección automática"