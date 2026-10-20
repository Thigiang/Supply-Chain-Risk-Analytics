-- Goal: give every shipped item a risk label (High, Medium, Low) based on how late it was, and see how many fall in each group
-- This works at the shipment level, which will help the operations team
-- Rules:
    -- Level: per item
    -- Exclude canceled items (including fraud)
    -- delay = days_for_shiping_real - days_for_shipment_scheduled
        -- delay > 0: late
        -- delay = 0: on time
        -- delay < - : early

-- 1. Delay distribution 

-- Finding of the delay distribution (172,765 shipped items):
    -- Delay ranges from -2 to 4: shipments arrived from 2 days early to 4 days late
    -- 24.07% were early (12.08% 2 days early, 11.99% 1 day early)
    -- 18.64% were on time
    -- 33.55% were 1 day late, the most common outcome
    -- 15.95% were 2 days late
    -- 7.80% were 3 or more days late (3.92% 3 days, 3.88% 4 days)
    -- Total late (delay > 0) = 57.30%, matching the 57.3% late rate from exploration
WITH orders AS(
    SELECT *,
    days_for_shipping_real - days_for_shipment_scheduled AS delay
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
)
SELECT delay,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY delay
ORDER BY delay;

-- 2. Give each shipment a risk label: High, Medium or Low
    -- Threshold:
        -- High: delay >= 3 days (severe, rare ~ 7.80%)
        -- Medium: 1-2 days (late, but moderately ~ 49.49%)
        -- Low: <= 0 (on time or early ~ 42.71%)
    -- Finding:
        -- Medium 49.49% (85,508), Low 42.71% (73,788), High 7.80% (13,469) of 172,765 shipped items
        -- About half of all shipments are moderately late, and 1 in 13 is severely late (3+ days)
        -- Consistent with earlier findings: Medium + High = 98,977 late shipments (57.3%), Low = 73,788 on time or early shipments
WITH orders AS(
    SELECT *,
    days_for_shipping_real - days_for_shipment_scheduled AS delay
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
)
SELECT 
    CASE
        WHEN delay >= 3 THEN 'High'
        WHEN delay >= 1 THEN 'Medium'
        ELSE 'Low'
    END AS risk_label,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct
FROM orders
GROUP BY risk_label
ORDER BY n DESC;

-- 3. Analyze risk labels by shipping mode to see where each risk level comes from
    -- Finding:
        -- High risk comes ONLY from Second Class: all 13,469 High shipments, 39.84% of Second Class
            --   (2-day promise, actual 2–6 days → 3–4 days late is common)
        -- First Class: 100% Medium. Every shipment is exactly 1 day late, never on time, never High
        -- Standard Class and Same Day are never High: Standard 39.77% Medium / 60.23% Low,
        --   Same Day 47.93% Medium / 52.07% Low
        -- Early warning: because risk depends only on shipping mode, it can be flagged when the order is placed:
            --   First Class → certain to be late (Medium), Second Class → ~80% late and ~40% severely late (High)
            --   Standard Class and Same Day → lower risk, never severely late
        -- Limit: within a mode, which individual shipments will be late can't be predicted from this data
        --   (root cause found no region or department effect), so the alert works per mode, not per shipment.

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
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION By shipping_mode), 2) AS pct
FROM orders
GROUP BY shipping_mode, risk_label
ORDER BY shipping_mode, risk_label DESC;
