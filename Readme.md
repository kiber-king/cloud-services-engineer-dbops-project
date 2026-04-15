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

Секреты: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

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

Запрос для замера — тот же отчёт, обёрнутый в EXPLAIN:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.date_created, SUM(op.quantity) AS total_sold
FROM orders AS o
    JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

### До индексов 
``` 
 Finalize GroupAggregate  (cost=266111.40..266134.46 rows=91 width=12) (actual time=9809.771..9859.393 rows=7 loops=1)
   Group Key: o.date_created
   Buffers: shared hit=2809 read=124621
   ->  Gather Merge  (cost=266111.40..266132.64 rows=182 width=12) (actual time=9809.740..9859.361 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2809 read=124621
         ->  Sort  (cost=265111.38..265111.61 rows=91 width=12) (actual time=9773.609..9773.614 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=2809 read=124621
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=265107.51..265108.42 rows=91 width=12) (actual time=9773.586..9773.591 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared hit=2793 read=124621
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Hash Join  (cost=148299.95..264598.43 rows=101815 width=8) (actual time=4344.392..9749.339 rows=81901 loops=3)
                           Hash Cond: (op.order_id = o.id)
                           Buffers: shared hit=2793 read=124621
                           ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.13 rows=4166613 width=12) (actual time=7.118..4117.543 rows=3333333 loops=3)
                                 Buffers: shared hit=384 read=63311
                           ->  Parallel Hash  (cost=147027.26..147027.26 rows=101815 width=12) (actual time=4336.315..4336.316 rows=81901 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 13632kB
                                 Buffers: shared hit=2385 read=61310
                                 ->  Parallel Seq Scan on orders o  (cost=0.00..147027.26 rows=101815 width=12) (actual time=15.500..4288.994 rows=81901 loops=3)
                                       Filter: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Rows Removed by Filter: 3251433
                                       Buffers: shared hit=2385 read=61310
 Planning:
   Buffers: shared hit=8
 Planning Time: 0.225 ms
 JIT:
   Functions: 54
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 5.192 ms, Inlining 0.000 ms, Optimization 1.286 ms, Emission 45.348 ms, Total 51.826 ms
 Execution Time: 9860.307 ms
```
### После индексов 

```
 Finalize GroupAggregate  (cost=1001.02..146269.61 rows=91 width=12) (actual time=692.826..700.985 rows=7 loops=1)
   Group Key: o.date_created
   Buffers: shared hit=582211 read=176129
   ->  Gather Merge  (cost=1001.02..146267.79 rows=182 width=12) (actual time=692.190..700.938 rows=16 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=582211 read=176129
         ->  Partial GroupAggregate  (cost=1.00..145246.76 rows=91 width=12) (actual time=126.678..480.160 rows=5 loops=3)
               Group Key: o.date_created
               Buffers: shared hit=582211 read=176129
               ->  Nested Loop  (cost=1.00..144736.77 rows=101815 width=8) (actual time=9.214..470.726 rows=81901 loops=3)
                     Buffers: shared hit=582211 read=176129
                     ->  Parallel Index Only Scan using idx_orders_status_date on orders o  (cost=0.56..33560.41 rows=101815 width=12) (actual time=9.142..63.174 rows=81901 loops=3)
                           Index Cond: ((status = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                           Heap Fetches: 25895
                           Buffers: shared hit=69 read=21132
                     ->  Index Only Scan using idx_order_product_order_id on order_product op  (cost=0.43..1.08 rows=1 width=12) (actual time=0.004..0.005 rows=1 loops=245702)
                           Index Cond: (order_id = o.id)
                           Heap Fetches: 0
                           Buffers: shared hit=582142 read=154997
 Planning:
   Buffers: shared hit=244 read=37
 Planning Time: 203.666 ms
 JIT:
   Functions: 27
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.170 ms, Inlining 0.000 ms, Optimization 0.853 ms, Emission 26.320 ms, Total 29.343 ms
 Execution Time: 730.968 ms
```

Оба индекса созданы с INCLUDE, что позволяет планировщику выполнять сканирование быстрее

Время выполнения сократилось с `9860.307` ms до `730.968` ms после использования индексов 

Без индексов Postgres читает обе таблицы целиком (по 10 млн строк) и только
потом отбрасывает лишнее. С индексами он сразу смотрит по нужным заказам
за последнюю неделю. Благодаря этому идет ускорение запроса в 13 раз.
