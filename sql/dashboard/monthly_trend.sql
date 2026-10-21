SELECT strftime('%Y-%m', order_date_dateorders) AS order_month,
    COUNT(*) AS n_items,
    COUNT(DISTINCT order_id) AS n_orders,
    ROUND(AVG(days_for_shipping_real), 2) AS avg_cycle_days,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY order_month
ORDER BY order_month;