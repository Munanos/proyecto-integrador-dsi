--Vista resumen pedidos
CREATE OR REPLACE VIEW vw_resumen_pedidos AS
SELECT 
    p.pedido_id,
    p.fecha_pedido,
    p.tipo_transaccion,
    p.estado AS estado_pedido,
    p.estado_pago,
    c.cliente_id,
    CONCAT(c.nombres, ' ', c.apellidos) AS nombre_cliente,
    c.documento AS documento_cliente,
    c.correo AS correo_cliente,
    COALESCE(CONCAT(a.nombres, ' ', a.apellidos), 'Sin Asignar') AS atendido_por,
    p.total,
    p.monto_adelanto,
    p.monto_pendiente,
    COUNT(dp.detalle_pedido_id) AS total_items
FROM pedido p
INNER JOIN cliente c ON p.cliente_id = c.cliente_id
LEFT JOIN usuario_administrador a ON p.usuario_admin_id = a.usuario_admin_id
LEFT JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id
GROUP BY p.pedido_id, c.cliente_id, a.usuario_admin_id;

--Vista Reporte de Inventario y Alertas Stock
CREATE OR REPLACE VIEW vw_reporte_inventario_alertas AS
SELECT 
    p.producto_id,
    p.codigo,
    p.nombre AS nombre_producto,
    cat.nombre AS categoria,
    um.abreviatura AS unidad,
    p.precio_actual,
    i.stock_actual,
    i.stock_minimo,
    CASE 
        WHEN i.stock_actual = 0 THEN 'CRÍTICO: SIN STOCK'
        WHEN i.stock_actual <= i.stock_minimo THEN 'ALERTA: STOCK BAJO'
        ELSE 'NORMAL'
    END AS estado_stock,
    i.fecha_actualizacion
FROM producto p
INNER JOIN categoria cat ON p.categoria_id = cat.categoria_id
INNER JOIN unidad_medida um ON p.unidad_id = um.unidad_id
INNER JOIN inventario i ON p.producto_id = i.producto_id;