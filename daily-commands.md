# Comandos Útiles para Gestión Diaria - Pacífico Health Insurance

## 🚀 Comandos de Inicio Rápido

```bash
# Setup inicial completo
chmod +x setup.sh && ./setup.sh

# Iniciar todo el sistema
make up
# o
docker-compose up -d

# Ver estado rápidamente
make status && make health
```

## 📊 Monitoreo y Logs

```bash
# Ver logs en tiempo real de todos los servicios
make logs

# Ver logs de servicios específicos
make logs-api-gateway
make logs-ms-validar-recaptcha
make logs-mysql
make logs-postgres

# Seguir logs con filtros
docker-compose logs -f --tail=100 api-gateway
docker-compose logs -f --since=30m ms-gestion-lead

# Ver uso de recursos
docker stats
docker system df
```

## 🔧 Gestión de Servicios

```bash
# Reiniciar un servicio específico
docker-compose restart api-gateway
docker-compose restart ms-validar-recaptcha

# Reconstruir y reiniciar un servicio
docker-compose up -d --build ms-validar-recaptcha

# Escalar un servicio (múltiples instancias)
docker-compose up -d --scale ms-gestion-lead=3

# Detener un servicio específico
docker-compose stop ms-validar-recaptcha

# Eliminar y recrear un servicio
docker-compose rm -s ms-validar-recaptcha
docker-compose up -d ms-validar-recaptcha
```

## 🔐 Gestión del Servicio reCAPTCHA

```bash
# Verificar estado del servicio reCAPTCHA
curl http://localhost:1323/recaptcha/health

# Ver logs específicos de reCAPTCHA
make logs-ms-validar-recaptcha

# Testear endpoint de validación (requiere token válido)
curl -X POST http://localhost:1323/recaptcha/validate-recaptcha \
  -H "Content-Type: application/json" \
  -d '{"recaptcha_token":"TOKEN_FROM_FRONTEND"}'

# Verificar variables de entorno de reCAPTCHA
docker-compose exec ms-validar-recaptcha env | grep RECAPTCHA

# Acceder al contenedor de reCAPTCHA
docker-compose exec ms-validar-recaptcha sh
```

## 💾 Gestión de Base de Datos

### MySQL

```bash
# Conectar a MySQL
docker-compose exec mysql mysql -u root -ppass_personas DB_Personas

# Backup manual
docker-compose exec mysql mysqldump -u root -ppass_personas DB_Personas > backup_$(date +%Y%m%d).sql

# Restaurar backup
docker-compose exec -T mysql mysql -u root -ppass_personas DB_Personas < backup_file.sql

# Ver tablas y datos
docker-compose exec mysql mysql -u root -ppass_personas -e "USE DB_Personas; SHOW TABLES;"
docker-compose exec mysql mysql -u root -ppass_personas -e "USE DB_Personas; SELECT * FROM persona LIMIT 5;"
```

### PostgreSQL

```bash
# Conectar a PostgreSQL
docker-compose exec postgres psql -U postgres personas_db

# Backup manual
docker-compose exec postgres pg_dump -U postgres personas_db > backup_$(date +%Y%m%d).sql

# Restaurar backup
docker-compose exec -T postgres psql -U postgres personas_db < backup_file.sql

# Ver tablas y datos
docker-compose exec postgres psql -U postgres -d personas_db -c "\dt"
docker-compose exec postgres psql -U postgres -d personas_db -c "SELECT * FROM leads LIMIT 5;"
```

### Redis

```bash
# Conectar a Redis
docker-compose exec redis redis-cli

# Ver información de Redis
docker-compose exec redis redis-cli info memory
docker-compose exec redis redis-cli info stats

# Limpiar cache
docker-compose exec redis redis-cli flushall
```

## 🐛 Debugging y Troubleshooting

```bash
# Inspeccionar un contenedor
docker-compose exec api-gateway sh
docker-compose exec ms-validar-recaptcha sh
docker-compose exec mysql bash

# Ver configuración de docker-compose
docker-compose config

# Ver eventos de Docker
docker events --filter container=ms_validar_recaptcha

# Inspeccionar redes
docker network ls
docker network inspect mcp-folder_pacifico_network

# Ver volúmenes
docker volume ls
docker volume inspect mcp-folder_mysql_data

# Verificar puertos abiertos
netstat -tulpn | grep :8080
netstat -tulpn | grep :1323
lsof -i :3306
```

## 🧹 Mantenimiento y Limpieza

```bash
# Limpieza básica
make clean

# Limpieza completa (¡CUIDADO! Elimina datos)
make clean-all

# Limpiar imágenes no utilizadas
docker image prune -f

# Limpiar contenedores detenidos
docker container prune -f

# Ver espacio ocupado
docker system df
du -sh /var/lib/docker/

# Limpieza profunda del sistema Docker
docker system prune -af --volumes
```

## 📈 Performance y Optimización

```bash
# Ver uso de CPU y memoria por contenedor
docker stats --no-stream

# Ver logs de rendimiento
docker-compose logs | grep -E "(slow|timeout|error|exception)"

# Monitorear conexiones de base de datos
docker-compose exec mysql mysql -u root -ppass_personas -e "SHOW PROCESSLIST;"
docker-compose exec postgres psql -U postgres -d personas_db -c "SELECT * FROM pg_stat_activity;"

# Ver métricas de Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Monitorear específicamente el servicio reCAPTCHA
curl http://localhost:9090/api/v1/query?query=up{job="ms-validar-recaptcha"}
```

## 🔐 Seguridad y Configuración

```bash
# Verificar configuración de reCAPTCHA
grep RECAPTCHA_SECRET_KEY .env

# Rotar clave de reCAPTCHA
# 1. Obtener nueva clave en https://www.google.com/recaptcha/admin
# 2. Actualizar .env
# 3. Reiniciar servicio
docker-compose restart ms-validar-recaptcha

# Backup completo automático
make db-backup

# Verificar integridad de volúmenes
docker run --rm -v mcp-folder_mysql_data:/data alpine ls -la /data

# Exportar volúmenes
docker run --rm -v mcp-folder_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_volume_backup.tar.gz -C /data .
```

## 🚀 Deployment y Updates

```bash
# Update completo del sistema
git pull
make build
make up

# Rolling update de un servicio
docker-compose pull ms-validar-recaptcha
docker-compose up -d --no-deps ms-validar-recaptcha

# Verificar que todo funciona después del update
make health
curl -f http://localhost:8080/health
curl -f http://localhost:1323/recaptcha/health
```

## 📱 Comandos Móviles (One-liners)

```bash
# Status completo en una línea
docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}"

# Restart rápido de todos los microservicios
docker-compose restart api-gateway ms-gestion-gestor ms-gestion-lead ms-gestion-persona ms-gestion-poliza ms-validar-recaptcha

# Verificación rápida de salud de todos los servicios
curl -s http://localhost:8080/health && echo " ✓ Gateway OK" || echo " ✗ Gateway FAIL"
curl -s http://localhost:1323/recaptcha/health && echo " ✓ reCAPTCHA OK" || echo " ✗ reCAPTCHA FAIL"

# Logs de errores recientes
docker-compose logs --since=1h | grep -i error

# Memoria total usada por el stack
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | awk 'NR>1 {split($2,a,"/"); sum+=a[1]} END {print "Total Memory: " sum/1024/1024 " MB"}'

# Verificar todos los puertos en uso
netstat -tulpn | grep -E ":8080|:1323|:3000|:7000|:8001|:8002|:4321|:3306|:5432|:6379"
```

## 🔍 URLs Importantes de Referencia Rápida

```bash
# Servicios principales
echo "Frontend: http://localhost:4321"
echo "API Gateway: http://localhost:8080"
echo "reCAPTCHA Service: http://localhost:1323/recaptcha/health"

echo "Swagger APIs:"
echo "  - MS Gestor: http://localhost:7000/docs"  
echo "  - MS Lead: http://localhost:3000/api"
echo "  - MS Persona: http://localhost:8001/swagger"
echo "  - MS Poliza: http://localhost:8002/docs"

# Herramientas de admin
echo "phpMyAdmin: http://localhost:8090"
echo "pgAdmin: http://localhost:8081 (admin@pacifico.com/admin123)"
echo "Grafana: http://localhost:3001 (admin/admin123)"
echo "Prometheus: http://localhost:9090"
```

## 📋 Checklist de Troubleshooting

Cuando algo no funciona, sigue este checklist:

1. **Verificar estado de contenedores**: `make status`
2. **Verificar salud de servicios**: `make health`
3. **Revisar logs**: `make logs-[service-name]`
4. **Verificar configuración reCAPTCHA**: `grep RECAPTCHA_SECRET_KEY .env`
5. **Verificar conectividad de red**: `docker network inspect mcp-folder_pacifico_network`
6. **Verificar puertos**: `netstat -tulpn | grep [puerto]`
7. **Reiniciar servicio específico**: `docker-compose restart [service-name]`
8. **Reconstruir si es necesario**: `docker-compose up -d --build [service-name]`
9. **Verificar recursos**: `docker stats`
10. **Revisar logs del sistema**: `journalctl -u docker`
11. **Como último recurso**: `make clean && make build && make up`

## 🔐 Configuración Específica de reCAPTCHA

### Obtener Claves de reCAPTCHA

1. Ve a https://www.google.com/recaptcha/admin
2. Registra un nuevo sitio
3. Selecciona reCAPTCHA v2 o v3
4. Añade tus dominios (localhost para desarrollo)
5. Copia la **Secret Key** al archivo `.env`

### Configurar Frontend para reCAPTCHA

```javascript
// Ejemplo para el frontend
const validateRecaptcha = async (token) => {
  try {
    const response = await fetch('http://localhost:1323/recaptcha/validate-recaptcha', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        recaptcha_token: token
      })
    });
    
    const result = await response.json();
    return result.success;
  } catch (error) {
    console.error('Error validating reCAPTCHA:', error);
    return false;
  }
};
```

### Testing reCAPTCHA en Desarrollo

```bash
# Para testing, Google proporciona tokens de prueba:
# Siempre pasa: "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI"
# Siempre falla: "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe"

curl -X POST http://localhost:1323/recaptcha/validate-recaptcha \
  -H "Content-Type: application/json" \
  -d '{"recaptcha_token":"6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI"}'
```
