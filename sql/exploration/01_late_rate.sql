-- WHAT IS THE LATE DELIVERY RATE?
-- calculate the late delivery rate including the shipping canceled
SELECT ROUND(100.0*AVG(late_delivery_risk), 2) as late_rate_pct
FROM supply_chain;

SELECT DISTINCT delivery_status FROM supply_chain;

--excluding canceled orders because they never got shipped
SELECT delivery_status, late_delivery_risk, COUNT(*) as n,
        ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER(), 2) as percentage
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY delivery_status, late_delivery_risk;

-- check order_id, each order has 1 or more items, it shows that each row is one item, not one order
-- Hence the above queries were calculated per item (late rate per item) not per order
SELECT order_id, COUNT(*) as item_per_order
FROM supply_chain
GROUP BY order_id
LIMIT 20;

-- calculate late rate per order
-- Finding: ~57% of shipped orders arrive late (57.29% per item, 57.31% per order, n = 62,897 orders)

With orders AS(
    SELECT order_id,
    MAX(late_delivery_risk) AS late_flag
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
    GROUP BY order_id
)
SELECT COUNT(*) AS n_orders,
    ROUND(100.0*AVG(late_flag), 2) AS late_rate_pct_orders
FROM orders;
