-- Next, we will look at suspected fraud
-- Finding: all suspected fraud orders have 'shipping canceled' delivery status
-- so when we filter delivery_status <> 'Shipping canceled', we've filtered both CANCELED and SUSPECTED_FRAUD orders

SELECT DISTINCT delivery_status
FROM supply_chain
WHERE order_status = 'SUSPECTED_FRAUD';

-- 1,367 orders have CANCELED status and 1,488 orders have SUSPECTED_FRAUD status
-- SUSPECTED_FRAUD: 1,488 orders, ~$741K (2.24% of revenue) blocked before shipping.
SELECT order_status,
    COUNT( DISTINCT order_id) AS n_orders,
    ROUND(SUM(order_item_total), 0) AS revenue,
    ROUND(100.0 * SUM(order_item_total)/SUM(SUM(order_item_total)) OVER(), 2) as share_of_total_revenue
FROM supply_chain
GROUP BY order_status
ORDER BY revenue DESC;

-- Finding: only TRANSFER payments have SUSPECTED_FRAUD status (8.14% fraud rate for TRANSFER and 0% for every other payment type)
-- 100% of suspected fraud comes from TRANSFER payments, and 8.14% of all transfers get flagged, every other payment type has 0%
-- extra verification for bank transfer payments would help with the fraud problem.
SELECT type, COUNT(*) as n,
    ROUND(100.0 * AVG(order_status = 'SUSPECTED_FRAUD'), 2) AS fraud_rate
FROM supply_chain
GROUP BY type
ORDER BY fraud_rate DESC;

-- Finding: fraud doesn't depend on market or region.
SELECT order_region, COUNT(*) as n,
    ROUND(100.0 * AVG(order_status = 'SUSPECTED_FRAUD'), 2) AS fraud_rate
FROM supply_chain
GROUP BY order_region
ORDER BY fraud_rate DESC;


SELECT market, COUNT(*) as n,
    ROUND(100.0 * AVG(order_status = 'SUSPECTED_FRAUD'), 2) AS fraud_rate
FROM supply_chain
GROUP BY market
ORDER BY fraud_rate DESC;
