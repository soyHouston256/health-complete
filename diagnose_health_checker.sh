#!/bin/bash

echo "🔍 Diagnóstico específico del Health Checker"
echo "============================================"
echo ""

echo "1. 🏥 Verificando endpoint /health de cada microservicio:"
echo "========================================================="

echo "Lead Service (puerto 3000):"
curl -s http://localhost:3000/health | jq . 2>/dev/null || echo "❌ No responde o no es JSON válido"
echo ""

echo "Persona Service (puerto 8001):"
curl -s http://localhost:8001/health | jq . 2>/dev/null || echo "❌ No responde o no es JSON válido"
echo ""

echo "Poliza Service (puerto 8002):"
curl -s http://localhost:8002/health | jq . 2>/dev/null || echo "❌ No responde o no es JSON válido"
echo ""

echo "Gestor Service (puerto 6000):"
curl -s http://localhost:6000/health | jq . 2>/dev/null || echo "❌ No responde o no es JSON válido"
echo ""

echo "Recaptcha Service (puerto 1323):"
curl -s http://localhost:1323/recaptcha/health | jq . 2>/dev/null || echo "❌ No responde o no es JSON válido"
echo ""

echo "2. 🌐 Verificando conectividad desde API Gateway:"
echo "=================================================="

echo "Ping desde API Gateway a ms-gestion-lead:"
docker-compose exec api-gateway ping -c 2 ms-gestion-lead 2>/dev/null || echo "❌ No puede hacer ping"
echo ""

echo "Curl desde API Gateway a lead health:"
docker-compose exec api-gateway curl -s http://ms-gestion-lead:3000/health 2>/dev/null || echo "❌ No puede conectar"
echo ""

echo "Curl desde API Gateway a persona health:"
docker-compose exec api-gateway curl -s http://ms-gestion-persona:8001/health 2>/dev/null || echo "❌ No puede conectar"
echo ""

echo "3. 📊 Estado actual del health checker del API Gateway:"
echo "======================================================="

echo "Health services status via Gateway:"
curl -s http://localhost:8000/health/services | jq '.data.services' 2>/dev/null || echo "❌ No puede obtener estado"
echo ""

echo "4. 🔍 Logs del health checker:"
echo "=============================="
echo "Logs recientes que mencionen 'health':"
docker-compose logs api-gateway | grep -i health | tail -10
echo ""

echo "5. 🐳 Verificando configuración de red Docker:"
echo "==============================================="
echo "Contenedores en la red pacifico_network:"
docker network inspect mcp-folder_pacifico_network 2>/dev/null | jq -r '.[0].Containers | keys[] as $k | "\($k): \(.[k].Name)"' 2>/dev/null || echo "No se puede inspeccionar la red"
echo ""

echo "6. 🔧 Verificando configuración del health checker:"
echo "==================================================="
echo "Configuración de health checks en config.json:"
docker-compose exec api-gateway cat config/config.json | jq '.gateway.services[] | {name: .name, health_check: .health_check}' 2>/dev/null || echo "No se puede leer configuración"
echo ""

echo "7. 🧪 Prueba manual del health checker URLs:"
echo "============================================"

echo "URLs que el health checker debería usar:"
echo "- Lead: http://ms-gestion-lead:3000/health"
echo "- Persona: http://ms-gestion-persona:8001/health"
echo "- Poliza: http://ms-gestion-poliza:8002/health"
echo "- Gestor: http://ms-gestion-gestor:6000/health"
echo "- Recaptcha: http://ms-validar-recaptcha:1323/recaptcha/health"
echo ""

echo "Probando desde dentro del API Gateway:"
docker-compose exec api-gateway sh -c "
  echo 'Lead:' && curl -s http://ms-gestion-lead:3000/health
  echo 'Persona:' && curl -s http://ms-gestion-persona:8001/health  
  echo 'Poliza:' && curl -s http://ms-gestion-poliza:8002/health
  echo 'Gestor:' && curl -s http://ms-gestion-gestor:6000/health
  echo 'Recaptcha:' && curl -s http://ms-validar-recaptcha:1323/recaptcha/health
" 2>/dev/null || echo "❌ No se puede ejecutar desde el contenedor"

echo ""
echo "8. 📈 Información adicional:"
echo "============================"
echo "Estado de contenedores:"
docker-compose ps | grep -E "(api-gateway|ms-gestion|ms-validar)"
echo ""

echo "🎯 DIAGNÓSTICO COMPLETADO"
echo "========================="
echo "Si algún health check falla desde el API Gateway pero funciona desde el host,"
echo "probablemente hay un problema de:"
echo "1. Configuración de red Docker"
echo "2. Configuración incorrecta de URLs en config.json"
echo "3. Timing - servicios no listos cuando el gateway inicia"
echo "4. Health checker implementación del Gateway"
