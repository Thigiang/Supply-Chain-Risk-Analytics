-- So far, the analysis shows that lateness is mainly caused by shipping mode: the promised days of the premium modes can't be met
-- OTIF tells how well the deliveries perform.
-- Root cause tells why they fail.
-- Next question is which supplier should business be worried about first? Who to act on first.
-- Problem: there is no supplier column in this dataset, so we will use department as a stand-in for supplier to anaylyze risk 
-- Expectation: from early analysis, deparments barely differed on lateness and OTIF, so the score may show no department stands out

-- Rules:
    -- suspected fraud excluded (same as OTIF)
    -- only departments with n >= 500 items (to deal with randomness in small sample size)
    -- delay frequency and lead-time variance: shipped items only
    -- cancellation rate: all non-fraud items (order status = 'CANCELED')



-- Finding (raw metrics, 8 departments with n >= 500):
    -- delay_freq:    56.77% (Discs Shop) to 58.00% (Fitness): ~1.2-point spread
    -- lead_time_var: 2.587 (Technology) to 2.650 (Outdoors) days² : nearly identical
    -- cancel_rate:   2.06% (Fan Shop) to 2.58% (Technology): ~0.5-point spread
    -- as expected, no department stands out on raw metrics: All three metrics are almost the same across departments
 
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
)
SELECT *  FROM metrics
ORDER BY delay_freq DESC;

-- Normalize the metrics so the metrics will be on the same 0-1 scale using min-max normalization
-- Finding (normalized):
    -- Each metric is stretched to 0 (best department) – 1 (worst department), so the metrics can be combined.
    -- But min-max always stretches the gap to the full 0–1 scale, however small the real gap is:
    --   delay: Fitness = 1.000, Discs Shop = 0.000, but the raw gap is only 1.2 points (58.00% vs 56.77%)
    --   cancel: Technology = 1.000, Fan Shop = 0.000, raw gap only 0.5 points (2.58% vs 2.06%)
    -- The 1.2-point delay gap is smaller than the wobble of either department
    --   (Discs Shop ±100/sqrt(1987) ~ ±2.2, Fitness ±100/sqrt(2425) ~ ±2.0 points: the differences are within chance.
    --   Hence, the final ranking will look decisive, but must be read together with the raw spread.

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
)
SELECT department_name, n,
    ROUND(delay_norm, 3) AS delay_norm,
    ROUND(var_norm, 3) AS var_norm,
    ROUND(cancel_norm, 3) AS cancel_norm
FROM normalized
ORDER BY delay_norm DESC;

-- Now the metrics are on the same scale, next step is to calculate the score and rank them
-- Scores will be calculated using weights:
        -- risk_score = 0.5 * delay_norm + 0.3 * var_norm + 0.2 * cancel_norm
    -- delay has 0.5 weight because lateness is what customers feel most and it's the main problem in this dataset
    -- variance has 0.3 weight because unpredictable delivery makes planning hard
    -- cancellation 0.2 because cancellations are rate (in this dataset), about 2% and it is customer's choice rather than supplier's fault.
    -- these weights can be adjusted based on one's choice

-- Finding (risk score and rank):
    -- Rank 1 Outdoors (0.809), rank 2 Fitness (0.790) ... rank 8 Discs Shop (0.169).
    -- Outdoors edges out Fitness only on variance: same late rate (both 58.00%),
    --   lead_time_var 2.650 vs 2.644 days² → var_norm 1.000 vs 0.907.
    -- The scores look far apart (0.17 to 0.81), but the raw gaps between rank 1 and rank 8 are tiny:
    --   late rate 58.00% vs 56.77% (1.2 points), lead_time_var 2.650 vs 2.610, cancel 2.08% vs 2.21%
    --   (rank 8 Discs Shop actually cancels slightly more than rank 1 Outdoors).
    -- The 1.2-point late-rate gap is within the wobble of the smaller departments (±2.0 to ±2.6 points),
    --   so the ranking reflects noise stretched by min-max, not real differences.
    -- Conclusion: no department is a meaningfully riskier "supplier". Consistent with OTIF and root cause:
    --   risk comes from shipping mode promises, so auditing departments would not fix lateness.

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
    ROUND(lead_time_var, 2) AS lead_time_var,
    ROUND(100.0 * cancel_rate, 2) AS cancel_rate_pct,
    ROUND(risk_score, 3) AS risk_score,
    RANK() OVER (ORDER BY risk_score DESC) AS risk_rank 
FROM scored
ORDER BY risk_rank;