.PHONY: help build up down restart logs clean status health

# Colores para el output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

help: ## Mostrar esta ayuda
	@echo "${BLUE}=== Sistema Pacífico Health Insurance ===${NC}"
	@echo "${YELLOW}Comandos disponibles:${NC}"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-15s${NC} %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Construir todas las imágenes
	@echo "${BLUE}Construyendo todas las imágenes...${NC}"
	docker-compose build --parallel

up: ## Levantar todos los servicios
	@echo "${BLUE}Levantando todos los servicios...${NC}"
	docker-compose up -d
	@echo "${GREEN}Servicios iniciados. Ejecuta 'make status' para ver el estado.${NC}"

down: ## Detener todos los servicios
	@echo "${YELLOW}Deteniendo todos los servicios...${NC}"
	docker-compose down

restart: ## Reiniciar todos los servicios
	@echo "${YELLOW}Reiniciando todos los servicios...${NC}"
	docker-compose restart

logs: ## Ver logs de todos los servicios
	docker-compose logs -f

logs-%: ## Ver logs de un servicio específico (ej: make logs-api-gateway)
	docker-compose logs -f $*

status: ## Ver el estado de todos los servicios
	@echo "${BLUE}Estado de los servicios:${NC}"
	@docker-compose ps

health: ## Verificar el estado de salud de los servicios
	@echo "${BLUE}Verificando salud de los servicios...${NC}"
	@echo "${YELLOW}Bases de Datos:${NC}"
	@docker-compose exec mysql mysqladmin ping -h localhost --silent && echo "${GREEN}✓ MySQL: OK${NC}" || echo "${RED}✗ MySQL: ERROR${NC}"
	@docker-compose exec postgres pg_isready -U postgres --quiet && echo "${GREEN}✓ PostgreSQL: OK${NC}" || echo "${RED}✗ PostgreSQL: ERROR${NC}"
	@docker-compose exec redis redis-cli ping > /dev/null && echo "${GREEN}✓ Redis: OK${NC}" || echo "${RED}✗ Redis: ERROR${NC}"
	@echo "${YELLOW}APIs:${NC}"
	@curl -sf http://localhost:8080/health > /dev/null && echo "${GREEN}✓ API Gateway: OK${NC}" || echo "${RED}✗ API Gateway: ERROR${NC}"
	@curl -sf http://localhost:7000/ > /dev/null && echo "${GREEN}✓ MS Gestión Gestor: OK${NC}" || echo "${RED}✗ MS Gestión Gestor: ERROR${NC}"
	@curl -sf http://localhost:3000/ > /dev/null && echo "${GREEN}✓ MS Gestión Lead: OK${NC}" || echo "${RED}✗ MS Gestión Lead: ERROR${NC}"
	@curl -sf http://localhost:8001/health > /dev/null && echo "${GREEN}✓ MS Gestión Persona: OK${NC}" || echo "${RED}✗ MS Gestión Persona: ERROR${NC}"
	@curl -sf http://localhost:8002/ > /dev/null && echo "${GREEN}✓ MS Gestión Poliza: OK${NC}" || echo "${RED}✗ MS Gestión Poliza: ERROR${NC}"
	@curl -sf http://localhost:1323/recaptcha/health > /dev/null && echo "${GREEN}✓ MS Validar Recaptcha: OK${NC}" || echo "${RED}✗ MS Validar Recaptcha: ERROR${NC}"
	@curl -sf http://localhost:4321/ > /dev/null && echo "${GREEN}✓ Frontend: OK${NC}" || echo "${RED}✗ Frontend: ERROR${NC}"

clean: ## Limpiar contenedores, imágenes y volúmenes no utilizados
	@echo "${YELLOW}Limpiando sistema Docker...${NC}"
	docker-compose down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

clean-all: ## Limpiar TODO (incluyendo volúmenes de datos)
	@echo "${RED}¡ADVERTENCIA! Esto eliminará TODOS los datos.${NC}"
	@read -p "¿Estás seguro? (y/N): " confirm && [ "$$confirm" = "y" ]
	docker-compose down -v --remove-orphans
	docker system prune -af
	docker volume prune -af

# Comandos específicos para desarrollo
dev-build: ## Construir solo los servicios de desarrollo
	docker-compose build api-gateway ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

dev-up: ## Levantar solo servicios esenciales para desarrollo
	docker-compose up -d mysql postgres redis
	@echo "${GREEN}Servicios de desarrollo iniciados.${NC}"

# Comandos para bases de datos
db-backup: ## Hacer backup de las bases de datos
	@echo "${BLUE}Creando backups de las bases de datos...${NC}"
	@mkdir -p backups
	docker-compose exec mysql mysqldump -u root -ppass_personas DB_Personas > backups/mysql_backup_$(shell date +%Y%m%d_%H%M%S).sql
	docker-compose exec postgres pg_dump -U postgres personas_db > backups/postgres_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "${GREEN}Backups creados en la carpeta backups/${NC}"

db-restore-mysql: ## Restaurar backup de MySQL (especificar BACKUP_FILE=archivo.sql)
	@test -n "$(BACKUP_FILE)" || (echo "${RED}Error: Especifica BACKUP_FILE=archivo.sql${NC}" && exit 1)
	docker-compose exec -T mysql mysql -u root -ppass_personas DB_Personas < $(BACKUP_FILE)
	@echo "${GREEN}Backup de MySQL restaurado.${NC}"

db-restore-postgres: ## Restaurar backup de PostgreSQL (especificar BACKUP_FILE=archivo.sql)
	@test -n "$(BACKUP_FILE)" || (echo "${RED}Error: Especifica BACKUP_FILE=archivo.sql${NC}" && exit 1)
	docker-compose exec -T postgres psql -U postgres personas_db < $(BACKUP_FILE)
	@echo "${GREEN}Backup de PostgreSQL restaurado.${NC}"

# Comandos de monitoreo
monitor: ## Abrir interfaces de monitoreo
	@echo "${BLUE}Abriendo interfaces de monitoreo...${NC}"
	@echo "${YELLOW}Grafana:${NC} http://localhost:3001 (admin/admin123)"
	@echo "${YELLOW}Prometheus:${NC} http://localhost:9090"
	@echo "${YELLOW}phpMyAdmin:${NC} http://localhost:8090"
	@echo "${YELLOW}pgAdmin:${NC} http://localhost:8081 (admin@pacifico.com/admin123)"

# Información del sistema
info: ## Mostrar información del sistema
	@echo "${BLUE}=== Información del Sistema Pacífico Health Insurance ===${NC}"
	@echo "${YELLOW}Servicios principales:${NC}"
	@echo "  Frontend:             http://localhost:4321"
	@echo "  API Gateway:          http://localhost:8080"
	@echo "  MS Gestión Gestor:    http://localhost:7000"
	@echo "  MS Gestión Lead:      http://localhost:3000"
	@echo "  MS Gestión Persona:   http://localhost:8001"
	@echo "  MS Gestión Poliza:    http://localhost:8002"
	@echo "  MS Validar Recaptcha: http://localhost:1323"
	@echo ""
	@echo "${YELLOW}Bases de datos:${NC}"
	@echo "  MySQL:      localhost:3306 (user: root, pass: pass_personas)"
	@echo "  PostgreSQL: localhost:5432 (user: postgres, pass: postgres123)"
	@echo "  Redis:      localhost:6379"
	@echo ""
	@echo "${YELLOW}Herramientas de administración:${NC}"
	@echo "  phpMyAdmin: http://localhost:8090"
	@echo "  pgAdmin:    http://localhost:8081 (admin@pacifico.com/admin123)"
	@echo ""
	@echo "${YELLOW}Monitoreo:${NC}"
	@echo "  Grafana:    http://localhost:3001 (admin/admin123)"
	@echo "  Prometheus: http://localhost:9090"
	@echo ""
	@echo "${YELLOW}Endpoints de API:${NC}"
	@echo "  Gestor:     http://localhost:7000/docs"
	@echo "  Lead:       http://localhost:3000/api"  
	@echo "  Persona:    http://localhost:8001/swagger"
	@echo "  Poliza:     http://localhost:8002/docs"
	@echo "  Recaptcha:  http://localhost:1323/recaptcha/health"
