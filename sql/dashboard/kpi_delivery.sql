SELECT
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct,
    ROUND(AVG(days_for_shipping_real - days_for_shipment_scheduled), 2) AS avg_delay_days,
    ROUND(SUM(CASE WHEN late_delivery_risk = 1 THEN order_item_total END), 0) AS late_revenue
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled';
