#!/bin/bash

# setup.sh - Script de inicialización del Sistema Pacífico Health Insurance

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ____            _  __ _              _   _            _ _   ║
║  |  _ \ __ _  ___(_)/ _(_) ___ ___   | | | | ___  __ _| | |_ ║
║  | |_) / _` |/ __| | |_| |/ __/ _ \  | |_| |/ _ \/ _` | | __║ ║
║  |  __/ (_| | (__| |  _| | (_| (_) | |  _  |  __/ (_| | | |_ ║
║  |_|   \__,_|\___|_|_| |_|\___\___/  |_| |_|\___|\__,_|_|\__║ ║
║                                                               ║
║               Health Insurance Platform                       ║
║                    Setup Script                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar prerrequisitos
log "Verificando prerrequisitos..."

# Verificar Docker
if ! command -v docker &> /dev/null; then
    error "Docker no está instalado. Por favor instala Docker antes de continuar."
    exit 1
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose no está instalado. Por favor instala Docker Compose antes de continuar."
    exit 1
fi

# Verificar que Docker esté ejecutándose
if ! docker info &> /dev/null; then
    error "Docker no está ejecutándose. Por favor inicia Docker antes de continuar."
    exit 1
fi

success "Prerrequisitos verificados correctamente"

# Crear directorios necesarios
log "Creando estructura de directorios..."

directories=(
    "backups"
    "logs"
    "secrets"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log "Creado directorio: $dir"
    fi
done

success "Estructura de directorios creada"

# Crear archivo .env.example si no existe
if [ ! -f ".env.example" ]; then
    log "Creando archivo .env.example..."
    cat > .env.example << 'EOF'
# Configuración de Bases de Datos
MYSQL_ROOT_PASSWORD=pass_personas
MYSQL_DATABASE=DB_Personas
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password

POSTGRES_DB=personas_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123

# Configuración de Redis
REDIS_PASSWORD=

# Configuración de reCAPTCHA (OBLIGATORIO)
# Obtén tu clave en: https://www.google.com/recaptcha/admin
RECAPTCHA_SECRET_KEY=tu_clave_secreta_aqui

# Configuración de servicios
API_GATEWAY_PORT=8080
MS_GESTOR_PORT=7000
MS_LEAD_PORT=3000
MS_PERSONA_PORT=8001
MS_POLIZA_PORT=8002
MS_RECAPTCHA_PORT=1323
FRONTEND_PORT=4321

# Configuración de herramientas de administración
PHPMYADMIN_PORT=8090
PGADMIN_PORT=8081
GRAFANA_PORT=3001
PROMETHEUS_PORT=9090

# Configuración de pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@pacifico.com
PGADMIN_DEFAULT_PASSWORD=admin123

# Configuración de Grafana
GF_SECURITY_ADMIN_PASSWORD=admin123

# URLs de servicios (para desarrollo)
API_GATEWAY_URL=http://localhost:8080
MYSQL_HOST=localhost
POSTGRES_HOST=localhost
REDIS_HOST=localhost
EOF
    success "Archivo .env.example creado"
fi

# Crear archivo .env si no existe
if [ ! -f ".env" ]; then
    log "Creando archivo .env desde .env.example..."
    cp .env.example .env
    warning "¡IMPORTANTE! Debes configurar RECAPTCHA_SECRET_KEY en el archivo .env"
    warning "Obtén tu clave en: https://www.google.com/recaptcha/admin"
fi

# Crear archivo .gitignore si no existe
if [ ! -f ".gitignore" ]; then
    log "Creando archivo .gitignore..."
    cat > .gitignore << 'EOF'
# Environment variables
.env
.env.local
.env.production

# Docker
.docker/

# Logs
logs/
*.log

# Backups
backups/*.sql
backups/*.dump

# Secrets
secrets/
*.key
*.pem

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
.pytest_cache/

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out

# Build artifacts
dist/
build/
target/

# Database
*.db
*.sqlite
*.sqlite3

# Temporary files
*.tmp
*.temp
.cache/
EOF
    success "Archivo .gitignore creado"
fi

# Verificar configuración de reCAPTCHA
if [ -f ".env" ]; then
    if grep -q "RECAPTCHA_SECRET_KEY=tu_clave_secreta_aqui" .env; then
        warning "⚠️  RECAPTCHA_SECRET_KEY no está configurado en .env"
        warning "   El servicio ms-validar-recaptcha no funcionará correctamente"
        warning "   Configúralo en: https://www.google.com/recaptcha/admin"
    fi
fi

# Mostrar servicios que se van a levantar
echo ""
log "Servicios que se incluirán en el stack:"
echo "  ✅ API Gateway (Go/Echo) - Puerto 8080"
echo "  ✅ MS Gestión Gestor (Python/FastAPI) - Puerto 7000"
echo "  ✅ MS Gestión Lead (Node.js/NestJS) - Puerto 3000"
echo "  ✅ MS Gestión Persona (Go/Echo) - Puerto 8001"
echo "  ✅ MS Gestión Poliza (Python/FastAPI) - Puerto 8002"
echo "  ✅ MS Validar Recaptcha (Go/Echo) - Puerto 1323"
echo "  ✅ Frontend (Astro) - Puerto 4321"
echo "  ✅ MySQL + PostgreSQL + Redis"
echo "  ✅ phpMyAdmin + pgAdmin + Grafana + Prometheus"

# Preguntar si desea construir las imágenes
echo ""
read -p "¿Deseas construir las imágenes Docker ahora? (y/N): " build_images

if [[ $build_images =~ ^[Yy]$ ]]; then
    log "Construyendo imágenes Docker..."
    if command -v make &> /dev/null; then
        make build
    else
        docker-compose build --parallel
    fi
    success "Imágenes construidas correctamente"
fi

# Preguntar si desea iniciar los servicios
echo ""
read -p "¿Deseas iniciar todos los servicios ahora? (y/N): " start_services

if [[ $start_services =~ ^[Yy]$ ]]; then
    log "Iniciando servicios..."
    if command -v make &> /dev/null; then
        make up
    else
        docker-compose up -d
    fi
    
    # Esperar un momento para que los servicios se inicien
    log "Esperando que los servicios se inicien..."
    sleep 30
    
    # Verificar estado
    if command -v make &> /dev/null; then
        make status
        echo ""
        make health
    else
        docker-compose ps
    fi
    
    success "Servicios iniciados correctamente"
else
    log "Servicios no iniciados. Puedes iniciarlos más tarde con:"
    if command -v make &> /dev/null; then
        echo "  make up"
    else
        echo "  docker-compose up -d"
    fi
fi

# Mostrar información final
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Setup completado exitosamente!     ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}URLs de los servicios:${NC}"
echo "  Frontend:             http://localhost:4321"
echo "  API Gateway:          http://localhost:8080"
echo "  MS Gestión Gestor:    http://localhost:7000"
echo "  MS Gestión Lead:      http://localhost:3000"
echo "  MS Gestión Persona:   http://localhost:8001"
echo "  MS Gestión Poliza:    http://localhost:8002"
echo "  MS Validar Recaptcha: http://localhost:1323"
echo ""
echo -e "${YELLOW}Herramientas de administración:${NC}"
echo "  phpMyAdmin:           http://localhost:8090"
echo "  pgAdmin:              http://localhost:8081"
echo "  Grafana:              http://localhost:3001"
echo "  Prometheus:           http://localhost:9090"
echo ""
echo -e "${YELLOW}Endpoints de APIs:${NC}"
echo "  Gestor:               http://localhost:7000/docs"
echo "  Lead:                 http://localhost:3000/api"
echo "  Persona:              http://localhost:8001/swagger"
echo "  Poliza:               http://localhost:8002/docs"
echo "  Recaptcha Health:     http://localhost:1323/recaptcha/health"
echo "  Recaptcha Validate:   http://localhost:1323/recaptcha/validate-recaptcha"
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
if command -v make &> /dev/null; then
    echo "  make help          # Ver todos los comandos disponibles"
    echo "  make status        # Ver estado de servicios"
    echo "  make health        # Verificar salud de servicios"
    echo "  make logs          # Ver logs de todos los servicios"
    echo "  make down          # Detener todos los servicios"
    echo "  make clean         # Limpiar recursos no utilizados"
else
    echo "  docker-compose ps              # Ver estado de servicios"
    echo "  docker-compose logs -f         # Ver logs de servicios"
    echo "  docker-compose down            # Detener servicios"
    echo "  docker-compose up -d           # Iniciar servicios"
fi
echo ""

# Mostrar advertencias importantes
if grep -q "RECAPTCHA_SECRET_KEY=tu_clave_secreta_aqui" .env 2>/dev/null; then
    echo -e "${RED}⚠️  IMPORTANTE: Configura RECAPTCHA_SECRET_KEY en .env${NC}"
    echo -e "${RED}   Sin esto, el servicio de validación reCAPTCHA no funcionará${NC}"
    echo ""
fi

echo -e "${BLUE}¡Listo para usar! 🚀${NC}"
echo ""

# Crear archivo de verificación del setup
touch .setup_complete
echo "Setup completed on $(date)" > .setup_complete
echo "Services: api-gateway, ms-gestion-gestor, ms-gestion-lead, ms-gestion-persona, ms-gestion-poliza, ms-validar-recaptcha, frontend" >> .setup_complete
