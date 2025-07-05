#!/bin/bash

echo "☁️ SOLUCIÓN ESPECÍFICA PARA EL ERROR DE AWS DEPLOYMENT"
echo "======================================================"
echo ""

echo "🔍 El error indica que faltan Dockerfiles en algunos microservicios"
echo "Vamos a crear los Dockerfiles faltantes y optimizar para AWS"
echo ""

echo "📋 1. Verificando estructura actual del proyecto..."
echo "=================================================="

# Verificar qué microservicios existen y cuáles tienen Dockerfile
services=("api-gateway" "ms-gestion-lead" "ms-gestion-persona" "ms-gestion-poliza" "ms-gestion-gestor" "ms-validar-recaptcha")

echo "Servicios encontrados y sus Dockerfiles:"
for service in "${services[@]}"; do
    if [ -d "$service" ]; then
        echo "✅ $service/ - directorio existe"
        if [ -f "$service/Dockerfile" ]; then
            echo "   ✅ Dockerfile existe"
        else
            echo "   ❌ Dockerfile FALTANTE - será creado"
        fi
    else
        echo "❌ $service/ - directorio NO existe"
    fi
done

echo ""
echo "📋 2. Actualizando docker-compose.yml para AWS..."
echo "==============================================="

if [ -f "docker-compose.yml" ]; then
    echo "🔧 Removiendo 'version' obsoleta y optimizando para AWS..."
    
    # Crear backup
    cp docker-compose.yml docker-compose.yml.backup
    
    # Remover línea de version
    sed -i.tmp '/^version:/d' docker-compose.yml
    rm -f docker-compose.yml.tmp 2>/dev/null
    
    echo "✅ docker-compose.yml actualizado"
else
    echo "❌ docker-compose.yml no encontrado"
fi

echo ""
echo "📋 3. Creando Dockerfiles faltantes optimizados para AWS..."
echo "=========================================================="

# Dockerfile para Node.js/NestJS (ms-gestion-lead)
if [ -d "ms-gestion-lead" ] && [ ! -f "ms-gestion-lead/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para ms-gestion-lead (Node.js/NestJS)..."
    
    cat > "ms-gestion-lead/Dockerfile" << 'EOF'
# Etapa de construcción
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Copiar archivos de configuración
COPY package*.json ./
COPY tsconfig*.json ./

# Instalar dependencias
RUN npm ci --legacy-peer-deps && npm cache clean --force

# Copiar código fuente
COPY . .

# Generar cliente Prisma si existe
RUN if [ -f "prisma/schema.prisma" ]; then npx prisma generate; fi

# Compilar TypeScript
RUN npm run build

# Etapa de producción
FROM node:20-alpine AS production

# Instalar dependencias del sistema
RUN apk add --no-cache dumb-init curl

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs && adduser -S nestjs -u 1001

WORKDIR /usr/src/app

# Copiar archivos necesarios
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/package*.json ./

# Copiar Prisma si existe
RUN if [ -d "/usr/src/app/node_modules/.prisma" ]; then \
    cp -r /usr/src/app/node_modules/.prisma ./node_modules/.prisma; fi

USER nestjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["dumb-init", "node", "dist/main.js"]
EOF
    echo "   ✅ ms-gestion-lead/Dockerfile creado"
fi

# Dockerfile para Go (ms-gestion-persona)
if [ -d "ms-gestion-persona" ] && [ ! -f "ms-gestion-persona/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para ms-gestion-persona (Go)..."
    
    cat > "ms-gestion-persona/Dockerfile" << 'EOF'
# Etapa de construcción
FROM golang:1.21-alpine AS builder

# Instalar dependencias
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copiar go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Etapa de producción
FROM alpine:latest

# Instalar dependencias
RUN apk --no-cache add ca-certificates curl && \
    adduser -D -s /bin/sh appuser

WORKDIR /home/appuser/

# Copiar binario
COPY --from=builder /app/main .
COPY --from=builder /app/config ./config

# Cambiar permisos
RUN chown appuser:appuser main && chmod +x main

USER appuser

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

CMD ["./main"]
EOF
    echo "   ✅ ms-gestion-persona/Dockerfile creado"
fi

# Dockerfile para Python/FastAPI (ms-gestion-poliza)
if [ -d "ms-gestion-poliza" ] && [ ! -f "ms-gestion-poliza/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para ms-gestion-poliza (Python/FastAPI)..."
    
    cat > "ms-gestion-poliza/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Configurar variables de entorno
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root
RUN adduser --disabled-password --gecos '' appuser

WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Cambiar permisos
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8002

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8002/health || exit 1

CMD ["python", "main.py"]
EOF
    echo "   ✅ ms-gestion-poliza/Dockerfile creado"
fi

# Dockerfile para Python/FastAPI (ms-gestion-gestor)
if [ -d "ms-gestion-gestor" ] && [ ! -f "ms-gestion-gestor/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para ms-gestion-gestor (Python/FastAPI)..."
    
    cat > "ms-gestion-gestor/Dockerfile" << 'EOF'
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root
RUN adduser --disabled-password --gecos '' appuser

WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Cambiar permisos
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 6000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:6000/health || exit 1

CMD ["python", "main.py"]
EOF
    echo "   ✅ ms-gestion-gestor/Dockerfile creado"
fi

# Dockerfile para Go (ms-validar-recaptcha)
if [ -d "ms-validar-recaptcha" ] && [ ! -f "ms-validar-recaptcha/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para ms-validar-recaptcha (Go)..."
    
    cat > "ms-validar-recaptcha/Dockerfile" << 'EOF'
# Etapa de construcción
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copiar go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Etapa de producción
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl && \
    adduser -D -s /bin/sh appuser

WORKDIR /home/appuser/

# Copiar binario
COPY --from=builder /app/main .

RUN chown appuser:appuser main && chmod +x main

USER appuser

EXPOSE 1323

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:1323/recaptcha/health || exit 1

CMD ["./main"]
EOF
    echo "   ✅ ms-validar-recaptcha/Dockerfile creado"
fi

# Verificar/crear Dockerfile para API Gateway si no existe
if [ -d "api-gateway" ] && [ ! -f "api-gateway/Dockerfile" ]; then
    echo "📝 Creando Dockerfile para api-gateway (Go)..."
    
    cat > "api-gateway/Dockerfile" << 'EOF'
# Etapa de construcción
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copiar go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Etapa de producción
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl && \
    adduser -D -s /bin/sh appuser

WORKDIR /home/appuser/

# Copiar binario y configuración
COPY --from=builder /app/main .
COPY --from=builder /app/config ./config

RUN chown -R appuser:appuser . && chmod +x main

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["./main"]
EOF
    echo "   ✅ api-gateway/Dockerfile creado"
fi

echo ""
echo "📋 4. Creando script de deployment simplificado para AWS..."
echo "========================================================="

cat > "deploy-aws-simple.sh" << 'EOF'
#!/bin/bash

echo "🚀 DEPLOYMENT SIMPLIFICADO EN AWS"
echo "================================="
echo ""

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado"
    exit 1
fi

# Limpiar deployment previo
echo "🧹 Limpiando deployment previo..."
docker-compose down --remove-orphans 2>/dev/null || true

# Limpiar imágenes huérfanas
echo "🗑️ Limpiando imágenes..."
docker image prune -f

# Build con más detalles
echo ""
echo "🏗️ Construyendo servicios..."
docker-compose build --no-cache --parallel

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error en el build. Verificando problemas..."
    
    # Verificar Dockerfiles
    echo "📋 Verificando Dockerfiles:"
    for service in api-gateway ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-gestion-gestor ms-validar-recaptcha; do
        if [ -d "$service" ]; then
            if [ -f "$service/Dockerfile" ]; then
                echo "  ✅ $service/Dockerfile"
            else
                echo "  ❌ $service/Dockerfile FALTANTE"
            fi
        else
            echo "  ⚠️ $service/ directorio no existe"
        fi
    done
    
    echo ""
    echo "💡 Soluciones:"
    echo "1. Verificar que todos los Dockerfiles existen"
    echo "2. Verificar que los archivos de dependencias existen (package.json, requirements.txt, go.mod)"
    echo "3. Ejecutar: ./fix-aws-dockerfiles.sh"
    
    exit 1
fi

# Iniciar servicios
echo ""
echo "🚀 Iniciando servicios..."
docker-compose up -d

# Esperar y verificar
echo ""
echo "⏳ Esperando que los servicios estén listos..."
sleep 30

echo ""
echo "📊 Estado de los servicios:"
docker-compose ps

echo ""
echo "🏥 Verificando health checks..."
services=("8000:gateway" "3000:lead" "8001:persona" "8002:poliza" "6000:gestor" "1323:recaptcha")

for service in "${services[@]}"; do
    port=${service%:*}
    name=${service#*:}
    echo -n "  $name ($port): "
    
    if [ "$name" == "recaptcha" ]; then
        url="http://localhost:$port/recaptcha/health"
    else
        url="http://localhost:$port/health"
    fi
    
    if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAIL"
    fi
done

# Obtener IP pública si está en AWS
PUBLIC_IP=$(curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")

echo ""
echo "🎉 DEPLOYMENT COMPLETADO"
echo "========================"
echo ""
echo "🌐 URLs de acceso:"
echo "  API Gateway: http://$PUBLIC_IP:8000"
echo "  Health Check: http://$PUBLIC_IP:8000/health"
echo "  Services Health: http://$PUBLIC_IP:8000/health/services"
echo ""
echo "📋 Comandos útiles:"
echo "  Ver logs: docker-compose logs -f"
echo "  Ver estado: docker-compose ps"
echo "  Parar servicios: docker-compose down"
EOF

chmod +x deploy-aws-simple.sh

echo ""
echo "📋 5. Creando .dockerignore para optimizar builds..."
echo "=================================================="

# Crear .dockerignore básico para cada servicio si no existe
for service in "${services[@]}"; do
    if [ -d "$service" ] && [ ! -f "$service/.dockerignore" ]; then
        echo "📝 Creando .dockerignore para $service..."
        
        cat > "$service/.dockerignore" << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.vscode
.idea
*.log
dist
build
.DS_Store
Thumbs.db
*.tmp
*.temp
.venv
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env
pip-log.txt
pip-delete-this-directory.txt
.coverage
.pytest_cache
htmlcov
.tox
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis
.mypy_cache
.dmypy.json
dmypy.json
EOF
        echo "   ✅ $service/.dockerignore creado"
    fi
done

echo ""
echo "✅ CORRECCIÓN COMPLETADA PARA AWS"
echo "================================="
echo ""
echo "📁 Archivos creados/modificados:"
echo "  ✅ Dockerfiles faltantes creados para todos los servicios"
echo "  ✅ docker-compose.yml actualizado (version removida)"
echo "  ✅ deploy-aws-simple.sh - script de deployment simplificado"
echo "  ✅ .dockerignore files creados para optimizar builds"
echo ""
echo "🚀 Para desplegar en AWS:"
echo ""
echo "1. 📤 Subir todos los archivos a tu instancia AWS:"
echo "   scp -i tu-key.pem -r ./* ubuntu@tu-instancia:~/pacifico/health-complete/"
echo ""
echo "2. 🔐 Conectar a la instancia:"
echo "   ssh -i tu-key.pem ubuntu@tu-instancia"
echo ""
echo "3. 📂 Ir al directorio del proyecto:"
echo "   cd ~/pacifico/health-complete"
echo ""
echo "4. 🚀 Ejecutar deployment:"
echo "   ./deploy-aws-simple.sh"
echo ""
echo "🔧 Si el error persiste:"
echo "  - Verificar que todos los archivos se subieron correctamente"
echo "  - Verificar que Docker y Docker Compose están instalados"
echo "  - Verificar que la instancia tiene suficientes recursos (mínimo 2GB RAM)"
echo ""
echo "📋 Security Groups necesarios en AWS:"
echo "  - Puerto 22 (SSH): Solo tu IP"
echo "  - Puerto 8000 (HTTP): 0.0.0.0/0 para acceso público"
echo ""
echo "🎯 Tu aplicación estará disponible en:"
echo "  http://TU-IP-PUBLICA-AWS:8000"