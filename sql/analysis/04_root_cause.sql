-- Level: per item
-- We want to find where the late shipments concentrate
-- Rules: 
    -- In this analysis, we will exclude 'shipping canceled' status as we only check lateness for shipped items.
    -- late item: late_delivery_risk = 1
    -- Confirm that late_delivery_risk = 1 is same as real > schedule:

-- Check: late_delivery_risk = 1 exactly when real > scheduled (expect 0 mismatches)
SELECT COUNT(*) AS n_items,
    SUM(late_delivery_risk <> (days_for_shipping_real > days_for_shipment_scheduled)) AS mismatches
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled';


-- 1. We will check late rate and volume by shipping mode
-- Finding:
    -- Highest late rate ≠ most late items.
    -- Standard Class has the lowest late rate (39.77%) but the most late items (41,023 = 41.45% of all late items)
    -- because it carries the most volume (103,153 items).
    -- First Class is 100% late but only 26.79% of all late items. Second Class: 79.83% late, 27.27% of late items.
    -- First + Second Class = 54.06% of all late items → fixing their promised days removes over half of late shipments.
    -- Standard Class is the biggest single source of late items → worth checking its 2–6 day spread

SELECT shipping_mode,
    COUNT(*) as n,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct,
    SUM(late_delivery_risk) AS n_late,
    ROUND(100.0 * SUM(late_delivery_risk) / SUM(SUM(late_delivery_risk)) OVER(), 2) AS share_of_late_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY shipping_mode
ORDER BY n_late DESC;

-- 2. Shipping mode and market: is there an interaction between shipping mode and market?
    -- Is the mode's problem the same in all markets or worse in particular markets?
    -- Finding:
    -- Each mode has about the same late rate in every market → no interaction between mode and market.
    -- First Class:    100% in all 5 markets
    -- Second Class:   79.07% (LATAM) to 80.38% (Pacific Asia), overall 79.83%
    -- Standard Class: 39.55% (LATAM) to 40.03% (Pacific Asia), overall 39.77%
    -- Same Day:       45.39% (Pacific Asia, n = 2,135) to 50.36% (LATAM, n = 2,528), overall 47.93%
    --                 → the only mode with some spread, but each end is only ~2.5 points from overall,
    --                   close to its wobble (±2.2 and ±2.0), so this is weak evidence.
    -- Most late items are in Europe, LATAM and Pacific Asia only because they are the biggest markets:
    --   share_of_mode_late ≈ share_of_mode_items in every row (e.g. Standard Class Europe 27.56% vs 27.56%).
    --   The biggest gap is Same Day LATAM (27.20% of items vs 28.58% of late items, ~1.4 points).
    -- Conclusion: market is not a root cause. Late items follow volume; of the dimensions in this data, only shipping mode explains lateness.
 
SELECT shipping_mode, market,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct,
    SUM(late_delivery_risk) AS n_late,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY shipping_mode), 2) AS share_of_mode_items,
    ROUND(100.0 * SUM(late_delivery_risk) / SUM(SUM(late_delivery_risk)) OVER (PARTITION BY shipping_mode), 2) AS share_of_mode_late
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY shipping_mode, market
ORDER BY shipping_mode, late_rate_pct DESC;

-- 3. Shipping mode x region x department
    -- Compare each group with its own mode using diff
    -- diff = this group's late rate - its mode's late rate
        -- diff = 0 or close to 0: the group behaves like its mode
        -- diff >> 0: the group is worse than its mode, a possible root cause
        -- diff << 0: the group is better than its mode
    -- Only groups with n >= 500 are compared (wobble = 100/sqrt(n) <= ~4.5 points).
    -- The mode rate is calculated over ALL groups in the CTE, the n >= 500 filter is applied after.
    -- Finding:
        -- Largest gap: Standard Class / North Africa / Fan Shop, -6.48 points (n = 709), i.e. BETTER than its mode.
        -- Only 4 of 85 groups are beyond their wobble, about what luck alone predicts (1 in 20 → ~4).
            --   3 are better than their mode, only 1 is worse:
                --   Standard Class / East of USA / Apparel, +3.27 vs wobble ±3.1 (n = 1,041) → barely beyond, weak evidence.
        -- First Class is 100% late in every group, so its diff is always 0.
        -- Conclusion: no combination of region and department makes a mode worse.

WITH combos AS(
    SELECT shipping_mode, order_region, department_name,
        COUNT(*) AS n,
        SUM(late_delivery_risk) AS n_late,
        100.0 * AVG(late_delivery_risk) AS late_rate_pct,
        100.0 * SUM(SUM(late_delivery_risk)) OVER (PARTITION BY shipping_mode) / SUM(COUNT(*)) OVER (PARTITION BY shipping_mode) AS mode_rate_pct
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
    GROUP BY shipping_mode, order_region, department_name
)
SELECT shipping_mode, order_region, department_name, n, n_late,
    ROUND(late_rate_pct, 2) AS late_rate_pct,
    ROUND(mode_rate_pct, 2) AS mode_rate_pct,
    ROUND(late_rate_pct - mode_rate_pct, 2) AS diff,
    ROUND(100 / SQRT(n), 1) AS wobble
FROM combos
WHERE n >= 500
ORDER BY ABS(diff) DESC;

-- Check: how many groups (n >= 500) are beyond their wobble?
WITH combos AS (
    SELECT shipping_mode, order_region, department_name,
        COUNT(*) AS n,
        100.0 * AVG(late_delivery_risk) AS late_rate_pct,
        100.0 * SUM(SUM(late_delivery_risk)) OVER (PARTITION BY shipping_mode) / SUM(COUNT(*)) OVER (PARTITION BY shipping_mode) AS mode_rate_pct
    FROM supply_chain
    WHERE delivery_status <> 'Shipping canceled'
    GROUP BY shipping_mode, order_region, department_name
)
SELECT COUNT(*) AS total_groups,
    SUM(n >= 500) AS groups_500,
    SUM(CASE WHEN n >= 500 THEN n END) AS items_in_groups_500,
    SUM(n >= 500 AND ABS(late_rate_pct - mode_rate_pct) > 100 / SQRT(n)) AS beyond_wobble,
    SUM(n >= 500 AND late_rate_pct - mode_rate_pct > 100 / SQRT(n)) AS worse_than_mode,
    SUM(n >= 500 AND mode_rate_pct - late_rate_pct > 100 / SQRT(n)) AS better_than_mode
FROM combos;

-- Up until now: Root cause of lateness = shipping mode (promise vs actual days), nothing else in this dataset.

