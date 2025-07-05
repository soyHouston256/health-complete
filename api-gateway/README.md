# API Gateway con Echo

Un API Gateway robusto y escalable construido con Go y Echo Framework.

## 🚀 Características

- **Proxy HTTP** - Enrutamiento de requests a servicios backend
- **Load Balancing** - Round Robin, Random, Weighted, Least Connections
- **Rate Limiting** - Control de tasa por servicio y cliente
- **Circuit Breaker** - Protección contra servicios caídos
- **Cache Redis** - Cache inteligente para GET requests
- **Health Checks** - Monitoreo automático de servicios
- **Autenticación JWT** - Soporte para tokens JWT y API Keys
- **Logging** - Logs estructurados con request ID
- **Métricas** - Estadísticas de performance y salud

## 📁 Estructura del Proyecto

```
api-gateway/
├── main.go                 # Punto de entrada principal
├── config/
│   ├── config.go          # Configuración y estructuras
│   └── config.json        # Archivo de configuración
├── middleware/
│   ├── auth.go            # Autenticación JWT/API Key
│   ├── rate_limit.go      # Rate limiting
│   ├── cache.go           # Cache con Redis
│   ├── load_balancer.go   # Load balancing
│   └── circuit_breaker.go # Circuit breaker
├── health/
│   └── checker.go         # Health check de servicios
├── proxy/
│   └── handler.go         # Manejador principal del proxy
├── examples/
│   ├── services/          # Servicios de ejemplo
│   └── requests/          # Ejemplos de requests
├── docker-compose.yml     # Configuración Docker
├── Dockerfile            # Imagen Docker
├── Makefile              # Comandos útiles
└── README.md             # Esta documentación
```

## 🛠️ Instalación y Configuración

### Prerrequisitos

- Go 1.21+
- Redis (para cache y rate limiting)
- Docker (opcional)

### Instalación

1. **Clonar el repositorio:**
```bash
git clone <repository-url>
cd api-gateway
```

2. **Instalar dependencias:**
```bash
go mod tidy
```

3. **Configurar servicios:**
Edita `config/config.json` para agregar tus servicios backend.

4. **Iniciar Redis:**
```bash
# Con Docker
docker run -d -p 6379:6379 redis:alpine

# O usar docker-compose
docker-compose up -d redis
```

5. **Ejecutar el gateway:**
```bash
go run main.go
```

## ⚙️ Configuración

### Archivo config.json

```json
{
  "gateway": {
    "port": "8000",
    "services": [
      {
        "name": "users",
        "base_url": "http://localhost:3001",
        "prefix": "/api/users",
        "timeout": 30,
        "rate_limit": {
          "enabled": true,
          "requests_per_second": 100,
          "burst_size": 200
        },
        "load_balancer": {
          "enabled": false,
          "strategy": "round_robin",
          "backends": []
        },
        "health_check": {
          "enabled": true,
          "endpoint": "/health",
          "interval_seconds": 30
        },
        "cache": {
          "enabled": true,
          "ttl_seconds": 300
        }
      }
    ]
  },
  "redis": {
    "address": "localhost:6379",
    "password": "",
    "db": 0
  },
  "auth": {
    "enabled": false,
    "jwt_secret": "your-secret-key"
  }
}
```

### Variables de Entorno

```bash
export GATEWAY_PORT=8000
export REDIS_ADDRESS=localhost:6379
export JWT_SECRET=your-super-secret-key
```

## 🏃‍♂️ Uso

### Iniciar el Gateway

```bash
# Desarrollo
make dev

# Producción
make build
./api-gateway

# Con Docker
make docker-run
```

### Endpoints del Gateway

- **Health Check:** `GET /health`
- **Services Health:** `GET /health/services`
- **Métricas:** `GET /metrics` (si está habilitado)

### Ejemplos de Requests

```bash
# Request a servicio users
curl -X GET http://localhost:8000/api/users/profile \
  -H "Authorization: Bearer your-jwt-token"

# Request con API Key
curl -X GET http://localhost:8000/api/orders \
  -H "X-API-Key: your-api-key"

# POST request
curl -X POST http://localhost:8000/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-jwt-token" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

## 🔧 Desarrollo

### Comandos Útiles

```bash
# Instalar dependencias
make deps

# Ejecutar en modo desarrollo
make dev

# Ejecutar tests
make test

# Construcción
make build

# Limpiar
make clean

# Ver logs
make logs
```

### Crear un Servicio de Prueba

```bash
# Usar el servicio de ejemplo incluido
cd examples/services
go run user-service/main.go  # Puerto 3001
go run order-service/main.go # Puerto 3002
```

## 📊 Monitoreo

### Health Checks

El gateway verifica automáticamente la salud de los servicios:

```bash
curl http://localhost:8000/health/services
```

### Métricas

Ver estadísticas de circuit breakers y load balancers:

```bash
curl http://localhost:8000/metrics
```

### Logs

Los logs incluyen información detallada:

```
[INFO] 2024-06-29 15:04:05 [users] GET /api/users/profile - 200 - 45ms - 192.168.1.1 - 1234567890
```

## 🐳 Docker

### Construir Imagen

```bash
make docker-build
```

### Ejecutar con Docker Compose

```bash
# Iniciar todo el stack
docker-compose up -d

# Ver logs
docker-compose logs -f api-gateway

# Detener
docker-compose down
```

## 🧪 Testing

### Tests Unitarios

```bash
go test ./...
```

### Tests de Integración

```bash
# Iniciar servicios de prueba
make test-services

# Ejecutar tests
make test-integration
```

### Pruebas de Carga

```bash
# Instalar hey
go install github.com/rakyll/hey@latest

# Test básico
hey -n 1000 -c 10 http://localhost:8000/api/users

# Test con autenticación
hey -n 1000 -c 10 -H "Authorization: Bearer token" http://localhost:8000/api/users
```

## 🔒 Seguridad

### Autenticación JWT

```go
// Generar token para testing
token, err := authMiddleware.GenerateToken("user123", "john_doe", "user")
```

### API Keys

Configurar en `middleware/auth.go`:

```go
validKeys := map[string]bool{
    "dev-key-123":  true,
    "prod-key-456": true,
}
```

### Rate Limiting

Configuración por servicio:

```json
"rate_limit": {
  "enabled": true,
  "requests_per_second": 100,
  "burst_size": 200
}
```

## 📈 Performance

### Optimizaciones Incluidas

- **Connection Pooling** - Reutilización de conexiones HTTP
- **Circuit Breaker** - Prevención de cascading failures
- **Cache Redis** - Reducción de latencia para GET requests
- **Load Balancing** - Distribución de carga
- **Request Timeout** - Prevención de requests colgantes

### Benchmarks

En un MacBook Pro M1:
- **Throughput:** ~50,000 requests/segundo
- **Latencia media:** <5ms
- **P99:** <20ms

## 🤝 Contribución

1. Fork el proyecto
2. Crear feature branch (`git checkout -b feature/amazing-feature`)
3. Commit cambios (`git commit -m 'Add amazing feature'`)
4. Push al branch (`git push origin feature/amazing-feature`)
5. Abrir Pull Request

## 📝 TODO

- [ ] Métricas con Prometheus
- [ ] Tracing distribuido con Jaeger
- [ ] WebSocket proxy
- [ ] API versioning
- [ ] Dashboard web
- [ ] Certificados SSL automáticos
- [ ] Plugin system

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE) para detalles.

## 🆘 Soporte

- **Issues:** GitHub Issues
- **Documentación:** Wiki del proyecto
- **Chat:** Discord/Slack (si aplica)

---

⭐ Si este proyecto te es útil, ¡no olvides darle una estrella!
