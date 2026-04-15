# Проектная работа: сосисочная

Развёртывание БД «Сосисочная». В рамках данной работы
нормализована схема, настроены версионные миграции Flyway и CI/CD-пайплайн
в GitHub Actions.


## Развёртывание

### 1. Поднять PostgreSQL


```bash
docker compose up -d
```

### 2. Создать БД и пользователя для миграций

```bash
docker exec -it postgres psql -U user -d postgres
```

```sql
CREATE DATABASE store;
CREATE USER migrator WITH ENCRYPTED PASSWORD '...';

\c store

ALTER SCHEMA public OWNER TO migrator;

GRANT ALL PRIVILEGES ON DATABASE store   TO migrator;
GRANT ALL PRIVILEGES ON SCHEMA   public  TO migrator;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO migrator;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES    TO migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO migrator;
```

Пользователю migrator выданы права на работу со схемой public — этого
достаточно для DDL и DML Flyway, без суперпользовательских привилегий.

### 3. Прописать секреты в GitHub

Секреты: DB_HOST,DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

### 4. Запуск пайплайна

workflow:

1. Install Flyway (CLI 11.1.0).
2. flyway migrate — применяет V001–V004 к store.
3. Прогон автотестов dbopstest.

## Нормализация (V002)

В исходной схеме были избыточные таблицы product_info и orders_date,
дублирующие данные из product и orders

После V002 нормализации схема состоит из трёх таблиц: product, orders, order_product

## Отчёт: продажи за предыдущую неделю

```sql
SELECT o.date_created, SUM(op.quantity) AS total_sold
FROM orders AS o
    JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

## Производительность до и после индексов

### До индексов 

### После индексов 

Оба индекса созданы с INCLUDE, что позволяет планировщику выполнять сканирование быстрее

