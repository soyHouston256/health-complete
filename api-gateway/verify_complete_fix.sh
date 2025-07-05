#!/bin/bash

# Verificación final de la configuración actualizada
echo "🔧 Verificando configuración actualizada..."
echo ""

# Verificar archivos
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Ejecuta desde el directorio api-gateway"
    exit 1
fi

# Compilar
echo "🔨 Recompilando con nueva configuración..."
if go build -o api-gateway; then
    echo "✅ Compilación exitosa"
else
    echo "❌ Error en compilación"
    exit 1
fi

# Verificar configuración Lead
echo "📋 Verificando configuración Lead..."
if grep -q '"base_url": "http://localhost:3000/api"' config/config.json; then
    echo "✅ Lead service: base_url correcto"
else
    echo "❌ Lead service: configuración incorrecta"
fi

# Verificar configuración reCAPTCHA
echo "📋 Verificando configuración reCAPTCHA..."
if grep -q '"base_url": "http://localhost:1323/ms-validate-recaptcha/api"' config/config.json; then
    echo "✅ reCAPTCHA service: base_url correcto"
else
    echo "❌ reCAPTCHA service: configuración incorrecta"
fi

echo ""
echo "🎉 Configuración completamente actualizada!"
echo ""
echo "📊 Mapeo de rutas final:"
echo "┌─────────────────────────────────────────────────────────────────────────────────┐"
echo "│ Gateway Request                           │ Servicio Destino                      │"
echo "├─────────────────────────────────────────────────────────────────────────────────┤"
echo "│ /api/lead/health                         │ localhost:3000/api/health             │"
echo "│ /api/lead/*                              │ localhost:3000/api/*                  │"
echo "│ /ms-validate-recaptcha/api/health        │ localhost:1323/ms-validate-recaptcha/ │"
echo "│                                          │ api/health                            │"
echo "│ /ms-validate-recaptcha/api/*             │ localhost:1323/ms-validate-recaptcha/ │"
echo "│                                          │ api/*                                 │"
echo "└─────────────────────────────────────────────────────────────────────────────────┘"
echo ""
echo "🚀 Para iniciar el gateway:"
echo "  ./api-gateway"
echo ""
echo "🧪 Para probar:"
echo "  curl http://localhost:8001/api/lead/health"
echo "  curl http://localhost:8001/ms-validate-recaptcha/api/health"
echo ""
echo "🛠️ Comandos útiles:"
echo "  make test-lead      # Test rápido Lead service"
echo "  make test-captcha   # Test rápido reCAPTCHA service"
echo "  make test-services  # Test completo actualizado"
echo ""
echo "💡 Asegúrate de que ambos servicios estén corriendo:"
echo "  - Lead service en puerto 3000"
echo "  - reCAPTCHA service en puerto 1323"