-- =========================================================
-- 1. FUNDAMENTOS: DDL, restricciones
-- =========================================================
CREATE TABLE ejemplo (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio NUMERIC(10,2) CHECK (precio > 0),
    categoria_id INTEGER REFERENCES categoria(id),
    creado_en TIMESTAMP DEFAULT NOW()
);


-- =========================================================
-- 2. SELECT BASICO: filtros, DISTINCT, ORDER BY, LIMIT/OFFSET
-- =========================================================
SELECT * FROM public.film
WHERE rental_rate BETWEEN 1 AND 3
  AND rating IN ('G', 'PG')
  AND title ILIKE 'a%';

SELECT DISTINCT rating FROM public.film;

SELECT title, rental_rate
FROM public.film
ORDER BY rental_rate DESC
LIMIT 5 OFFSET 10;


-- =========================================================
-- 3. FUNCIONES DE TEXTO Y FECHA
-- =========================================================
SELECT
    UPPER(first_name)                  AS nombre_mayus,
    LOWER(last_name)                   AS apellido_minus,
    CONCAT(first_name, ' ', last_name) AS nombre_completo,
    LENGTH(first_name)                 AS largo_nombre,
    SUBSTRING(last_name FROM 1 FOR 3)  AS primeras_letras,
    TRIM('  hola  ')                   AS sin_espacios
FROM public.customer;

SELECT
    rental_date,
    NOW()                             AS fecha_actual,
    AGE(NOW(), rental_date)           AS antiguedad,
    EXTRACT(YEAR FROM rental_date)    AS anio,
    DATE_TRUNC('month', rental_date)  AS mes
FROM public.rental;


-- =========================================================
-- 4. JOIN
-- =========================================================
SELECT c.customer_id, c.first_name
FROM public.customer c
LEFT JOIN public.rental r ON r.customer_id = c.customer_id
WHERE r.rental_id IS NULL;

SELECT e.first_name AS empleado, m.first_name AS jefe
FROM employees.employee e
JOIN employees.employee m ON e.manager_id = m.id;


-- =========================================================
-- 5. GROUP BY Y HAVING
-- =========================================================
SELECT t.name, COUNT(*) AS total
FROM public.lego_themes t
JOIN public.lego_sets s ON s.theme_id = t.id
GROUP BY t.name
HAVING COUNT(*) > 50
ORDER BY total DESC;


-- =========================================================
-- 6. SUBCONSULTAS
-- =========================================================
SELECT * FROM employees.employee e
JOIN employees.salary s ON s.employee_id = e.id
WHERE s.amount > (SELECT AVG(amount) FROM employees.salary);

SELECT e.id, s.amount
FROM employees.employee e
JOIN employees.salary s ON s.employee_id = e.id AND s.to_date = '9999-01-01'
JOIN employees.department_employee de ON de.employee_id = e.id AND de.to_date = '9999-01-01'
WHERE s.amount > (
    SELECT AVG(s2.amount)
    FROM employees.salary s2
    JOIN employees.department_employee de2 ON de2.employee_id = s2.employee_id
    WHERE de2.department_id = de.department_id
      AND s2.to_date = '9999-01-01'
);


-- =========================================================
-- 7. CTE
-- =========================================================
WITH resumen AS (
    SELECT theme_id, COUNT(*) AS total
    FROM public.lego_sets
    GROUP BY theme_id
)
SELECT t.name, r.total
FROM resumen r
JOIN public.lego_themes t ON t.id = r.theme_id
WHERE r.total > 20;


-- =========================================================
-- 8. WINDOW FUNCTIONS
-- =========================================================
SELECT
    title,
    rating,
    rental_rate,
    RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS ranking_por_clasificacion
FROM public.film;


-- =========================================================
-- 9. UNION Y CASE WHEN
-- =========================================================
SELECT first_name AS nombre FROM public.customer
UNION
SELECT first_name FROM public.staff;

SELECT title,
       CASE
           WHEN rental_rate < 1 THEN 'economica'
           WHEN rental_rate BETWEEN 1 AND 3 THEN 'media'
           ELSE 'premium'
       END AS categoria_precio
FROM public.film;


-- =========================================================
-- 10. VISTAS
-- =========================================================
CREATE VIEW vista_clientes_totales AS
SELECT c.customer_id, c.first_name, SUM(p.amount) AS total_pagado
FROM public.customer c
JOIN public.payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name;

SELECT * FROM vista_clientes_totales WHERE total_pagado > 100;


-- =========================================================
-- 11. TRANSACCIONES
-- =========================================================
BEGIN;
UPDATE employees.salary SET amount = amount * 1.1 WHERE employee_id = 10001;
ROLLBACK;
-- o bien: COMMIT;


-- =========================================================
-- 12. INDICES
-- =========================================================
CREATE INDEX idx_employee_last_name ON employees.employee (last_name);

CREATE INDEX idx_salary_employee_todate ON employees.salary (employee_id, to_date);

CREATE UNIQUE INDEX idx_email_unico ON public.customer (email);


-- =========================================================
-- 13. EXPLAIN / EXPLAIN ANALYZE
-- =========================================================
EXPLAIN SELECT * FROM public.film WHERE rating = 'PG-13';

EXPLAIN ANALYZE SELECT * FROM public.film WHERE rating = 'PG-13';

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.film WHERE rating = 'PG-13';


-- =========================================================
-- 14. MANTENIMIENTO
-- =========================================================
VACUUM ANALYZE public.film;


-- =========================================================
-- 15. FASE A - DVD RENTAL
-- =========================================================

-- 15.1 Listar peliculas y aplicar filtros
SELECT film_id, title, release_year, rating, rental_rate, length
FROM public.film
WHERE rating = 'PG-13'
  AND rental_rate > 2.99
ORDER BY title;

-- 15.2 Contar peliculas por clasificacion
SELECT rating, COUNT(*) AS total_peliculas
FROM public.film
GROUP BY rating
ORDER BY total_peliculas DESC;

-- 15.3 Relacionar clientes con alquileres
SELECT c.customer_id, c.first_name, c.last_name,
       r.rental_id, r.rental_date, r.return_date
FROM public.customer c
JOIN public.rental r ON r.customer_id = c.customer_id
ORDER BY c.customer_id, r.rental_date;

-- 15.4 Total pagado por cliente
SELECT c.customer_id, c.first_name, c.last_name,
       SUM(p.amount) AS total_pagado
FROM public.customer c
JOIN public.payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_pagado DESC;

-- 15.5 Consulta con 3+ JOIN
SELECT f.title, l.name AS idioma, c.name AS categoria, f.rental_rate
FROM public.film f
JOIN public.language      l  ON l.language_id  = f.language_id
JOIN public.film_category fc ON fc.film_id      = f.film_id
JOIN public.category      c  ON c.category_id   = fc.category_id
ORDER BY f.title;

-- 15.6 EXPLAIN ANALYZE + indice
EXPLAIN ANALYZE
SELECT * FROM public.customer WHERE last_name = 'Smith';

CREATE INDEX idx_customer_last_name ON public.customer (last_name);

EXPLAIN ANALYZE
SELECT * FROM public.customer WHERE last_name = 'Smith';


-- =========================================================
-- 16. FASE B - LEGO
-- =========================================================

-- 16.1 Anios con mas sets
SELECT year, COUNT(*) AS total_sets
FROM public.lego_sets
WHERE year IS NOT NULL
GROUP BY year
ORDER BY total_sets DESC
LIMIT 10;

-- 16.2 Sets con mas piezas
SELECT set_num, name, year, num_parts
FROM public.lego_sets
ORDER BY num_parts DESC NULLS LAST
LIMIT 20;

-- 16.3 Sets relacionados con temas
SELECT s.set_num, s.name, s.year, t.name AS tema
FROM public.lego_sets s
JOIN public.lego_themes t ON t.id = s.theme_id
ORDER BY t.name, s.name;

-- 16.4 Estadisticas por tema
SELECT t.name AS tema,
       COUNT(s.set_num) AS cantidad_sets,
       ROUND(AVG(s.num_parts), 2) AS promedio_piezas,
       MIN(s.num_parts) AS min_piezas,
       MAX(s.num_parts) AS max_piezas
FROM public.lego_themes t
JOIN public.lego_sets s ON s.theme_id = t.id
GROUP BY t.name
ORDER BY cantidad_sets DESC;

-- 16.5 Consulta con CTE
WITH sets_por_anio AS (
    SELECT year, COUNT(*) AS total_sets, AVG(num_parts) AS promedio_piezas
    FROM public.lego_sets
    WHERE year IS NOT NULL
    GROUP BY year
)
SELECT year, total_sets, ROUND(promedio_piezas, 2) AS promedio_piezas
FROM sets_por_anio
WHERE total_sets > (SELECT AVG(total_sets) FROM sets_por_anio)
ORDER BY total_sets DESC;

-- 16.6 Filtro antes/despues de indice
EXPLAIN ANALYZE
SELECT * FROM public.lego_sets WHERE theme_id = 158;

CREATE INDEX idx_lego_sets_theme_id ON public.lego_sets (theme_id);

EXPLAIN ANALYZE
SELECT * FROM public.lego_sets WHERE theme_id = 158;


-- =========================================================
-- 17. FASE C - EMPLOYEES
-- =========================================================

-- 17.1 Volumen de las tablas
SELECT relname AS tabla,
       n_live_tup AS filas_aproximadas,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total
FROM pg_stat_user_tables
WHERE schemaname = 'employees'
ORDER BY n_live_tup DESC;

-- 17.2 Indices existentes
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'employees'
ORDER BY tablename, indexname;

-- 17.3 Columna no indexada
EXPLAIN ANALYZE
SELECT * FROM employees.employee WHERE last_name = 'Baba';

-- 17.4 Indice simple
CREATE INDEX idx_employee_last_name ON employees.employee (last_name);

EXPLAIN ANALYZE
SELECT * FROM employees.employee WHERE last_name = 'Baba';

-- 17.5 Indice compuesto
EXPLAIN ANALYZE
SELECT * FROM employees.salary
WHERE employee_id = 10001 AND to_date = '9999-01-01';

CREATE INDEX idx_salary_employee_todate ON employees.salary (employee_id, to_date);

EXPLAIN ANALYZE
SELECT * FROM employees.salary
WHERE employee_id = 10001 AND to_date = '9999-01-01';

-- 17.6 JOIN grande
EXPLAIN ANALYZE
SELECT e.id, e.first_name, e.last_name, d.dept_name, t.title, s.amount AS salario_actual
FROM employees.employee e
JOIN employees.department_employee de ON de.employee_id = e.id
JOIN employees.department d           ON d.id = de.department_id
JOIN employees.title t                ON t.employee_id = e.id
JOIN employees.salary s               ON s.employee_id = e.id
WHERE de.to_date = '9999-01-01'
  AND t.to_date  = '9999-01-01'
  AND s.to_date  = '9999-01-01';


-- =========================================================
-- 18. PRACTICA EXTRA
-- =========================================================

-- 18.1 LEFT JOIN: clientes sin alquileres
SELECT c.customer_id, c.first_name, c.last_name
FROM public.customer c
LEFT JOIN public.rental r ON r.customer_id = c.customer_id
WHERE r.rental_id IS NULL;

-- 18.2 Subconsulta correlacionada: salario sobre el promedio del propio departamento
SELECT e.id, s.amount
FROM employees.employee e
JOIN employees.salary s ON s.employee_id = e.id AND s.to_date = '9999-01-01'
JOIN employees.department_employee de ON de.employee_id = e.id AND de.to_date = '9999-01-01'
WHERE s.amount > (
    SELECT AVG(s2.amount)
    FROM employees.salary s2
    JOIN employees.department_employee de2 ON de2.employee_id = s2.employee_id
    WHERE de2.department_id = de.department_id
      AND s2.to_date = '9999-01-01'
);

-- 18.3 CTE con JOIN: sets de un tema especifico
WITH sets_tema AS (
    SELECT s.name, s.num_parts, t.name AS tema
    FROM public.lego_sets s
    JOIN public.lego_themes t ON t.id = s.theme_id
    WHERE t.name = 'Star Wars'
)
SELECT * FROM sets_tema ORDER BY num_parts DESC;

-- 18.4 Indice para acelerar ORDER BY
EXPLAIN ANALYZE
SELECT * FROM public.film ORDER BY rental_rate DESC LIMIT 10;

CREATE INDEX idx_film_rental_rate ON public.film (rental_rate DESC);

EXPLAIN ANALYZE
SELECT * FROM public.film ORDER BY rental_rate DESC LIMIT 10;

-- 18.5 GROUP BY + HAVING
SELECT t.name, COUNT(*) AS total
FROM public.lego_themes t
JOIN public.lego_sets s ON s.theme_id = t.id
GROUP BY t.name
HAVING COUNT(*) > 50
ORDER BY total DESC;

-- 18.6 DISTINCT
SELECT DISTINCT l.name
FROM public.language l
JOIN public.film f ON f.language_id = l.language_id;

-- 18.7 Window function: ranking por clasificacion
SELECT title, rating, rental_rate,
       RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS ranking
FROM public.film;

-- 18.8 UNION: nombres combinados
SELECT first_name AS nombre FROM public.customer
UNION
SELECT first_name FROM public.staff;

-- 18.9 CASE WHEN: categorizar precio
SELECT title,
       CASE
           WHEN rental_rate < 1 THEN 'economica'
           WHEN rental_rate BETWEEN 1 AND 3 THEN 'media'
           ELSE 'premium'
       END AS categoria_precio
FROM public.film;

-- 18.10 Vista reutilizable
CREATE VIEW vista_clientes_totales AS
SELECT c.customer_id, c.first_name, SUM(p.amount) AS total_pagado
FROM public.customer c
JOIN public.payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name;

SELECT * FROM vista_clientes_totales WHERE total_pagado > 100;

-- 18.11 Transaccion con posibilidad de revertir
BEGIN;
UPDATE employees.salary SET amount = amount * 1.1 WHERE employee_id = 10001;
ROLLBACK;
