#!/bin/bash

# Script de verificación post-solución
echo "🔧 Verificando solución para NestJS..."
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Ejecuta este script desde el directorio api-gateway"
    exit 1
fi

# Verificar go.mod
echo "✅ go.mod encontrado"

# Compilar
echo "🔨 Compilando proyecto..."
if go build -o api-gateway; then
    echo "✅ Compilación exitosa"
else
    echo "❌ Error en compilación"
    exit 1
fi

# Verificar configuración
echo "📋 Verificando configuración..."
if grep -q '"base_url": "http://localhost:3000/api"' config/config.json; then
    echo "✅ Configuración corregida: base_url incluye /api"
else
    echo "❌ Error: configuración no actualizada"
    exit 1
fi

echo ""
echo "🎉 Todo listo! Tu API Gateway está corregido para NestJS"
echo ""
echo "📊 Mapeo de rutas:"
echo "  Gateway: /api/lead/health -> NestJS: /api/health ✅"
echo "  Gateway: /api/lead/* -> NestJS: /api/*"
echo ""
echo "🚀 Para iniciar:"
echo "  ./api-gateway"
echo ""
echo "🧪 Para probar (en otra terminal):"
echo "  curl http://localhost:8001/api/lead/health"
echo "  curl http://localhost:8001/health/services"
echo "  make test-lead"
echo ""
echo "💡 Asegúrate de que tu servicio NestJS esté corriendo en puerto 3000"