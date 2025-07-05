# 🔧 Solución al Problema de Ruteo NestJS

## ❌ **Problema Original**
```bash
curl http://localhost:8001/api/lead/health
# Error: {"message":"Cannot GET /health","error":"Not Found","statusCode":404}
```

**Causa:** El gateway estaba enviando requests a `http://localhost:3000/health` en lugar de `http://localhost:3000/api/health`.

## ✅ **Solución Implementada**

### **1. Configuración Corregida**
```json
{
  "name": "lead",
  "base_url": "http://localhost:3000/api",  // ← Agregado /api
  "prefix": "/api/lead",
  "health_check": {
    "endpoint": "/health"  // Se combina con base_url
  }
}
```

### **2. Ruteo Mejorado**
- **Request:** `http://localhost:8001/api/lead/health`
- **Proceso:** Remover prefix `/api/lead` → queda `/health`
- **Resultado:** `http://localhost:3000/api` + `/health` = `http://localhost:3000/api/health` ✅

## 🧪 **Testing Después de la Solución**

### **1. Compilar y reiniciar**
```bash
go build -o api-gateway
./api-gateway
```

### **2. Probar el health check**
```bash
curl http://localhost:8001/api/lead/health
# Esperado: {"status": "ok"}
```

### **3. Testing completo**
```bash
make test-lead
# O usar el script completo:
./examples/test_your_services.sh
```

## 📊 **Mapeo de Rutas Actual**

| Gateway Request | Servicio Destino | Descripción |
|-----------------|-------------------|-------------|
| `GET /api/lead/health` | `http://localhost:3000/api/health` | Health check |
| `GET /api/lead/` | `http://localhost:3000/api/` | Endpoint raíz |
| `GET /api/lead/users` | `http://localhost:3000/api/users` | Cualquier endpoint |
| `POST /api/lead/auth/login` | `http://localhost:3000/api/auth/login` | Login |
| `GET /api/recaptcha/verify` | `http://localhost:1323/verify` | Captcha |

## 🔍 **Logs de Debug**

Con los cambios, ahora verás logs como:
```
[PROXY] GET /api/lead/health -> http://localhost:3000/api/health
[INFO] 2024-06-29 15:04:05 [lead] GET /api/lead/health - 200 - 45ms - 127.0.0.1
```

## 🚨 **Troubleshooting**

### **Si aún no funciona:**

1. **Verificar que NestJS esté corriendo:**
```bash
curl http://localhost:3000/api/health
# Debe responder: {"status": "ok"}
```

2. **Verificar el gateway:**
```bash
curl http://localhost:8001/health
# Debe responder con status del gateway
```

3. **Ver logs detallados:**
```bash
# Reiniciar gateway y ver logs de proxy
./api-gateway
# En otra terminal:
curl http://localhost:8001/api/lead/health
```

### **Configuración alternativa (si necesitas más control):**

Si tu NestJS tiene una estructura diferente, puedes ajustar la configuración:

```json
{
  "name": "lead",
  "base_url": "http://localhost:3000",
  "prefix": "/api/lead",
  "path_rewrite": {
    "/api/lead": "/api"  // Funcionalidad futura
  }
}
```

## ✅ **Verificación Final**

Después de aplicar los cambios, estos comandos deben funcionar:

```bash
# Health check específico
curl http://localhost:8001/api/lead/health

# Health check de todos los servicios
curl http://localhost:8001/health/services

# Endpoint raíz del lead service
curl http://localhost:8001/api/lead/

# Test completo
make test-services
```

## 🎯 **Próximos Pasos**

1. **✅ Verificar que funciona** con tu servicio NestJS
2. **🔧 Ajustar endpoints** específicos si es necesario
3. **📊 Habilitar métricas** y monitoreo
4. **🔐 Configurar autenticación** si la necesitas

---

💡 **Tip:** Usa `make test-lead` para verificar rápidamente que el ruteo funciona correctamente.
