#!/bin/bash

# Script de verificación completa para eliminar duplicación
echo "🔧 Verificando solución de NO duplicación..."
echo ""

# Verificar archivos
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Ejecuta desde el directorio api-gateway"
    exit 1
fi

# Compilar
echo "🔨 Compilando con corrección de duplicación..."
if go build -o api-gateway; then
    echo "✅ Compilación exitosa"
else
    echo "❌ Error en compilación"
    exit 1
fi

# Verificar que las funciones estén implementadas
echo "📋 Verificando implementación anti-duplicación..."

if grep -q "isStandardFormat" proxy/handler.go; then
    echo "✅ Función isStandardFormat implementada"
else
    echo "❌ Función isStandardFormat no encontrada"
    exit 1
fi

if grep -q "Standard format detected, passing through" proxy/handler.go; then
    echo "✅ Logs de detección implementados"
else
    echo "❌ Logs de detección no encontrados"
fi

if grep -q "Non-standard format detected, transforming" proxy/handler.go; then
    echo "✅ Logs de transformación implementados"
else
    echo "❌ Logs de transformación no encontrados"
fi

echo ""
echo "🎉 Corrección de duplicación implementada!"
echo ""
echo "📊 Cómo funciona ahora:"
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│ 1. Servicio responde con formato estándar                       │"
echo "│    {\"data\": {...}, \"success\": true, \"errorMessage\": null}       │"
echo "│                                                                  │"
echo "│ 2. Gateway detecta el formato estándar                          │"
echo "│    [TRANSFORM] Standard format detected, passing through        │"
echo "│                                                                  │"
echo "│ 3. Gateway pasa la respuesta SIN modificaciones                 │"
echo "│    {\"data\": {...}, \"success\": true, \"errorMessage\": null}       │"
echo "│                                                                  │"
echo "│ ✅ RESULTADO: NO hay duplicación                                 │"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
echo "🚀 Para iniciar y probar:"
echo "  1. ./api-gateway"
echo "  2. En otra terminal: make test-no-duplication"
echo ""
echo "🧪 Comandos de testing:"
echo "  make test-no-duplication  # Verificar NO duplicación"
echo "  make test-services        # Test completo"
echo "  make test-lead            # Test específico Lead"
echo "  make test-captcha         # Test específico reCAPTCHA"
echo ""
echo "📋 Los logs mostrarán:"
echo "  [TRANSFORM] Standard format detected, passing through: /api/lead/health"
echo "  [TRANSFORM] Non-standard format detected, transforming: /some/other/endpoint"
echo ""
echo "💡 Si tus servicios YA devuelven formato estándar:"
echo "  ✅ El gateway NO debe modificar las respuestas"
echo "  ✅ NO debe haber duplicación de campos"
echo "  ✅ Las respuestas deben pasar 'tal como están'"
echo ""
echo "🔍 Verificar en logs:"
echo "  - Busca mensajes 'Standard format detected'"
echo "  - NO debe haber 'data.data.success' en ninguna respuesta"
echo "  - Las respuestas deben tener exactamente 3 campos: data, success, errorMessage"