WITH orders AS (
    SELECT order_id,
        MAX(days_for_shipping_real <= days_for_shipment_scheduled) AS on_time,
        MAX(delivery_status <> 'Shipping canceled') AS in_full
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY order_id
)
SELECT COUNT(*) AS n_orders,
    ROUND(100.0 * AVG(on_time), 2) AS on_time_pct,
    ROUND(100.0 * AVG(in_full), 2) AS in_full_pct,
    ROUND(100.0 * AVG(on_time AND in_full), 2) AS otif_pct
FROM orders;