#!/bin/bash

# Script para probar el fix de duplicación en reCAPTCHA
echo "🧪 Testing reCAPTCHA Fix - Verificación de NO Duplicación..."
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# URL base del API Gateway
BASE_URL="http://localhost:8001"

echo -e "${BLUE}🔒 Test reCAPTCHA - Caso de error timeout-or-duplicate${NC}"

# Test con el token que está causando el problema
response=$(curl -s --location "$BASE_URL/recaptcha/validate-recaptcha" \
  --header 'Content-Type: application/json' \
  --data '{ "token":"03AFcWeA6LLV1" }')

echo "Response completa:"
echo "$response" | jq . 2>/dev/null || echo "$response"
echo ""

# Verificaciones específicas
echo -e "${BLUE}🔍 Verificaciones:${NC}"

# 1. Verificar que NO hay duplicación (data.data.success)
if echo "$response" | jq -e '.data.data.success' > /dev/null 2>&1; then
    echo -e "  ${RED}❌ PROBLEMA: Existe duplicación (data.data.success)${NC}"
    echo "  Estructura duplicada encontrada:"
    echo "$response" | jq '.data.data' 2>/dev/null
else
    echo -e "  ${GREEN}✅ NO hay duplicación - estructura correcta${NC}"
fi

# 2. Verificar formato estándar
if echo "$response" | jq -e '.data and (.success | type) == "boolean" and (.errorMessage | type) == ("string" or "null")' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Formato estándar presente${NC}"
else
    echo -e "  ${RED}❌ Formato estándar incorrecto${NC}"
fi

# 3. Verificar que errorMessage no contiene JSON duplicado
error_message=$(echo "$response" | jq -r '.errorMessage // empty')
if [[ "$error_message" == *"\"data\":"* ]]; then
    echo -e "  ${RED}❌ PROBLEMA: errorMessage contiene JSON duplicado${NC}"
    echo "  ErrorMessage problemático: $error_message"
else
    echo -e "  ${GREEN}✅ ErrorMessage limpio (sin JSON duplicado)${NC}"
fi

# 4. Mostrar estructura actual
echo -e "\n${BLUE}📋 Estructura actual:${NC}"
echo "$response" | jq '{
  success: .success,
  errorMessage: .errorMessage,
  data_type: (.data | type),
  data_keys: (if (.data | type) == "object" then (.data | keys) else "not_object" end)
}'

echo ""
echo -e "${YELLOW}💡 Estructura esperada CORRECTA:${NC}"
echo -e "${GREEN}{"
echo -e "  \"data\": {"
echo -e "    \"action\": \"\","
echo -e "    \"challenge_ts\": \"\","
echo -e "    \"error-codes\": [\"timeout-or-duplicate\"],"
echo -e "    \"hostname\": \"\","
echo -e "    \"score\": 0,"
echo -e "    \"success\": false"
echo -e "  },"
echo -e "  \"success\": false,"
echo -e "  \"errorMessage\": \"Validación de reCAPTCHA fallida: timeout-or-duplicate\""
echo -e "}${NC}"

echo ""
echo -e "${YELLOW}❌ Estructura INCORRECTA (con duplicación):${NC}"
echo -e "${RED}{"
echo -e "  \"data\": {"
echo -e "    \"data\": { /* contenido duplicado */ },"
echo -e "    \"success\": false,"
echo -e "    \"errorMessage\": \"...\""
echo -e "  },"
echo -e "  \"success\": false,"
echo -e "  \"errorMessage\": \"Bad Request: {JSON completo duplicado}\""
echo -e "}${NC}"

echo ""
echo -e "${GREEN}✅ Si ves la estructura correcta, el fix está funcionando!${NC}"
echo -e "${RED}❌ Si ves la estructura incorrecta, necesitas recompilar el gateway${NC}"

echo ""
echo -e "${BLUE}🔄 Para aplicar el fix:${NC}"
echo "1. cd /Users/maxhoustonramirezmartel/code/personales/mcp-folder/api-gateway"
echo "2. go build -o api-gateway"
echo "3. ./api-gateway"
echo "4. ./test_recaptcha_fix.sh"
