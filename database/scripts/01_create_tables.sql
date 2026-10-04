-- =============================================================================
-- SCRIPT DDL: BASE DE DATOS PLATAFORMA WEB ARANZÁBAL
-- Basado en la Sección 1 (Fundamento Teórico) - Sesión N° 11
-- SGBD: MySQL 8.0+ | Engine: InnoDB | Encoding: utf8mb4
-- =============================================================================

DROP DATABASE IF EXISTS aranzabal_db;
CREATE DATABASE aranzabal_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE aranzabal_db;

-- =============================================================================
-- FASE 1: TABLAS INDEPENDIENTES (PADRES - Sin Claves Foráneas)
-- Creación prioritaria para garantizar integridad al ser referenciadas.
-- =============================================================================

-- 1. Tabla: Categoria
CREATE TABLE categoria (
    categoria_id INT AUTO_INCREMENT,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(255) NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT pk_categoria PRIMARY KEY (categoria_id),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre),
    CONSTRAINT chk_categoria_estado CHECK (estado IN ('Activo', 'Inactivo'))
) ENGINE=InnoDB;

-- 2. Tabla: Unidad_Medida
CREATE TABLE unidad_medida (
    unidad_id INT AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    abreviatura VARCHAR(10) NOT NULL,
    CONSTRAINT pk_unidad_medida PRIMARY KEY (unidad_id),
    CONSTRAINT uq_unidad_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- 3. Tabla: Cliente
CREATE TABLE cliente (
    cliente_id INT AUTO_INCREMENT,
    documento VARCHAR(20) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    telefono VARCHAR(20) NULL,
    direccion TEXT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT pk_cliente PRIMARY KEY (cliente_id),
    CONSTRAINT uq_cliente_documento UNIQUE (documento),
    CONSTRAINT uq_cliente_correo UNIQUE (correo),
    CONSTRAINT chk_cliente_estado CHECK (estado IN ('Activo', 'Inactivo', 'Bloqueado'))
) ENGINE=InnoDB;

-- 4. Tabla: Usuario_Administrador
CREATE TABLE usuario_administrador (
    usuario_admin_id INT AUTO_INCREMENT,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(30) NOT NULL DEFAULT 'Administrador',
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT pk_usuario_admin PRIMARY KEY (usuario_admin_id),
    CONSTRAINT uq_usuario_admin_correo UNIQUE (correo),
    CONSTRAINT chk_usuario_admin_estado CHECK (estado IN ('Activo', 'Inactivo'))
) ENGINE=InnoDB;


-- =============================================================================
-- FASE 2: TABLAS DEPENDIENTES (HIJAS - Con Claves Foráneas)
-- Vinculación mediante FKs con reglas ON DELETE / ON UPDATE explícitas.
-- =============================================================================

-- 5. Tabla: Producto (Depende de categoria y unidad_medida)
CREATE TABLE producto (
    producto_id INT AUTO_INCREMENT,
    categoria_id INT NOT NULL,
    unidad_id INT NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NULL,
    imagen_url VARCHAR(255) NULL,
    precio_actual DECIMAL(10,2) NOT NULL,
    es_personalizable BOOLEAN NOT NULL DEFAULT FALSE,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_producto PRIMARY KEY (producto_id),
    CONSTRAINT uq_producto_codigo UNIQUE (codigo),
    CONSTRAINT chk_producto_precio CHECK (precio_actual >= 0),
    CONSTRAINT chk_producto_estado CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) 
        REFERENCES categoria(categoria_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_producto_unidad FOREIGN KEY (unidad_id) 
        REFERENCES unidad_medida(unidad_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 6. Tabla: Inventario (Depende de producto)
CREATE TABLE inventario (
    inventario_id INT AUTO_INCREMENT,
    producto_id INT NOT NULL,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 10,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventario PRIMARY KEY (inventario_id),
    CONSTRAINT uq_inventario_producto UNIQUE (producto_id),
    CONSTRAINT chk_inventario_stock CHECK (stock_actual >= 0 AND stock_minimo >= 0),
    CONSTRAINT fk_inventario_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 7. Tabla: Kardex_Inventario (Depende de producto y usuario_administrador)
CREATE TABLE kardex_inventario (
    kardex_id INT AUTO_INCREMENT,
    producto_id INT NOT NULL,
    usuario_admin_id INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL,
    cantidad_anterior INT NOT NULL,
    cantidad_movimiento INT NOT NULL,
    cantidad_resultante INT NOT NULL,
    motivo TEXT NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_kardex PRIMARY KEY (kardex_id),
    CONSTRAINT chk_kardex_tipo CHECK (tipo_movimiento IN ('Entrada', 'Salida', 'Ajuste')),
    CONSTRAINT chk_kardex_cantidades CHECK (cantidad_anterior >= 0 AND cantidad_resultante >= 0),
    CONSTRAINT fk_kardex_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_kardex_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 8. Tabla: Carrito (Depende de cliente)
CREATE TABLE carrito (
    carrito_id INT AUTO_INCREMENT,
    cliente_id INT NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_carrito PRIMARY KEY (carrito_id),
    CONSTRAINT uq_carrito_cliente UNIQUE (cliente_id),
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (cliente_id) 
        REFERENCES cliente(cliente_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 9. Tabla: Carrito_Detalle (Depende de carrito y producto)
CREATE TABLE carrito_detalle (
    detalle_carrito_id INT AUTO_INCREMENT,
    carrito_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL DEFAULT 1.00,
    CONSTRAINT pk_carrito_detalle PRIMARY KEY (detalle_carrito_id),
    CONSTRAINT uq_carrito_producto UNIQUE (carrito_id, producto_id),
    CONSTRAINT chk_carrito_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_detcarrito_carrito FOREIGN KEY (carrito_id) 
        REFERENCES carrito(carrito_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detcarrito_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10. Tabla: Pedido (Depende de cliente y usuario_administrador)
CREATE TABLE pedido (
    pedido_id INT AUTO_INCREMENT,
    cliente_id INT NOT NULL,
    usuario_admin_id INT NULL,
    fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_transaccion VARCHAR(30) NOT NULL DEFAULT 'Venta',
    estado VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
    estado_pago VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
    total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    monto_adelanto DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    monto_pendiente DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    direccion_entrega TEXT NULL,
    observaciones VARCHAR(500) NULL,
    CONSTRAINT pk_pedido PRIMARY KEY (pedido_id),
    CONSTRAINT chk_pedido_tipo CHECK (tipo_transaccion IN ('Venta', 'Reserva')),
    CONSTRAINT chk_pedido_estado CHECK (estado IN ('Pendiente', 'Confirmado', 'Atendido', 'Cancelado')),
    CONSTRAINT chk_pedido_estado_pago CHECK (estado_pago IN ('Pendiente', 'Parcial', 'Pagado')),
    CONSTRAINT chk_pedido_montos CHECK (total >= 0 AND monto_adelanto >= 0 AND monto_pendiente >= 0),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) 
        REFERENCES cliente(cliente_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pedido_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 11. Tabla: Detalle_Pedido (Depende de pedido y producto)
CREATE TABLE detalle_pedido (
    detalle_pedido_id INT AUTO_INCREMENT,
    pedido_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (detalle_pedido_id),
    CONSTRAINT uq_pedido_producto UNIQUE (pedido_id, producto_id),
    CONSTRAINT chk_detpedido_valores CHECK (cantidad > 0 AND precio_unitario >= 0 AND subtotal >= 0),
    CONSTRAINT fk_detpedido_pedido FOREIGN KEY (pedido_id) 
        REFERENCES pedido(pedido_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detpedido_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 12. Tabla: Auditoria_Acciones (Depende de usuario_administrador)
CREATE TABLE auditoria_acciones (
    auditoria_id INT AUTO_INCREMENT,
    usuario_admin_id INT NOT NULL,
    accion VARCHAR(100) NOT NULL,
    entidad VARCHAR(50) NOT NULL,
    entidad_id BIGINT NOT NULL,
    datos_anteriores JSON NULL,
    datos_nuevos JSON NULL,
    ip VARCHAR(45) NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria_acciones PRIMARY KEY (auditoria_id),
    CONSTRAINT fk_auditoria_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =============================================================================
-- FASE 3: ÍNDICES DE BASE DE DATOS (CREATE INDEX)
-- Optimización B-Tree sobre columnas de búsqueda frecuente para acelerar consultas.
-- =============================================================================

CREATE INDEX idx_cliente_documento ON cliente(documento);
CREATE INDEX idx_cliente_correo ON cliente(correo);

CREATE INDEX idx_producto_codigo ON producto(codigo);
CREATE INDEX idx_producto_categoria ON producto(categoria_id);

CREATE INDEX idx_pedido_cliente ON pedido(cliente_id);
CREATE INDEX idx_pedido_fecha ON pedido(fecha_pedido);
CREATE INDEX idx_pedido_estado ON pedido(estado);

CREATE INDEX idx_kardex_producto ON kardex_inventario(producto_id);
CREATE INDEX idx_kardex_fecha ON kardex_inventario(fecha_movimiento);

CREATE INDEX idx_auditoria_usuario ON auditoria_acciones(usuario_admin_id);