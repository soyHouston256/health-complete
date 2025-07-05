# 🚀 API Gateway - Configuración Personalizada

Tu API Gateway está configurado para tus servicios específicos:

## 📊 **Servicios Configurados**

### **🎯 Lead Service**
- **URL:** `http://localhost:3000`
- **Gateway Path:** `/api/lead/*`
- **Características:** Cache habilitado (5 min), Rate limit: 100 req/s

### **🔒 Captcha Service (reCAPTCHA)**  
- **URL:** `http://localhost:1323`
- **Gateway Path:** `/api/recaptcha/*`
- **Características:** Cache deshabilitado, Rate limit: 50 req/s

## 🏃‍♂️ **Inicio Rápido**

### **1. Iniciar Redis**
```bash
docker run -d -p 6379:6379 --name redis-gateway redis:alpine
```

### **2. Compilar y ejecutar**
```bash
go build -o api-gateway
./api-gateway
```

### **3. Probar servicios**
```bash
make test-services
```

## 🧪 **Testing**

### **Comandos rápidos:**
```bash
# Health check
curl http://localhost:8001/health

# Test Lead service
curl http://localhost:8001/api/lead/

# Test Captcha service  
curl http://localhost:8001/api/recaptcha/

# Test completo
make test-services
```

### **Con autenticación (si está habilitada):**
```bash
# Generar token
make generate-token USER_ID=user123 USERNAME=john ROLE=user

# Usar token
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8001/api/lead/
```

## ⚙️ **Configuración**

### **Habilitar/Deshabilitar Autenticación:**
```bash
make enable-auth    # Habilitar
make disable-auth   # Deshabilitar
```

### **Configuración actual (config/config.json):**
- **Puerto Gateway:** 8001
- **Autenticación:** Deshabilitada por defecto
- **Cache Redis:** Habilitado para Lead service
- **Rate Limiting:** Habilitado para ambos servicios

## 🛠️ **Comandos Útiles**

```bash
make help           # Ver todos los comandos
make dev            # Desarrollo con hot reload
make test-lead      # Test rápido Lead service
make test-captcha   # Test rápido Captcha service
make health         # Estado del gateway
make load-test      # Prueba de carga
```

## 📍 **Endpoints**

| Endpoint | Servicio | Descripción |
|----------|----------|-------------|
| `GET /health` | Gateway | Health check del gateway |
| `GET /health/services` | Gateway | Estado de todos los servicios |
| `GET,POST /api/lead/*` | Lead | Proxy a tu servicio Lead |
| `GET,POST /api/recaptcha/*` | Captcha | Proxy a tu servicio Captcha |

## 🔧 **Personalización**

### **Agregar nuevo servicio:**
Edita `config/config.json`:
```json
{
  "name": "nuevo-servicio",
  "base_url": "http://localhost:3004",
  "prefix": "/api/nuevo",
  "timeout": 30,
  "rate_limit": {
    "enabled": true,
    "requests_per_second": 50,
    "burst_size": 100
  },
  "health_check": {
    "enabled": true,
    "endpoint": "/health",
    "interval_seconds": 30
  }
}
```

### **Cambiar rate limits:**
```json
"rate_limit": {
  "enabled": true,
  "requests_per_second": 200,  // Cambiar aquí
  "burst_size": 400            // Y aquí
}
```

## 📊 **Monitoreo**

### **Ver estado en tiempo real:**
```bash
# Health check con detalles
curl -s http://localhost:8001/health/services | jq .

# Verificar rate limiting
for i in {1..10}; do curl -w "%{http_code} " http://localhost:8001/api/lead/; done

# Ver headers de cache
curl -v http://localhost:8001/api/lead/ 2>&1 | grep X-Cache
```

## 🚨 **Troubleshooting**

### **Gateway no inicia:**
```bash
# Verificar puerto
lsof -i :8001

# Verificar Redis
docker ps | grep redis

# Ver logs detallados
./api-gateway 2>&1 | tee gateway.log
```

### **Servicios no responden:**
```bash
# Test directo (bypass gateway)
curl http://localhost:3000/    # Lead service
curl http://localhost:1323/    # Captcha service

# Verificar health checks
curl http://localhost:8001/health/services
```

### **Rate limiting muy agresivo:**
```bash
# Deshabilitar temporalmente
# En config.json, cambiar "enabled": false en rate_limit
```

## 🎯 **Próximos Pasos**

1. **✅ Servicios funcionando** - Asegúrate de que tus servicios estén corriendo
2. **🔐 Autenticación** - Habilita auth si necesitas seguridad
3. **📊 Monitoreo** - Agrega métricas personalizadas
4. **🚀 Producción** - Configura Docker para deploy

---

💡 **Tip:** Usa `make help` para ver todos los comandos disponibles
