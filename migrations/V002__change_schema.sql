ALTER TABLE product
    ADD COLUMN IF NOT EXISTS price DOUBLE PRECISION;

UPDATE product AS p
SET price = pi.price
FROM product_info AS pi
WHERE pi.product_id = p.id
  AND (p.price IS NULL OR p.price IS DISTINCT FROM pi.price);

DROP TABLE IF EXISTS product_info;


ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS date_created DATE DEFAULT CURRENT_DATE;

UPDATE orders AS o
SET date_created = od.date_created
FROM orders_date AS od
WHERE od.order_id = o.id
  AND (o.date_created IS NULL OR o.date_created IS DISTINCT FROM od.date_created);

UPDATE orders
SET date_created = CURRENT_DATE
WHERE date_created IS NULL;

DROP TABLE IF EXISTS orders_date;


ALTER TABLE product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);

ALTER TABLE orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

ALTER TABLE order_product
    ADD CONSTRAINT order_product_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES orders (id);

ALTER TABLE order_product
    ADD CONSTRAINT order_product_product_id_fkey
    FOREIGN KEY (product_id) REFERENCES product (id);
