-- Выбираем базу данных, где лежит таблица
USE job_sql_test;

-- 1 Новые торговые точки, которые не делали заказ до текущего месяца
WITH FirstOrders AS (
    SELECT 
        client_id,
        MIN(STR_TO_DATE(purchase_date, '%m/%d/%Y')) AS first_order_date
    FROM orders
    GROUP BY client_id
)
SELECT 
    DATE_FORMAT(first_order_date, '%Y-%m-%d') AS first_order_date, 
    client_id
FROM FirstOrders
ORDER BY first_order_date, client_id;


-- 2 Торговые точки, сделавшие заказ в прошлом месяце и в этом
WITH MonthlyOrders AS (
    SELECT 
        client_id, 
        DATE_FORMAT(STR_TO_DATE(purchase_date, '%m/%d/%Y'), '%Y-%m-%d') AS purchase_date,
        DATE_FORMAT(STR_TO_DATE(purchase_date, '%m/%d/%Y'), '%Y-%m') AS month
    FROM orders
)
SELECT distinct  
    prev_month.client_id,
    prev_month.purchase_date AS previous_order_date,
    cur_month.purchase_date AS current_order_date
FROM MonthlyOrders prev_month
JOIN MonthlyOrders cur_month
    ON prev_month.client_id = cur_month.client_id
    AND DATE_ADD(STR_TO_DATE(CONCAT(prev_month.month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH) = STR_TO_DATE(CONCAT(cur_month.month, '-01'), '%Y-%m-%d')
ORDER BY previous_order_date, current_order_date, client_id;


-- 3. Торговые точки, которые не делали заказ в прошлом месяце, но сделали в текущем
WITH MonthlyOrders AS (
    SELECT 
        client_id, 
        DATE_FORMAT(STR_TO_DATE(purchase_date, '%m/%d/%Y'), '%Y-%m-%d') AS purchase_date,
        DATE_FORMAT(STR_TO_DATE(purchase_date, '%m/%d/%Y'), '%Y-%m') AS month
    FROM orders
)
SELECT DISTINCT
    cur_month.client_id, 
    cur_month.purchase_date AS returned_date
FROM MonthlyOrders cur_month
LEFT JOIN MonthlyOrders prev_month 
    ON cur_month.client_id = prev_month.client_id
    AND DATE_ADD(STR_TO_DATE(CONCAT(prev_month.month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH) = STR_TO_DATE(CONCAT(cur_month.month, '-01'), '%Y-%m-%d')
WHERE prev_month.client_id IS NULL
AND cur_month.client_id IN (
    SELECT client_id
    FROM orders
    WHERE STR_TO_DATE(purchase_date, '%m/%d/%Y') < STR_TO_DATE(CONCAT(cur_month.month, '-01'), '%Y-%m-%d')
);


-- 4. Торговые точки, отвалившиеся в текущем месяце
WITH DailyOrders AS (
    SELECT 
        client_id, 
        STR_TO_DATE(purchase_date, '%m/%d/%Y') AS order_date
    FROM orders
),
MonthlyOrders AS (
    SELECT 
        client_id,
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        MIN(order_date) AS first_order_date_in_month
    FROM DailyOrders
    GROUP BY client_id, month
)
SELECT DISTINCT
    prev_month.client_id AS dropped_client,
    prev_month.first_order_date_in_month AS last_active_date
FROM MonthlyOrders prev_month
LEFT JOIN MonthlyOrders cur_month
    ON prev_month.client_id = cur_month.client_id
    AND DATE_ADD(LAST_DAY(STR_TO_DATE(CONCAT(prev_month.month, '-01'), '%Y-%m-%d')), INTERVAL 1 DAY) = STR_TO_DATE(CONCAT(cur_month.month, '-01'), '%Y-%m-%d')
WHERE cur_month.client_id IS NULL
ORDER BY last_active_date, dropped_client;
