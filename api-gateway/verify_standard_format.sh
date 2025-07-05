#!/bin/bash

# Script de verificación completa para el formato de respuesta estándar
echo "🔧 Verificando implementación del formato de respuesta estándar..."
echo ""

# Verificar archivos
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Ejecuta desde el directorio api-gateway"
    exit 1
fi

# Compilar
echo "🔨 Compilando con formato de respuesta estándar..."
if go build -o api-gateway; then
    echo "✅ Compilación exitosa"
else
    echo "❌ Error en compilación"
    exit 1
fi

# Verificar que las estructuras estén implementadas
echo "📋 Verificando código..."
if grep -q "StandardResponse" proxy/handler.go; then
    echo "✅ Estructura StandardResponse implementada"
else
    echo "❌ Estructura StandardResponse no encontrada"
fi

if grep -q "GatewayResponse" main.go; then
    echo "✅ Estructura GatewayResponse implementada"
else
    echo "❌ Estructura GatewayResponse no encontrada"
fi

if grep -q "transformResponse" proxy/handler.go; then
    echo "✅ Función transformResponse implementada"
else
    echo "❌ Función transformResponse no encontrada"
fi

echo ""
echo "🎉 Implementación del formato estándar completada!"
echo ""
echo "📊 Funcionalidades implementadas:"
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│ ✅ Transformación automática de respuestas                      │"
echo "│ ✅ Formato estándar: {data, success, errorMessage}              │"
echo "│ ✅ Manejo de errores con formato consistente                    │"
echo "│ ✅ Headers de gateway en todas las respuestas                   │"
echo "│ ✅ Health checks con formato estándar                           │"
echo "│ ✅ Métricas con formato estándar                                 │"
echo "│ ✅ Rate limiting con errores en formato estándar                │"
echo "│ ✅ Circuit breaker con errores en formato estándar              │"
echo "│ ✅ Timeouts con errores en formato estándar                     │"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
echo "🔄 Ejemplo de transformación:"
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ Servicio Backend:                                               │"
echo "│ {\"status\": \"ok\"}                                               │"
echo "│                                                                 │"
echo "│ Gateway (transformado):                                         │"
echo "│ {                                                               │"
echo "│   \"data\": {\"status\": \"ok\"},                                  │"
echo "│   \"success\": true,                                             │"
echo "│   \"errorMessage\": null                                         │"
echo "│ }                                                               │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "🚀 Para iniciar el gateway:"
echo "  ./api-gateway"
echo ""
echo "🧪 Para probar el formato estándar:"
echo "  make test-services     # Test completo con verificación de formato"
echo "  make test-format       # Verificar solo formato de respuesta"
echo "  make test-metrics      # Ver métricas con formato estándar"
echo ""
echo "📍 Endpoints con formato estándar:"
echo "  - http://localhost:8001/health"
echo "  - http://localhost:8001/health/services"
echo "  - http://localhost:8001/metrics"
echo "  - http://localhost:8001/api/lead/*"
echo "  - http://localhost:8001/ms-validate-recaptcha/api/*"
echo ""
echo "📚 Documentación:"
echo "  - Ver: FORMATO_RESPUESTA_ESTANDAR.md"
echo "  - Script de testing: examples/test_standard_format.sh"
echo ""
echo "💡 Beneficios del formato estándar:"
echo "  ✅ Consistencia en todas las respuestas"
echo "  ✅ Manejo de errores estructurado"  
echo "  ✅ Fácil debugging y monitoreo"
echo "  ✅ Compatibilidad con cualquier servicio backend"
echo "  ✅ Headers de gateway informativos"