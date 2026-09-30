-- =============================================================================
-- BASE DE DATOS: PLATAFORMA WEB ARANZÁBAL
-- Motor: MySQL 8.0+ | Engine: InnoDB | Encoding: utf8mb4
-- =============================================================================

CREATE DATABASE IF NOT EXISTS aranzabal_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE aranzabal_db;

-- -----------------------------------------------------------------------------
-- 1. TABLA: Categoria
-- -----------------------------------------------------------------------------
CREATE TABLE categoria (
    categoria_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. TABLA: Unidad_Medida
-- -----------------------------------------------------------------------------
CREATE TABLE unidad_medida (
    unidad_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    abreviatura VARCHAR(10) NOT NULL
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 3. TABLA: Cliente
-- -----------------------------------------------------------------------------
CREATE TABLE cliente (
    cliente_id INT AUTO_INCREMENT PRIMARY KEY,
    documento VARCHAR(20) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    telefono VARCHAR(20) NULL,
    direccion TEXT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 4. TABLA: Usuario_Administrador
-- -----------------------------------------------------------------------------
CREATE TABLE usuario_administrador (
    usuario_admin_id INT AUTO_INCREMENT PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(30) NOT NULL DEFAULT 'Administrador',
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 5. TABLA: Producto
-- -----------------------------------------------------------------------------
CREATE TABLE producto (
    producto_id INT AUTO_INCREMENT PRIMARY KEY,
    categoria_id INT NOT NULL,
    unidad_id INT NOT NULL,
    codigo VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NULL,
    imagen_url VARCHAR(255) NULL,
    precio_actual DECIMAL(10,2) NOT NULL,
    es_personalizable BOOLEAN NOT NULL DEFAULT FALSE,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) 
        REFERENCES categoria(categoria_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_producto_unidad FOREIGN KEY (unidad_id) 
        REFERENCES unidad_medida(unidad_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 6. TABLA: Inventario (Soporta alerta stock_minimo <= 10)
-- -----------------------------------------------------------------------------
CREATE TABLE inventario (
    inventario_id INT AUTO_INCREMENT PRIMARY KEY,
    producto_id INT NOT NULL UNIQUE,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 10,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventario_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 7. TABLA: Kardex_Inventario (Movimientos e historial)
-- -----------------------------------------------------------------------------
CREATE TABLE kardex_inventario (
    kardex_id INT AUTO_INCREMENT PRIMARY KEY,
    producto_id INT NOT NULL,
    usuario_admin_id INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL, -- 'Entrada', 'Salida', 'Ajuste'
    cantidad_anterior INT NOT NULL,
    cantidad_movimiento INT NOT NULL,
    cantidad_resultante INT NOT NULL,
    motivo TEXT NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kardex_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_kardex_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 8. TABLA: Carrito
-- -----------------------------------------------------------------------------
CREATE TABLE carrito (
    carrito_id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL UNIQUE,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (cliente_id) 
        REFERENCES cliente(cliente_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 9. TABLA: Carrito_Detalle
-- -----------------------------------------------------------------------------
CREATE TABLE carrito_detalle (
    detalle_carrito_id INT AUTO_INCREMENT PRIMARY KEY,
    carrito_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL DEFAULT 1.00,
    CONSTRAINT fk_detcarrito_carrito FOREIGN KEY (carrito_id) 
        REFERENCES carrito(carrito_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detcarrito_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_carrito_producto UNIQUE (carrito_id, producto_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 10. TABLA: Pedido (Procesa Ventas y Reservas)
-- -----------------------------------------------------------------------------
CREATE TABLE pedido (
    pedido_id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    usuario_admin_id INT NULL,
    fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_transaccion VARCHAR(30) NOT NULL DEFAULT 'Venta', -- 'Venta', 'Reserva'
    estado VARCHAR(30) NOT NULL DEFAULT 'Pendiente', -- 'Pendiente', 'Confirmado', 'Atendido', 'Cancelado'
    estado_pago VARCHAR(30) NOT NULL DEFAULT 'Pendiente', -- 'Pendiente', 'Parcial', 'Pagado'
    total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    monto_adelanto DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    monto_pendiente DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    direccion_entrega TEXT NULL,
    observaciones VARCHAR(500) NULL,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) 
        REFERENCES cliente(cliente_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pedido_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 11. TABLA: Detalle_Pedido
-- -----------------------------------------------------------------------------
CREATE TABLE detalle_pedido (
    detalle_pedido_id INT AUTO_INCREMENT PRIMARY KEY,
    pedido_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_detpedido_pedido FOREIGN KEY (pedido_id) 
        REFERENCES pedido(pedido_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detpedido_producto FOREIGN KEY (producto_id) 
        REFERENCES producto(producto_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_pedido_producto UNIQUE (pedido_id, producto_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 12. TABLA: Auditoria_Acciones
-- -----------------------------------------------------------------------------
CREATE TABLE auditoria_acciones (
    auditoria_id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_admin_id INT NOT NULL,
    accion VARCHAR(100) NOT NULL,
    entidad VARCHAR(50) NOT NULL,
    entidad_id BIGINT NOT NULL,
    datos_anteriores JSON NULL,
    datos_nuevos JSON NULL,
    ip VARCHAR(45) NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_auditoria_admin FOREIGN KEY (usuario_admin_id) 
        REFERENCES usuario_administrador(usuario_admin_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;