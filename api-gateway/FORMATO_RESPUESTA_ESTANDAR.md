# 📊 Formato de Respuesta Estándar - API Gateway

## 🎯 **Objetivo**

Tu API Gateway ahora transforma **todas las respuestas** a un formato JSON estándar y consistente, sin importar cómo respondan los servicios backend originalmente.

## 📋 **Estructura de Respuesta Estándar**

### **Formato Base:**
```json
{
    "data": { /* contenido de la respuesta original */ },
    "success": boolean,
    "errorMessage": string | null
}
```

### **Campos:**
- **`data`:** Contiene la respuesta original del servicio backend
- **`success`:** `true` para respuestas exitosas (200-299), `false` para errores
- **`errorMessage`:** Descripción del error si `success: false`, `null` si todo está bien

## ✅ **Ejemplos de Respuestas Exitosas**

### **Health Check del Gateway:**
```json
{
    "data": {
        "status": "healthy",
        "timestamp": "2024-06-29T15:04:05Z",
        "services": 2,
        "version": "1.0.0",
        "uptime": "2h30m15s"
    },
    "success": true,
    "errorMessage": null
}
```

### **Servicio Lead (respuesta exitosa):**
```json
{
    "data": {
        "id": 29,
        "name": "max",
        "lastname": "ramirez", 
        "documentType": "DNID",
        "documentNumber": "46972239",
        "phone": "9189812912",
        "email": "maxr522@gmail.com"
    },
    "success": true,
    "errorMessage": null
}
```

### **Servicio reCAPTCHA (respuesta exitosa):**
```json
{
    "data": {
        "success": true,
        "message": "Servicio de validación de reCAPTCHA funcionando correctamente"
    },
    "success": true,
    "errorMessage": null
}
```

## ❌ **Ejemplos de Respuestas de Error**

### **Validación reCAPTCHA fallida:**
```json
{
    "data": {
        "success": false,
        "score": 0,
        "action": "",
        "challenge_ts": "",
        "hostname": "",
        "error-codes": ["timeout-or-duplicate"]
    },
    "success": false,
    "errorMessage": "Validación de reCAPTCHA fallida: timeout-or-duplicate"
}
```

### **Endpoint no encontrado:**
```json
{
    "data": {
        "code": 404,
        "message": "Cannot GET /nonexistent",
        "path": "/api/lead/nonexistent",
        "method": "GET"
    },
    "success": false,
    "errorMessage": "Not Found: Cannot GET /nonexistent"
}
```

### **Rate Limit Excedido:**
```json
{
    "data": {
        "error": "Rate limit exceeded",
        "retry_after": "2.50 seconds",
        "limit": 100
    },
    "success": false,
    "errorMessage": "Rate limit exceeded"
}
```

### **Servicio No Disponible:**
```json
{
    "data": {
        "code": 502,
        "message": "Service unavailable",
        "path": "/api/lead/health",
        "method": "GET"
    },
    "success": false,
    "errorMessage": "Service unavailable: connection refused"
}
```

## 🔄 **Transformación Automática**

### **Cómo Funciona:**

1. **Request llega al Gateway** → `/api/lead/health`
2. **Gateway hace proxy** → `http://localhost:3000/api/health`
3. **Servicio responde** → `{"status": "ok"}`
4. **Gateway transforma** → Formato estándar con `data`, `success`, `errorMessage`
5. **Cliente recibe** → Respuesta transformada

### **Código de Status HTTP:**
- **Todas las respuestas del gateway** devuelven `HTTP 200 OK`
- **El estado real** se indica en el campo `success`
- **Errores específicos** se detallan en `errorMessage`

## 📍 **Endpoints del Gateway**

| Endpoint | Descripción | Formato Estándar |
|----------|-------------|------------------|
| `GET /health` | Health check del gateway | ✅ |
| `GET /health/services` | Estado de todos los servicios | ✅ |
| `GET /metrics` | Métricas del gateway | ✅ |
| `GET /api/lead/*` | Proxy al servicio Lead | ✅ |
| `GET /ms-validate-recaptcha/api/*` | Proxy al servicio reCAPTCHA | ✅ |

## 🧪 **Testing del Formato**

### **Script de Testing Completo:**
```bash
./examples/test_standard_format.sh
```

### **Comandos Individuales:**
```bash
# Verificar formato
make test-format

# Ver métricas
make test-metrics

# Test completo de servicios
make test-services

# Tests individuales
make test-lead
make test-captcha
```

### **Testing Manual:**
```bash
# Health check
curl http://localhost:8001/health | jq .

# Verificar solo el formato
curl -s http://localhost:8001/health | jq '. | {success, errorMessage}'

# Test de servicio específico
curl http://localhost:8001/api/lead/health | jq .
```

## 🛠️ **Configuración**

### **Habilitación:**
El formato estándar está **siempre habilitado** y no se puede deshabilitar. Todas las respuestas se transforman automáticamente.

### **Headers Adicionales:**
Cada respuesta incluye headers del gateway:
```
X-Gateway: api-gateway
X-Gateway-Version: 1.0.0
X-Response-Time: 2024-06-29T15:04:05Z
Content-Type: application/json
```

## 🔍 **Casos Especiales**

### **Responses No-JSON de Servicios:**
Si un servicio responde con texto plano:
```json
{
    "data": "Texto plano del servicio",
    "success": true,
    "errorMessage": null
}
```

### **Responses Vacías:**
Si un servicio responde vacío:
```json
{
    "data": {},
    "success": true,
    "errorMessage": null
}
```

### **Timeouts de Servicios:**
```json
{
    "data": {
        "code": 504,
        "message": "Gateway Timeout",
        "path": "/api/lead/slow-endpoint",
        "method": "GET"
    },
    "success": false,
    "errorMessage": "Gateway Timeout: request timeout after 30s"
}
```

## 📊 **Métricas y Monitoreo**

### **Endpoint de Métricas:**
```bash
curl http://localhost:8001/metrics
```

**Respuesta:**
```json
{
    "data": {
        "gateway": {
            "uptime_seconds": 3600,
            "total_services": 2,
            "gateway_version": "1.0.0",
            "timestamp": "2024-06-29T15:04:05Z"
        },
        "proxy": {
            "circuit_breakers": { /* estados de circuit breakers */ },
            "load_balancers": { /* estados de load balancers */ }
        }
    },
    "success": true,
    "errorMessage": null
}
```

## 🚨 **Troubleshooting**

### **Verificar que funciona:**
```bash
# 1. Gateway responde con formato estándar
curl http://localhost:8001/health

# 2. Servicios backend funcionan directamente
curl http://localhost:3000/api/health
curl http://localhost:1323/ms-validate-recaptcha/api/health

# 3. Transformación funciona correctamente
curl http://localhost:8001/api/lead/health
```

### **Problemas Comunes:**

1. **Campo `data` vacío:** El servicio backend no responde o responde vacío
2. **`success: false` siempre:** Verifica que los servicios backend estén corriendo
3. **`errorMessage` con timeouts:** Aumenta el timeout en `config.json`

## 💡 **Beneficios**

✅ **Consistencia:** Todas las APIs tienen el mismo formato
✅ **Facilidad de uso:** Los clientes siempre saben qué esperar
✅ **Manejo de errores:** Errores estructurados y consistentes
✅ **Debugging:** Fácil identificar si el error viene del gateway o del servicio
✅ **Monitoreo:** Métricas y logs estructurados
✅ **Compatibilidad:** Funciona con cualquier servicio backend

---

🎯 **Tu API Gateway ahora proporciona una interfaz unificada y consistente para todos tus microservicios, independientemente de cómo implementen sus respuestas originalmente.**
