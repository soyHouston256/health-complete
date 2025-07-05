# 🐳 Correcciones para Transición a Docker

## 📋 Problemas Identificados y Solucionados

### 1. **Panic en Circuit Breaker** ❌➡️✅
**Problema**: El middleware del circuit breaker causaba panic con `interface conversion: interface is nil, not error`

**Archivo**: `api-gateway/middleware/circuit_breaker.go`
```go
// ❌ Antes (línea 390):
return result.(error)

// ✅ Después:
return nil
```

**Causa**: Intentaba convertir `nil` a `error` cuando no había errores.

### 2. **Health Check Endpoints Inconsistentes** ❌➡️✅
**Problema**: Diferencias entre docker-compose.yml y configuración del API Gateway

**Archivos corregidos**:
- `docker-compose.yml`: Todos los health checks ahora usan `/health`
- `api-gateway/config/config.json`: Todos los servicios usan endpoint `/health`

```yaml
# ✅ Ahora todos usan:
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
```

### 3. **URL Base del Servicio Captcha** ❌➡️✅
**Problema**: Duplicación de `/recaptcha` en la URL

```json
// ❌ Antes:
"base_url": "http://ms-validar-recaptcha:1323/recaptcha"

// ✅ Después:
"base_url": "http://ms-validar-recaptcha:1323"
```

### 4. **Configuración de Base de Datos Hardcodeada** ❌➡️✅
**Problema**: `ms-gestion-gestor` usaba `localhost` en lugar de nombres de contenedores Docker

**Archivo**: `ms-gestion-gestor/main.py`
```python
# ❌ Antes:
host_name = "localhost"
password_db = "root"

# ✅ Después:
host_name = os.getenv("MYSQL_HOST", "localhost")
password_db = os.getenv("MYSQL_PASSWORD", "root")
```

**Docker-compose.yml**: Agregadas variables de entorno:
```yaml
environment:
  - MYSQL_HOST=mysql
  - MYSQL_PASSWORD=pass_personas
  - MYSQL_DATABASE=DB_Personas
depends_on:
  mysql:
    condition: service_healthy
```

## 🚀 Cómo Aplicar las Correcciones

### Opción 1: Script Automático (Recomendado)
```bash
# Dar permisos
chmod +x complete_docker_fix.sh diagnose_docker.sh

# Aplicar todas las correcciones
./complete_docker_fix.sh
```

### Opción 2: Paso a Paso
```bash
# 1. Detener servicios
docker-compose down

# 2. Reconstruir con cambios
docker-compose build

# 3. Iniciar bases de datos primero
docker-compose up -d mysql postgres

# 4. Esperar que estén listas
sleep 15

# 5. Iniciar microservicios
docker-compose up -d ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

# 6. Iniciar API Gateway
docker-compose up -d api-gateway
```

## 🧪 Verificación

### Health Checks Directos
```bash
curl http://localhost:3000/health    # Lead (NestJS)
curl http://localhost:8001/health    # Persona (Go)
curl http://localhost:8002/health    # Poliza (FastAPI)
curl http://localhost:6000/health    # Gestor (FastAPI)
curl http://localhost:1323/recaptcha/health  # Recaptcha (Go)
```

### API Gateway
```bash
curl http://localhost:8000/health           # Gateway health
curl http://localhost:8000/health/services  # Services health
```

### Proxy a través del Gateway
```bash
curl http://localhost:8000/leads/           # Debe devolver formato estándar
curl http://localhost:8000/personas/        # Debe devolver formato estándar
curl http://localhost:8000/polizas/productos # Debe devolver formato estándar
curl http://localhost:8000/gestores/        # Debe devolver formato estándar
```

## 🔍 Diagnóstico
```bash
# Script de diagnóstico completo
./diagnose_docker.sh

# Ver logs específicos
docker-compose logs api-gateway
docker-compose logs ms-gestion-lead

# Estado de contenedores
docker-compose ps
```

## 📊 Diferencias: Ejecución Directa vs Docker

| Aspecto | Ejecución Directa | Docker |
|---------|-------------------|--------|
| **Host DB** | `localhost` | `mysql`, `postgres` |
| **Networking** | Host network | Bridge network |
| **Variables ENV** | Archivo local | docker-compose.yml |
| **Dependencies** | Manual | `depends_on` |
| **Health Checks** | No automáticos | Automáticos |

## 🐛 Troubleshooting

### Si un microservicio no inicia:
```bash
# Ver logs detallados
docker-compose logs [servicio]

# Verificar variables de entorno
docker-compose exec [servicio] env

# Verificar conectividad de red
docker-compose exec [servicio] ping mysql
```

### Si el API Gateway da errores 502:
```bash
# Verificar health checks
curl http://localhost:8000/health/services

# Ver logs del gateway
docker-compose logs api-gateway

# Verificar que los microservicios respondan
curl http://localhost:3000/health
```

### Si hay problemas de base de datos:
```bash
# Verificar conexión MySQL
docker-compose exec mysql mysql -u root -ppass_personas -e "SHOW DATABASES;"

# Verificar conexión PostgreSQL
docker-compose exec postgres psql -U postgres -c "\l"
```

## ✅ Estado Esperado Final

Después de aplicar las correcciones:

1. **Todos los contenedores healthy**: `docker-compose ps` muestra todos como "Up (healthy)"
2. **Health checks funcionando**: Todos los endpoints `/health` responden 200
3. **API Gateway operacional**: `/health` y `/health/services` funcionan
4. **Proxy funcionando**: Las requests a través del gateway devuelven respuestas en formato estándar
5. **Sin panics**: No más errores de circuit breaker en los logs

## 📝 Archivos Modificados

- ✅ `api-gateway/middleware/circuit_breaker.go`
- ✅ `api-gateway/config/config.json`
- ✅ `docker-compose.yml`
- ✅ `ms-gestion-gestor/main.py`
- ➕ Scripts de diagnóstico y corrección

## 🎯 Próximos Pasos

1. Ejecutar `./complete_docker_fix.sh`
2. Verificar con `./diagnose_docker.sh`
3. Probar endpoints específicos con `curl`
4. Si todo funciona, hacer commit de los cambios

## 🔧 Comandos de Mantenimiento

### Reinicio completo del stack:
```bash
docker-compose down && docker-compose up -d
```

### Ver logs en tiempo real:
```bash
docker-compose logs -f api-gateway
```

### Reconstruir un servicio específico:
```bash
docker-compose build [servicio] && docker-compose up -d [servicio]
```

### Limpiar y empezar desde cero:
```bash
docker-compose down --volumes --remove-orphans
docker-compose build --no-cache
docker-compose up -d
```

## 💡 Mejores Prácticas para Docker

1. **Usa variables de entorno** en lugar de valores hardcodeados
2. **Implementa health checks** en todos los servicios
3. **Configura depends_on** para orden de inicio correcto
4. **Usa redes custom** para aislamiento
5. **Implementa graceful shutdown** en tus aplicaciones
6. **Monitorea logs** regularmente

## 🚨 Alertas Importantes

- ⚠️ **Siempre verifica health checks** antes de considerar un servicio listo
- ⚠️ **Los nombres de hosts cambian** de `localhost` a nombres de contenedores
- ⚠️ **Las variables de entorno** deben configurarse en docker-compose.yml
- ⚠️ **Los puertos internos** pueden diferir de los externos mapeados

---

**¡Con estas correcciones, tu API Gateway debería funcionar perfectamente en Docker! 🎉**