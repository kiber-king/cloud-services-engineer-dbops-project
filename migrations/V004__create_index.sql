CREATE INDEX IF NOT EXISTS idx_orders_status_date
    ON orders (status, date_created) INCLUDE (id);

CREATE INDEX IF NOT EXISTS idx_order_product_order_id
    ON order_product (order_id) INCLUDE (quantity);
