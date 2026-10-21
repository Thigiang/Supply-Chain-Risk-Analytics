WITH orders AS(
    SELECT *,
    days_for_shipping_real - days_for_shipment_scheduled AS delay
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
)
SELECT shipping_mode,
    CASE
        WHEN delay >= 3 THEN 'High'
        WHEN delay >= 1 THEN 'Medium'
        ELSE 'Low'
    END AS risk_label,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY shipping_mode), 2) AS pct
FROM orders
GROUP BY shipping_mode, risk_label
ORDER BY shipping_mode,
    CASE risk_label WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;
