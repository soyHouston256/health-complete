-- Inicialización de base de datos MySQL para Pacífico Health Insurance

USE DB_Personas;

-- Tabla de personas
CREATE TABLE IF NOT EXISTS persona (
    codigo_persona INT AUTO_INCREMENT PRIMARY KEY,
    tipo_persona VARCHAR(50) NOT NULL,
    indicador_lista_negra BOOLEAN DEFAULT FALSE,
    nacionalidad VARCHAR(100),
    pais_procedencia VARCHAR(100),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Tabla de pólizas
CREATE TABLE IF NOT EXISTS polizas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigoPersona INT NOT NULL,
    codigoPoliza INT NOT NULL,
    numeroPoliza VARCHAR(100) UNIQUE NOT NULL,
    nombreProducto VARCHAR(200),
    descProducto TEXT,
    catProducto VARCHAR(100),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (codigoPersona) REFERENCES persona(codigo_persona)
);

-- Índices para mejorar rendimiento
CREATE INDEX idx_persona_tipo ON persona(tipo_persona);
CREATE INDEX idx_persona_nacionalidad ON persona(nacionalidad);
CREATE INDEX idx_poliza_persona ON polizas(codigoPersona);
CREATE INDEX idx_poliza_numero ON polizas(numeroPoliza);

-- Datos de ejemplo
INSERT IGNORE INTO persona (codigo_persona, tipo_persona, indicador_lista_negra, nacionalidad, pais_procedencia) VALUES
(1, 'Natural', FALSE, 'Peruana', 'Perú'),
(2, 'Jurídica', FALSE, 'Peruana', 'Perú'),
(3, 'Natural', FALSE, 'Ecuatoriana', 'Ecuador');

INSERT IGNORE INTO polizas (codigoPersona, codigoPoliza, numeroPoliza, nombreProducto, descProducto, catProducto) VALUES
(1, 1001, 'POL-2024-001', 'Seguro de Vida', 'Póliza de seguro de vida básico', 'Vida'),
(1, 1002, 'POL-2024-002', 'Seguro de Salud', 'Póliza de seguro de salud familiar', 'Salud'),
(2, 1003, 'POL-2024-003', 'Seguro Empresarial', 'Póliza de seguro para empresas', 'Empresarial');
