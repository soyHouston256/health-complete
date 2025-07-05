# Sistema Pacífico Health Insurance - Docker Compose

Este proyecto contiene la configuración completa para ejecutar todo el ecosistema de microservicios de Pacífico Health Insurance usando Docker Compose.

## 🏗️ Arquitectura del Sistema

### Componentes Principales

- **Frontend**: Astro application (Puerto 4321)
- **API Gateway**: Go/Echo service (Puerto 8080)
- **Microservicios**:
  - MS Gestión Gestor: Python/FastAPI (Puerto 7000)
  - MS Gestión Lead: Node.js/NestJS (Puerto 3000)
  - MS Gestión Persona: Go/Echo (Puerto 8001)
  - MS Gestión Poliza: Python/FastAPI (Puerto 8002)
  - MS Validar Recaptcha: Go/Echo (Puerto 1323)

### Bases de Datos

- **MySQL 8.0**: Para datos de personas y pólizas (Puerto 3306)
- **PostgreSQL 15**: Para datos del sistema (Puerto 5432)
- **Redis 7**: Cache y sesiones (Puerto 6379)

### Herramientas de Administración

- **phpMyAdmin**: Gestión de MySQL (Puerto 8090)
- **pgAdmin4**: Gestión de PostgreSQL (Puerto 8081)

### Monitoreo

- **Prometheus**: Métricas del sistema (Puerto 9090)
- **Grafana**: Dashboards y visualización (Puerto 3001)

## 🚀 Inicio Rápido

### Prerrequisitos

- Docker >= 20.0
- Docker Compose >= 2.0
- Make (opcional, para usar el Makefile)

### Instalación y Ejecución

1. **Configurar variables de entorno**:
```bash
cp .env.example .env
# Editar .env y agregar tu RECAPTCHA_SECRET_KEY
```

2. **Ejecutar el script de setup**:
```bash
chmod +x setup.sh
./setup.sh
```

3. **O manualmente**:
```bash
make build          # Construir imágenes
make up             # Levantar servicios
make health         # Verificar estado
```

## 📋 Comandos Útiles

### Usando Makefile

```bash
make help           # Ver todos los comandos disponibles
make build          # Construir todas las imágenes
make up             # Levantar todos los servicios
make down           # Detener todos los servicios
make restart        # Reiniciar todos los servicios
make logs           # Ver logs de todos los servicios
make logs-[service] # Ver logs de un servicio específico
make status         # Ver estado de servicios
make health         # Verificar salud de servicios
make clean          # Limpiar recursos no utilizados
make info           # Mostrar información del sistema
```

## 🔧 Configuración

### Variables de Entorno Importantes

- **RECAPTCHA_SECRET_KEY**: Clave secreta de Google reCAPTCHA (obligatoria)
- **MySQL**: root/pass_personas, BD: DB_Personas
- **PostgreSQL**: postgres/postgres123, BD: personas_db

### Configurar reCAPTCHA

1. Obtener claves en: https://www.google.com/recaptcha/admin
2. Agregar `RECAPTCHA_SECRET_KEY` en archivo `.env`
3. Configurar el dominio permitido en Google reCAPTCHA

## 🗄️ Gestión de Datos

### Backups

```bash
make db-backup                          # Backup de ambas bases de datos
make db-restore-mysql BACKUP_FILE=file.sql    # Restaurar MySQL
make db-restore-postgres BACKUP_FILE=file.sql # Restaurar PostgreSQL
```

## 🔍 Monitoreo y Administración

### Interfaces Web

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Frontend | http://localhost:4321 | - |
| API Gateway | http://localhost:8080 | - |
| phpMyAdmin | http://localhost:8090 | root/pass_personas |
| pgAdmin | http://localhost:8081 | admin@pacifico.com/admin123 |
| Grafana | http://localhost:3001 | admin/admin123 |
| Prometheus | http://localhost:9090 | - |

### APIs Disponibles

| Servicio | URL | Documentación |
|----------|-----|---------------|
| MS Gestión Gestor | http://localhost:7000 | http://localhost:7000/docs |
| MS Gestión Lead | http://localhost:3000 | http://localhost:3000/api |
| MS Gestión Persona | http://localhost:8001 | http://localhost:8001/swagger |
| MS Gestión Poliza | http://localhost:8002 | http://localhost:8002/docs |
| MS Validar Recaptcha | http://localhost:1323 | http://localhost:1323/recaptcha/health |

### Endpoints de reCAPTCHA

- **Health Check**: `GET http://localhost:1323/recaptcha/health`
- **Validar reCAPTCHA**: `POST http://localhost:1323/recaptcha/validate-recaptcha`

## 🛠️ Desarrollo

### Modo Desarrollo

```bash
make dev-up  # Solo bases de datos para desarrollo local
```

### Logs y Debugging

```bash
make logs                    # Ver logs de todos los servicios
make logs-api-gateway        # Ver logs específicos
make logs-ms-validar-recaptcha  # Ver logs del servicio reCAPTCHA
docker-compose exec mysql bash  # Acceder a contenedores
```

## 🚨 Solución de Problemas

### Problemas Comunes

1. **Puerto ocupado**: Cambiar puertos en docker-compose.yml
2. **Contenedor no inicia**: `make logs-[service]`
3. **BD no conecta**: `make health`
4. **reCAPTCHA falla**: Verificar RECAPTCHA_SECRET_KEY en .env
5. **Memoria insuficiente**: `make clean`

### Verificar Servicios

```bash
make health                    # Estado de todos los servicios
curl http://localhost:1323/recaptcha/health  # Test reCAPTCHA específico
```

## 📞 Soporte

- Ejecuta `make help` para ver todos los comandos
- Revisa logs con `make logs`
- Verifica estado con `make health`
- Para reCAPTCHA: https://developers.google.com/recaptcha

---

**¡Ejecuta `./setup.sh` para empezar! 🎉**

### Servicios Incluidos:
- ✅ **6 Microservicios** (Gateway, Gestor, Lead, Persona, Poliza, Recaptcha)
- ✅ **3 Bases de Datos** (MySQL, PostgreSQL, Redis)
- ✅ **Frontend** (Astro)
- ✅ **Herramientas de Admin** (phpMyAdmin, pgAdmin)
- ✅ **Monitoreo Completo** (Prometheus, Grafana)
