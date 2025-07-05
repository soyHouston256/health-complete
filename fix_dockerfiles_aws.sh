#!/bin/bash

echo "🐳 DIAGNÓSTICO Y CORRECCIÓN PARA DESPLIEGUE EN AWS"
echo "=================================================="
echo ""

echo "📋 1. Verificando estructura de directorios y Dockerfiles..."
echo "============================================================"

# Función para verificar si existe un directorio y su Dockerfile
check_service() {
    local service_dir=$1
    local service_name=$2
    
    echo "Checking $service_name ($service_dir):"
    
    if [ -d "$service_dir" ]; then
        echo "  ✅ Directorio existe"
        
        if [ -f "$service_dir/Dockerfile" ]; then
            echo "  ✅ Dockerfile existe"
            echo "  📝 Contenido del Dockerfile:"
            head -3 "$service_dir/Dockerfile" | sed 's/^/      /'
        else
            echo "  ❌ Dockerfile NO existe"
            echo "  📁 Archivos en el directorio:"
            ls -la "$service_dir" | head -10 | sed 's/^/      /'
        fi
    else
        echo "  ❌ Directorio NO existe"
        echo "  📁 Directorios disponibles:"
        ls -la . | grep "^d" | grep "ms-" | sed 's/^/      /'
    fi
    echo ""
}

# Verificar cada microservicio
services=(
    "ms-gestion-lead:Lead Service"
    "ms-gestion-persona:Persona Service"
    "ms-gestion-poliza:Poliza Service"
    "ms-gestion-gestor:Gestor Service"
    "ms-validar-recaptcha:Recaptcha Service"
    "api-gateway:API Gateway"
)

for service in "${services[@]}"; do
    dir=${service%:*}
    name=${service#*:}
    check_service "$dir" "$name"
done

echo "📋 2. Verificando docker-compose.yml..."
echo "======================================="

if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml existe"
    echo ""
    echo "🔍 Servicios definidos en docker-compose.yml:"
    grep -E "^  [a-z]" docker-compose.yml | grep -v "^  #" | sed 's/://' | sed 's/^/  /'
    echo ""
    
    echo "🔍 Build contexts definidos:"
    grep -A 2 "build:" docker-compose.yml | grep "context:" | sed 's/^/  /'
else
    echo "❌ docker-compose.yml NO existe"
fi

echo ""
echo "📋 3. Creando Dockerfiles faltantes..."
echo "======================================"

# Función para crear Dockerfile básico según el tipo de servicio
create_dockerfile() {
    local service_dir=$1
    local service_type=$2
    
    if [ ! -f "$service_dir/Dockerfile" ]; then
        echo "📝 Creando Dockerfile para $service_dir ($service_type)..."
        
        case $service_type in
            "nodejs")
                cat > "$service_dir/Dockerfile" << 'EOF'
# Usar imagen base de Node.js
FROM node:20-alpine AS base

# Instalar dumb-init para manejo de procesos
RUN apk add --no-cache dumb-init

# Crear directorio de trabajo
WORKDIR /usr/src/app

# Copiar archivos de configuración de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm ci --legacy-peer-deps && npm cache clean --force

# Copiar código fuente
COPY . .

# Generar cliente Prisma si existe
RUN if [ -f "prisma/schema.prisma" ]; then npx prisma generate; fi

# Compilar TypeScript si existe tsconfig
RUN if [ -f "tsconfig.json" ]; then npm run build; fi

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs && adduser -S nestjs -u 1001

# Cambiar permisos
RUN chown -R nestjs:nodejs /usr/src/app

# Cambiar al usuario no-root
USER nestjs

# Exponer puerto
EXPOSE 3000

# Comando para ejecutar la aplicación
CMD ["dumb-init", "node", "dist/main.js"]
EOF
                ;;
            "go")
                cat > "$service_dir/Dockerfile" << 'EOF'
# Build stage
FROM golang:1.21-alpine AS builder

# Instalar git y ca-certificates
RUN apk add --no-cache git ca-certificates

# Crear directorio de trabajo
WORKDIR /app

# Copiar go mod y descargar dependencias
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Production stage
FROM alpine:latest

# Instalar ca-certificates para HTTPS
RUN apk --no-cache add ca-certificates curl

# Crear directorio de trabajo
WORKDIR /root/

# Copiar binario desde build stage
COPY --from=builder /app/main .

# Copiar archivos de configuración si existen
COPY --from=builder /app/config ./config

# Exponer puerto
EXPOSE 8001

# Comando para ejecutar
CMD ["./main"]
EOF
                ;;
            "python")
                cat > "$service_dir/Dockerfile" << 'EOF'
# Usar imagen base de Python
FROM python:3.11-slim

# Configurar variables de entorno
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY requirements.txt .

# Instalar dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Crear usuario no-root
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Exponer puerto
EXPOSE 6000

# Comando para ejecutar la aplicación
CMD ["python", "main.py"]
EOF
                ;;
        esac
        
        echo "  ✅ Dockerfile creado para $service_dir"
    else
        echo "  ✅ Dockerfile ya existe para $service_dir"
    fi
}

# Detectar tipo de servicio y crear Dockerfile si es necesario
detect_and_create_dockerfile() {
    local service_dir=$1
    
    if [ -d "$service_dir" ]; then
        if [ -f "$service_dir/package.json" ]; then
            create_dockerfile "$service_dir" "nodejs"
        elif [ -f "$service_dir/go.mod" ]; then
            create_dockerfile "$service_dir" "go"
        elif [ -f "$service_dir/requirements.txt" ] || [ -f "$service_dir/main.py" ]; then
            create_dockerfile "$service_dir" "python"
        else
            echo "⚠️  No se pudo detectar el tipo de servicio para $service_dir"
            echo "   Archivos encontrados:"
            ls -la "$service_dir" | head -5 | sed 's/^/     /'
        fi
    fi
}

# Procesar cada servicio
for service in "${services[@]}"; do
    dir=${service%:*}
    detect_and_create_dockerfile "$dir"
done

echo ""
echo "📋 4. Actualizando docker-compose.yml para AWS..."
echo "==============================================="

if [ -f "docker-compose.yml" ]; then
    # Crear backup
    cp docker-compose.yml docker-compose.yml.backup
    
    # Remover version obsoleta
    if grep -q "^version:" docker-compose.yml; then
        echo "🔧 Removiendo 'version' obsoleta..."
        sed -i '/^version:/d' docker-compose.yml
    fi
    
    # Agregar configuración para AWS si no existe
    if ! grep -q "# AWS Configuration" docker-compose.yml; then
        echo "🔧 Agregando configuración para AWS..."
        cat >> docker-compose.yml << 'EOF'

# ============================================================================
# AWS CONFIGURATION
# ============================================================================
# Para usar en AWS, considerar:
# 1. Usar RDS para bases de datos en producción
# 2. Usar ELB para load balancing
# 3. Usar ECS o EKS para orchestration
# 4. Configurar health checks apropiados
EOF
    fi
fi

echo ""
echo "📋 5. Creando script de despliegue para AWS..."
echo "=============================================="

cat > "deploy-aws.sh" << 'EOF'
#!/bin/bash

echo "🚀 DESPLIEGUE EN AWS - Pacifico Health Insurance"
echo "==============================================="
echo ""

# Verificar que Docker y Docker Compose estén instalados
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Instalando..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado. Reinicia la sesión para aplicar permisos."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado. Instalando..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose instalado"
fi

# Verificar archivos necesarios
echo "📋 Verificando archivos necesarios..."
required_files=("docker-compose.yml")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Archivo requerido no encontrado: $file"
        exit 1
    fi
    echo "✅ $file encontrado"
done

# Verificar Dockerfiles
echo ""
echo "📋 Verificando Dockerfiles..."
services=("api-gateway" "ms-gestion-lead" "ms-gestion-persona" "ms-gestion-poliza" "ms-gestion-gestor" "ms-validar-recaptcha")
missing_dockerfiles=()

for service in "${services[@]}"; do
    if [ -d "$service" ]; then
        if [ -f "$service/Dockerfile" ]; then
            echo "✅ $service/Dockerfile encontrado"
        else
            echo "❌ $service/Dockerfile NO encontrado"
            missing_dockerfiles+=("$service")
        fi
    else
        echo "⚠️  Directorio $service no existe"
    fi
done

if [ ${#missing_dockerfiles[@]} -gt 0 ]; then
    echo ""
    echo "❌ Faltan Dockerfiles para: ${missing_dockerfiles[*]}"
    echo "Ejecuta './fix_dockerfiles_aws.sh' para crear los Dockerfiles faltantes"
    exit 1
fi

# Configurar variables de entorno para AWS
echo ""
echo "🔧 Configurando variables de entorno para AWS..."
if [ ! -f ".env" ]; then
    echo "⚠️  Archivo .env no encontrado. Creando uno básico..."
    cat > .env << 'ENVEOF'
# Configuración para AWS
MYSQL_ROOT_PASSWORD=your_secure_password_here
MYSQL_DATABASE=DB_Personas
MYSQL_USER=app_user
MYSQL_PASSWORD=your_app_password_here

POSTGRES_DB=personas_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_postgres_password_here

RECAPTCHA_SECRET_KEY=your_recaptcha_secret_key_here

# Configuración de puertos
API_GATEWAY_PORT=8000
MS_GESTOR_PORT=6000
MS_LEAD_PORT=3000
MS_PERSONA_PORT=8001
MS_POLIZA_PORT=8002
MS_RECAPTCHA_PORT=1323
ENVEOF
    echo "⚠️  IMPORTANTE: Edita el archivo .env con tus credenciales reales"
fi

# Limpiar contenedores previos
echo ""
echo "🧹 Limpiando despliegue previo..."
docker-compose down --remove-orphans

# Construir imágenes
echo ""
echo "🏗️  Construyendo imágenes..."
docker-compose build

# Iniciar servicios
echo ""
echo "🚀 Iniciando servicios..."
docker-compose up -d

# Esperar que los servicios estén listos
echo ""
echo "⏳ Esperando que los servicios estén listos..."
sleep 30

# Verificar estado
echo ""
echo "📊 Estado de los servicios:"
docker-compose ps

# Verificar health checks
echo ""
echo "🏥 Verificando health checks..."
services_to_check=("3000" "8001" "8002" "6000" "1323" "8000")
for port in "${services_to_check[@]}"; do
    echo -n "Puerto $port: "
    if curl -s --max-time 5 "http://localhost:$port/health" >/dev/null 2>&1; then
        echo "✅ Healthy"
    else
        echo "❌ No responde"
    fi
done

echo ""
echo "🎉 DESPLIEGUE COMPLETADO"
echo "======================="
echo ""
echo "🌐 URLs disponibles:"
echo "   API Gateway: http://$(curl -s http://checkip.amazonaws.com):8000"
echo "   Health Check: http://$(curl -s http://checkip.amazonaws.com):8000/health"
echo ""
echo "📋 Para monitorear:"
echo "   docker-compose logs -f"
echo "   docker-compose ps"
echo ""
echo "🛑 Para detener:"
echo "   docker-compose down"
EOF

chmod +x deploy-aws.sh

echo ""
echo "✅ CORRECCIÓN COMPLETADA"
echo "========================"
echo ""
echo "📁 Archivos creados/modificados:"
echo "  ✅ Dockerfiles faltantes creados"
echo "  ✅ docker-compose.yml actualizado (version removida)"
echo "  ✅ deploy-aws.sh creado"
echo "  ✅ Backup: docker-compose.yml.backup"
echo ""
echo "🚀 Para desplegar en AWS:"
echo "  1. ./deploy-aws.sh"
echo "  2. Editar .env con credenciales reales"
echo "  3. Configurar security groups en AWS (puertos 8000, 3000, 8001, 8002, 6000, 1323)"
echo ""
echo "🔧 Si necesitas más Dockerfiles específicos:"
echo "  Ejecuta este script nuevamente después de subir más archivos"
