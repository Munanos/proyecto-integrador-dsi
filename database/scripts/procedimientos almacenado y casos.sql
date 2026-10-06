-- precedimiento Almacenado procesar pedido
DELIMITER //

CREATE PROCEDURE sp_procesar_pedido_transaccional (
    IN p_cliente_id INT,
    IN p_producto_id INT,
    IN p_cantidad INT,
    IN p_tipo_transaccion VARCHAR(30),
    IN p_direccion_entrega TEXT,
    IN p_observaciones VARCHAR(500)
)
BEGIN
    -- Declaración de variables locales
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_stock_actual INT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_pedido_id INT;
    
    -- Control de excepciones: ante cualquier error deshace los cambios
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Inicio de la transacción atómica
    START TRANSACTION;

    -- 1. Validar existencia y precio del producto
    SELECT precio_actual INTO v_precio
    FROM producto 
    WHERE producto_id = p_producto_id AND estado = 'Activo';

    IF v_precio IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El producto especificado no existe o se encuentra inactivo.';
    END IF;

    -- 2. Validar disponibilidad en inventario
    SELECT stock_actual INTO v_stock_actual
    FROM inventario 
    WHERE producto_id = p_producto_id FOR UPDATE;

    IF v_stock_actual IS NULL OR v_stock_actual < p_cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Stock insuficiente para procesar el pedido.';
    END IF;

    -- 3. Calcular importe total
    SET v_total = v_precio * p_cantidad;

    -- 4. Registrar la cabecera en la tabla pedido
    INSERT INTO pedido (
        cliente_id, usuario_admin_id, fecha_pedido, tipo_transaccion, 
        estado, estado_pago, total, monto_adelanto, monto_pendiente, 
        direccion_entrega, observaciones
    ) VALUES (
        p_cliente_id, NULL, NOW(), p_tipo_transaccion, 
        'Pendiente', 'Pendiente', v_total, 0.00, v_total, 
        p_direccion_entrega, p_observaciones
    );

    SET v_pedido_id = LAST_INSERT_ID();

    -- 5. Registrar el detalle del pedido
    INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (v_pedido_id, p_producto_id, p_cantidad, v_precio, v_total);

    -- 6. Actualizar inventario (Restar stock)
    UPDATE inventario 
    SET stock_actual = stock_actual - p_cantidad
    WHERE producto_id = p_producto_id;

    -- 7. Registrar en Kardex auditoría de salida
    INSERT INTO kardex_inventario (
        producto_id, usuario_admin_id, tipo_movimiento, 
        cantidad_anterior, cantidad_movimiento, cantidad_resultante, 
        motivo, fecha_movimiento
    ) VALUES (
        p_producto_id, 1, 'Salida', 
        v_stock_actual, p_cantidad, (v_stock_actual - p_cantidad), 
        CONCAT('Salida por registro de pedido N° ', v_pedido_id), NOW()
    );

    -- Confirmación de la transacción
    COMMIT;
    
    SELECT v_pedido_id AS pedido_generado, 'Pedido procesado exitosamente' AS mensaje;
END //

DELIMITER ;


--Precedimiento almacenado cancelar pedido
DELIMITER //

CREATE PROCEDURE sp_cancelar_pedido_transaccional (
    IN p_pedido_id INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(30);
    DECLARE v_producto_id INT;
    DECLARE v_cantidad INT;
    DECLARE v_stock_actual INT;

    -- Manejador de excepciones con reversión de transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Validar estado del pedido
    SELECT estado INTO v_estado_actual
    FROM pedido
    WHERE pedido_id = p_pedido_id FOR UPDATE;

    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El pedido especificado no existe.';
    ELSEIF v_estado_actual = 'Atendido' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede cancelar un pedido que ya ha sido Atendido.';
    ELSEIF v_estado_actual = 'Cancelado' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El pedido ya se encuentra cancelado.';
    END IF;

    -- 2. Obtener datos del detalle del pedido
    SELECT producto_id, cantidad INTO v_producto_id, v_cantidad
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id
    LIMIT 1;

    -- 3. Obtener stock actual para la auditoría
    SELECT stock_actual INTO v_stock_actual
    FROM inventario
    WHERE producto_id = v_producto_id FOR UPDATE;

    -- 4. Reponer stock en inventario
    UPDATE inventario
    SET stock_actual = stock_actual + v_cantidad
    WHERE producto_id = v_producto_id;

    -- 5. Registrar devolución en Kardex
    INSERT INTO kardex_inventario (
        producto_id, usuario_admin_id, tipo_movimiento,
        cantidad_anterior, cantidad_movimiento, cantidad_resultante,
        motivo, fecha_movimiento
    ) VALUES (
        v_producto_id, 1, 'Entrada',
        v_stock_actual, v_cantidad, (v_stock_actual + v_cantidad),
        CONCAT('Reingreso por cancelacion del pedido N° ', p_pedido_id, '. Motivo: ', p_motivo), NOW()
    );

    -- 6. Actualizar estado del pedido
    UPDATE pedido
    SET estado = 'Cancelado',
        observaciones = CONCAT(COALESCE(observaciones, ''), ' | Cancelado: ', p_motivo)
    WHERE pedido_id = p_pedido_id;

    COMMIT;

    SELECT p_pedido_id AS pedido_cancelado, 'Pedido cancelado y stock reexpedido exitosamente' AS mensaje;
END //

DELIMITER ;


-- ============================================================================
-- CASO 1: Prueba de Registro Exitoso (Parámetros Válidos)
-- ============================================================================
CALL sp_procesar_pedido_transaccional(
    1,                    -- ID de cliente válido
    1,                    -- ID de producto con stock suficiente
    2,                    -- Cantidad solicitada
    'Venta Directa', 
    'Av. El Sol 456, Cusco', 
    'Entrega urgente'
);

-- ============================================================================
-- CASO 2: Prueba de Error por Producto Inexistente (Parámetro Inválido)
-- ============================================================================
-- Resultado Esperado: Detiene ejecución y lanza exception: "Error: El producto especificado no existe..."
CALL sp_procesar_pedido_transaccional(
    1, 
    99999,                -- ID inexistente
    1, 
    'Venta Directa', 
    'Av. El Sol 456', 
    'Prueba de fallo'
);

-- ============================================================================
-- CASO 3: Prueba de Error por Stock Insuficiente (Parámetro Inválido)
-- ============================================================================
-- Resultado Esperado: Detiene ejecución y lanza exception: "Error: Stock insuficiente..."
CALL sp_procesar_pedido_transaccional(
    1, 
    1, 
    500000,               -- Cantidad excesiva superior al stock
    'Venta Directa', 
    'Av. El Sol 456', 
    'Prueba de sobrestock'
);

-- ============================================================================
-- CASO 4: Prueba de Cancelación Invalida (Pedido en estado Atendido)
-- ============================================================================
-- Resultado Esperado: Lanza exception: "Error: No se puede cancelar un pedido..."
CALL sp_cancelar_pedido_transaccional(1, 'Cliente solicita anulación');