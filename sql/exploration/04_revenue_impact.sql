-- Now we know how often and why orders are late. We will look into revenue and profit between late and on time group
-- Check some data from the table to see which columns should be used to calculate the lateness cost. We will look into order_id = 5
-- Finding: the sales amount is before discount. The real revenue is after discount, so we will use order_item_total which is the sales after discount
-- The last column order_profit_per_order in this table display the profits of the order. If this were order-level profit, every row of order 5 would show the same value.
-- Instead each item has a different value, so it is actually per-item profit and SUM is correct

SELECT order_id, order_item_id, sales, order_item_discount, order_item_total, order_profit_per_order
FROM supply_chain
WHERE order_id = 5;

-- Let's look at the revenue and profit for late vs on-time items
-- Finding: About 57% of total revenue ($18.1M) went through late deliveries.
-- Late and on-time items have nearly the same profit margin (11.83% vs. 12.29%)
-- but refunds and lost customers are not recorded in this data, so we can't measure the real cost of lateness
-- in this dataset.

SELECT late_delivery_risk,
    CASE WHEN late_delivery_risk = 1 THEN 'Late' ELSE 'On time' END AS delivery,
    COUNT(*) AS n,
    ROUND(SUM(order_item_total), 0) AS revenue,
    ROUND(100.0 * SUM(order_item_total)/SUM(SUM(order_item_total)) OVER(), 2) as share_of_total_revenue,
    ROUND(SUM(order_profit_per_order), 0) AS profit,
    ROUND(100.0*SUM(order_profit_per_order)/SUM(order_item_total), 2) AS profit_margin
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY late_delivery_risk;
