WITH metrics AS (
    SELECT department_name,
        COUNT(*) AS n,
        AVG(CASE WHEN delivery_status <> 'Shipping canceled' THEN late_delivery_risk END) AS delay_freq,
        AVG(CASE WHEN delivery_status <> 'Shipping canceled' THEN days_for_shipping_real * days_for_shipping_real END)
        - AVG(CASE WHEN delivery_status <> 'Shipping canceled' THEN days_for_shipping_real END)
        * AVG(CASE WHEN delivery_status <> 'Shipping canceled' THEN days_for_shipping_real END) AS lead_time_var,
        AVG( order_status = 'CANCELED' ) AS cancel_rate
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY department_name
    HAVING COUNT(*) >= 500
),
normalized AS (
    SELECT *,
        (delay_freq - MIN(delay_freq) OVER()) / (MAX(delay_freq) OVER() - MIN(delay_freq) OVER()) AS delay_norm,
        (lead_time_var - MIN(lead_time_var) OVER()) / (MAX(lead_time_var) OVER() - MIN(lead_time_var) OVER()) AS var_norm,
        (cancel_rate - MIN(cancel_rate) OVER()) / (MAX(cancel_rate) OVER() - MIN(cancel_rate) OVER()) AS cancel_norm
    FROM metrics
),
scored AS (
    SELECT *,
        0.5 * delay_norm + 0.3 * var_norm + 0.2 * cancel_norm AS risk_score
    FROM normalized
)
SELECT department_name, n,
    ROUND(100.0 * delay_freq, 2) AS delay_pct,
    ROUND(lead_time_var, 3) AS lead_time_var,
    ROUND(100.0 * cancel_rate, 2) AS cancel_rate_pct,
    ROUND(risk_score, 3) AS risk_score,
    RANK() OVER (ORDER BY risk_score DESC) AS risk_rank
FROM scored
ORDER BY risk_rank;
