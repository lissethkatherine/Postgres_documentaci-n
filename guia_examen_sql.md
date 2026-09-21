# Guía de estudio — Examen SQL (DVD Rental, LEGO, Employees)

Teoría completa + ejercicios resueltos + práctica extra. El código SQL corrido (sin explicaciones) está en el archivo `ejercicios_examen.sql` que acompaña esta guía.

---

## 1. Fundamentos de SQL

### 1.1 Categorías de comandos
| Categoría | Para qué sirve | Ejemplos |
|---|---|---|
| DDL (Data Definition Language) | Definir estructura | `CREATE`, `ALTER`, `DROP` |
| DML (Data Manipulation Language) | Modificar datos | `INSERT`, `UPDATE`, `DELETE` |
| DQL (Data Query Language) | Consultar datos | `SELECT` |
| DCL (Data Control Language) | Permisos | `GRANT`, `REVOKE` |
| TCL (Transaction Control Language) | Transacciones | `BEGIN`, `COMMIT`, `ROLLBACK` |

### 1.2 Tipos de datos comunes en PostgreSQL
- Numéricos: `INTEGER`, `SMALLINT`, `BIGINT`, `NUMERIC(p,s)`, `REAL`, `DOUBLE PRECISION`
- Texto: `VARCHAR(n)`, `TEXT`, `CHAR(n)`
- Fecha/hora: `DATE`, `TIME`, `TIMESTAMP`, `TIMESTAMPTZ`, `INTERVAL`
- Booleano: `BOOLEAN`
- Otros: `SERIAL` (autoincremental), `UUID`, `JSON`/`JSONB`, `ARRAY`

### 1.3 Restricciones (constraints)
- `PRIMARY KEY`: identifica de forma única cada fila.
- `FOREIGN KEY`: referencia a la clave primaria de otra tabla.
- `UNIQUE`: no permite valores repetidos.
- `NOT NULL`: obliga a que la columna tenga un valor.
- `CHECK`: valida una condición (ej: `CHECK (rental_rate > 0)`).
- `DEFAULT`: valor por defecto si no se especifica uno.

```sql
CREATE TABLE ejemplo (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio NUMERIC(10,2) CHECK (precio > 0),
    categoria_id INTEGER REFERENCES categoria(id),
    creado_en TIMESTAMP DEFAULT NOW()
);
```

### 1.4 Orden lógico de ejecución de un SELECT
Aunque se escribe `SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT`, el motor lo **ejecuta** en este orden:
`FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY` → `LIMIT`.
Por eso no se puede usar un alias del `SELECT` en el `WHERE`, pero sí en el `ORDER BY`.

---

## 2. Consultas SELECT básicas

### 2.1 Operadores de filtro en WHERE
| Operador | Uso |
|---|---|
| `=`, `<>`, `>`, `<`, `>=`, `<=` | Comparación |
| `BETWEEN a AND b` | Rango incluyente |
| `IN (a, b, c)` | Pertenece a una lista |
| `LIKE 'patron%'` | Coincidencia de texto (sensible a mayúsculas) |
| `ILIKE 'patron%'` | Igual que LIKE, insensible a mayúsculas |
| `IS NULL` / `IS NOT NULL` | Comprobar nulos |
| `AND`, `OR`, `NOT` | Combinar condiciones |

```sql
SELECT * FROM public.film
WHERE rental_rate BETWEEN 1 AND 3
  AND rating IN ('G', 'PG')
  AND title ILIKE 'a%';
```

### 2.2 DISTINCT, ORDER BY, LIMIT/OFFSET
```sql
SELECT DISTINCT rating FROM public.film;

SELECT title, rental_rate
FROM public.film
ORDER BY rental_rate DESC
LIMIT 5 OFFSET 10;   -- salta los primeros 10 y trae los siguientes 5
```

---

## 3. Funciones de texto y de fecha

### 3.1 Texto
```sql
SELECT
    UPPER(first_name)                 AS nombre_mayus,
    LOWER(last_name)                  AS apellido_minus,
    CONCAT(first_name, ' ', last_name) AS nombre_completo,
    LENGTH(first_name)                AS largo_nombre,
    SUBSTRING(last_name FROM 1 FOR 3) AS primeras_letras,
    TRIM('  hola  ')                  AS sin_espacios
FROM public.customer;
```

### 3.2 Fecha
```sql
SELECT
    rental_date,
    NOW()                                   AS fecha_actual,
    AGE(NOW(), rental_date)                 AS antiguedad,
    EXTRACT(YEAR FROM rental_date)          AS anio,
    DATE_TRUNC('month', rental_date)        AS mes
FROM public.rental;
```

---

## 4. JOIN

| Tipo | Qué devuelve |
|---|---|
| `INNER JOIN` | Solo filas que coinciden en ambas tablas |
| `LEFT JOIN` | Todas las de la izquierda + coincidencias de la derecha (NULL si no hay) |
| `RIGHT JOIN` | Todas las de la derecha + coincidencias de la izquierda |
| `FULL JOIN` | Todas las filas de ambas tablas, coincidan o no |
| `SELF JOIN` | Una tabla unida consigo misma (ej: empleado-jefe) |
| `CROSS JOIN` | Producto cartesiano (todas las combinaciones posibles) |

```sql
-- LEFT JOIN: clientes que nunca alquilaron nada
SELECT c.customer_id, c.first_name
FROM public.customer c
LEFT JOIN public.rental r ON r.customer_id = c.customer_id
WHERE r.rental_id IS NULL;

-- SELF JOIN: empleados y su jefe directo (si la tabla tuviera manager_id)
SELECT e.first_name AS empleado, m.first_name AS jefe
FROM employees.employee e
JOIN employees.employee m ON e.manager_id = m.id;
```

---

## 5. Agregaciones: GROUP BY y HAVING

- `WHERE` filtra filas antes de agrupar.
- `HAVING` filtra grupos después de agrupar.
- Toda columna no agregada del `SELECT` debe estar en el `GROUP BY`.

```sql
SELECT t.name, COUNT(*) AS total
FROM public.lego_themes t
JOIN public.lego_sets s ON s.theme_id = t.id
GROUP BY t.name
HAVING COUNT(*) > 50
ORDER BY total DESC;
```

---

## 6. Subconsultas

- **Escalar**: devuelve un solo valor, se usa en `WHERE` o `SELECT`.
- **De fila/lista**: se usa con `IN`, `ANY`, `ALL`.
- **Correlacionada**: hace referencia a la consulta externa, se ejecuta una vez por cada fila externa.
- **En el FROM**: se trata como una tabla temporal.

```sql
-- Escalar
SELECT * FROM employees.employee e
JOIN employees.salary s ON s.employee_id = e.id
WHERE s.amount > (SELECT AVG(amount) FROM employees.salary);

-- Correlacionada: salario por encima del promedio de SU departamento
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
```

---

## 7. CTE (Common Table Expression)

Se define con `WITH`, crea un resultado temporal con nombre reutilizable en la consulta principal. Ordena consultas complejas en pasos legibles. También soporta CTE recursivas (`WITH RECURSIVE`) para jerarquías (ej: árbol de categorías).

```sql
WITH resumen AS (
    SELECT theme_id, COUNT(*) AS total
    FROM public.lego_sets
    GROUP BY theme_id
)
SELECT t.name, r.total
FROM resumen r
JOIN public.lego_themes t ON t.id = r.theme_id
WHERE r.total > 20;
```

---

## 8. Funciones de ventana (Window Functions)

A diferencia de `GROUP BY`, no colapsan las filas: agregan una columna calculada manteniendo el detalle de cada fila.

| Función | Qué hace |
|---|---|
| `ROW_NUMBER()` | Numera las filas dentro de cada partición |
| `RANK()` | Igual, pero deja huecos si hay empates |
| `DENSE_RANK()` | Igual que RANK pero sin huecos |
| `SUM()/AVG() OVER (...)` | Acumulados o promedios sin perder el detalle |

```sql
SELECT
    title,
    rating,
    rental_rate,
    RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS ranking_por_clasificacion
FROM public.film;
```

---

## 9. UNION, CASE WHEN

```sql
-- UNION: junta resultados de dos consultas (elimina duplicados)
-- UNION ALL: igual pero conserva duplicados (más rápido)
SELECT first_name AS nombre FROM public.customer
UNION
SELECT first_name FROM public.staff;

-- CASE WHEN: valor condicional dentro de una consulta
SELECT title,
       CASE
           WHEN rental_rate < 1 THEN 'económica'
           WHEN rental_rate BETWEEN 1 AND 3 THEN 'media'
           ELSE 'premium'
       END AS categoria_precio
FROM public.film;
```

---

## 10. Vistas (VIEW)

Una vista guarda una consulta con un nombre, como si fuera una tabla virtual. No almacena datos propios: cada vez que se consulta, vuelve a ejecutar el `SELECT` de base.

```sql
CREATE VIEW vista_clientes_totales AS
SELECT c.customer_id, c.first_name, SUM(p.amount) AS total_pagado
FROM public.customer c
JOIN public.payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name;

SELECT * FROM vista_clientes_totales WHERE total_pagado > 100;
```

---

## 11. Transacciones y ACID

Una transacción agrupa varias operaciones para que se ejecuten todas o ninguna.

- **Atomicidad**: todo o nada.
- **Consistencia**: la base pasa de un estado válido a otro.
- **Aislamiento**: las transacciones no se interfieren entre sí.
- **Durabilidad**: lo confirmado (`COMMIT`) persiste aunque haya una falla.

```sql
BEGIN;
UPDATE employees.salary SET amount = amount * 1.1 WHERE employee_id = 10001;
-- si algo sale mal:
ROLLBACK;
-- si todo está bien:
COMMIT;
```

---

## 12. Índices

### 12.1 Tipos principales en PostgreSQL
| Tipo | Uso típico |
|---|---|
| B-tree (por defecto) | Igualdad y rangos (`=`, `<`, `>`, `BETWEEN`, `ORDER BY`) |
| Hash | Solo igualdad (`=`), poco usado en la práctica |
| GIN | Datos tipo array, JSONB, búsqueda de texto completo |
| GiST | Datos geométricos, rangos |

### 12.2 Índice simple vs compuesto
```sql
-- Simple: sirve cuando se filtra SOLO por esa columna
CREATE INDEX idx_employee_last_name ON employees.employee (last_name);

-- Compuesto: sirve cuando se filtran esas columnas JUNTAS (el orden importa)
CREATE INDEX idx_salary_employee_todate ON employees.salary (employee_id, to_date);

-- Único: además de indexar, impide valores duplicados
CREATE UNIQUE INDEX idx_email_unico ON public.customer (email);
```

### 12.3 Costos y cuándo NO conviene un índice
- Ocupa espacio en disco.
- Ralentiza un poco `INSERT`/`UPDATE`/`DELETE` porque el índice también se actualiza.
- En tablas pequeñas o cuando el filtro devuelve casi todas las filas, PostgreSQL puede preferir `Seq Scan` igual, porque leer secuencial es más eficiente que saltar entre páginas del índice.

---

## 13. EXPLAIN y EXPLAIN ANALYZE en detalle

- `EXPLAIN`: plan **estimado**, no ejecuta la consulta.
- `EXPLAIN ANALYZE`: **ejecuta** la consulta y agrega tiempos y filas reales.
- `EXPLAIN (ANALYZE, BUFFERS)`: además muestra el uso de memoria/disco (páginas leídas de caché vs de disco).

| Elemento del plan | Significado |
|---|---|
| `Seq Scan` | Recorre toda la tabla |
| `Index Scan` | Usa el índice para ir directo a las filas |
| `Bitmap Heap Scan` / `Bitmap Index Scan` | Usa el índice para armar un mapa de páginas a leer |
| `Nested Loop` | Estrategia de JOIN: por cada fila de una tabla, busca en la otra |
| `Hash Join` | Estrategia de JOIN: arma una tabla hash de una de las tablas |
| `Merge Join` | Estrategia de JOIN: ambas tablas ya vienen ordenadas por la clave |
| `cost=inicio..fin` | Costo estimado (unidad arbitraria) |
| `rows` | Filas estimadas por el planificador |
| `actual time=inicio..fin` | Tiempo real (ms) de ese paso |
| `Execution Time` | Tiempo total real de la consulta completa |

Al comparar "antes/después" de un índice se busca: cambio de `Seq Scan` a `Index Scan`, y una baja en `Execution Time`.

---

## 14. Mantenimiento: VACUUM y ANALYZE

- `VACUUM`: libera espacio de filas eliminadas o actualizadas que ya no se usan.
- `ANALYZE`: actualiza las estadísticas internas (cuántos valores distintos hay, distribución de datos) que usa el planificador para decidir si usar un índice o no.
- `VACUUM ANALYZE`: hace ambas cosas.

```sql
VACUUM ANALYZE public.film;
```
Si las estadísticas están desactualizadas, el planificador puede elegir un plan poco óptimo aunque exista un índice adecuado.

---

## 15. Ejercicios resueltos — Fase A: DVD Rental

**Tablas clave:** `film`, `customer`, `rental`, `payment`, `category`, `film_category`, `language`.

1. Listar películas con filtros → clasificación + tarifa.
2. Contar películas por clasificación.
3. Relacionar clientes con alquileres.
4. Calcular total pagado por cliente.
5. Consulta con 3+ JOIN (film, language, category).
6. `EXPLAIN ANALYZE` antes/después de crear un índice sobre `customer.last_name`.

*(código completo en `ejercicios_examen.sql`, sección 15)*

---

## 16. Ejercicios resueltos — Fase B: LEGO

**Tablas clave:** `lego_sets`, `lego_themes`.

1. Años con más sets lanzados.
2. Sets con mayor número de piezas.
3. Relacionar sets con temas.
4. Estadísticas por tema (cantidad, promedio, min, max de piezas).
5. Consulta con CTE: años sobre el promedio histórico de sets.
6. `EXPLAIN ANALYZE` antes/después de indexar `lego_sets.theme_id`.

*(código completo en `ejercicios_examen.sql`, sección 16)*

---

## 17. Ejercicios resueltos — Fase C: Employees

**Esquema:** `employees` (no `public`). Tablas: `employee`, `department`, `department_employee`, `salary`, `title`. Convención: `to_date = '9999-01-01'` = registro vigente.

1. Medir el volumen de las tablas (`pg_stat_user_tables`).
2. Inspeccionar índices existentes (`pg_indexes`).
3. Buscar por una columna no indexada (`last_name`).
4. Crear índice simple y comparar el plan.
5. Crear índice compuesto (`employee_id, to_date`) y justificarlo.
6. `EXPLAIN ANALYZE` de un JOIN grande (empleado + departamento + cargo + salario).
7. Documentar evidencia antes/después y conclusión técnica.

*(código completo en `ejercicios_examen.sql`, sección 17)*

---

## 18. Práctica extra (variantes típicas de examen)

1. LEFT JOIN — clientes sin alquileres.
2. Subconsulta correlacionada — salario por encima del promedio del propio departamento.
3. CTE con JOIN — sets de un tema específico ordenados por piezas.
4. Índice para ORDER BY — acelerar un top-N.
5. GROUP BY + HAVING — temas con más de 50 sets.
6. DISTINCT — idiomas distintos con películas.
7. Window function — ranking de películas por tarifa dentro de cada clasificación.
8. UNION — nombres combinados de clientes y empleados.
9. CASE WHEN — categorizar películas por rango de precio.
10. Vista — vista reutilizable de clientes con su total pagado.
11. Transacción — actualizar un salario con posibilidad de revertir.

*(código completo en `ejercicios_examen.sql`, sección 18)*

---

## 19. Chuleta rápida final

- Orden de ejecución real: `FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`.
- `WHERE` filtra filas; `HAVING` filtra grupos.
- `INNER JOIN` descarta lo que no coincide; `LEFT/RIGHT/FULL JOIN` lo conservan con `NULL`.
- Índice simple → filtro por una columna. Índice compuesto → filtro por varias columnas juntas (importa el orden).
- `EXPLAIN` = estimado (no ejecuta). `EXPLAIN ANALYZE` = real (sí ejecuta).
- `Seq Scan` = recorre todo. `Index Scan`/`Bitmap Heap Scan` = usa el índice.
- Un índice no siempre mejora el rendimiento: en tablas chicas o filtros poco selectivos, PostgreSQL puede seguir prefiriendo `Seq Scan`.
- CTE (`WITH`) ordena consultas complejas en pasos con nombre.
- Window functions agregan una columna calculada sin perder el detalle de cada fila (a diferencia de `GROUP BY`).
- ACID: Atomicidad, Consistencia, Aislamiento, Durabilidad.
- `VACUUM` libera espacio; `ANALYZE` actualiza estadísticas para que el planificador elija bien.
