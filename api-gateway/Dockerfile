# Build stage
FROM golang:1.21-alpine AS builder

# Instalar dependencias del sistema
RUN apk add --no-cache git ca-certificates tzdata

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos go.mod y go.sum
COPY go.mod go.sum ./

# Descargar dependencias
RUN go mod download

# Copiar código fuente
COPY . .

# Construir la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api-gateway .

# Production stage
FROM alpine:latest

# Instalar ca-certificates para HTTPS requests
RUN apk --no-cache add ca-certificates

# Crear usuario no-root
RUN addgroup -g 1001 app && \
    adduser -D -s /bin/sh -u 1001 -G app app

# Crear directorio de trabajo
WORKDIR /app

# Copiar binario desde builder stage
COPY --from=builder /app/api-gateway .

# Copiar archivos de configuración
COPY --from=builder /app/config/config.json ./config/

# Cambiar ownership
RUN chown -R app:app /app

# Cambiar a usuario no-root
USER app

# Exponer puerto
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# Comando por defecto
CMD ["./api-gateway"]