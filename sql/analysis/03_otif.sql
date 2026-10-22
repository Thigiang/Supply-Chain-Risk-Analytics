-- OTIF: On Time In Full
-- OTIF happens when an order arrives on-time with all items and the full quantity (nothing missing or canceled)
-- OTIF % = orders that are BOTH on time AND in full / all orders excluding suspected fraud x 100
-- Level: per order (one row per order_id)
-- on-time = days_for_shipping_real <= days_for_shipment_scheduled
-- In full: since there is no quantity order nor quantity shipment, no order is partially canceled,
-- and all items in an order share the same status, so cancellation is the only measureable "not in full" outcome
-- If an order is not canceled = in full
-- In the exploration, suspected fraud orders had shipping canceled status. we will exclude suspected fraud orders
-- from this analysis as blocking a fraudulent order is the correct action, not a delivery failure.
-- Unlike the exploration, OTIF counts customer cancellation (CANCELED) as a failure.

-- Overall OTIF
-- on_time: MAX(days_for_shipping_real <= days_for_shipment_scheduled)
-- in_full: MAX(delivery_status <> 'Shipping canceled')
-- denominator condition: WHERE order_status <> 'SUSPECTED_FRAUD'

 
-- Findings:
-- Overall OTIF is 41.78% (n = 64,264 orders, suspected fraud excluded):
--   fewer than half of orders arrive both on time and in full.
-- On Time is the weak component (42.68%); In Full is high (97.87%).
-- Of the 37,415 orders that fail OTIF, 36,048 (96.3%) fail because they were late
--   and only 1,367 (3.7%) because they were canceled.
--   → Improving OTIF means fixing lateness, not cancellations.

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

WITH orders AS (
    SELECT order_id,
        MAX(days_for_shipping_real <= days_for_shipment_scheduled) AS on_time,
        MAX(delivery_status <> 'Shipping canceled') AS in_full
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY order_id
)
SELECT COUNT(*) AS n_orders,
    SUM(on_time) AS n_on_time, -- include 579 canceled orders (day columns only)
    SUM(NOT on_time AND in_full) AS n_late, -- order shipped late (not include canceled order)
    SUM(in_full) AS n_in_full,
    SUM(NOT in_full) AS n_canceled,
    SUM(on_time AND in_full) AS n_otif,
    SUM(NOT (on_time AND in_full)) AS n_failed_otif
FROM orders;

-- OTIF by shipping mode, market/region and department
-- 1. shipping by mode
    -- Finding: 
        -- OTIF percentage: Standard Class (58.89%) > Same Day (50.43%) > Second Class (19.61%) > First Class (0.00%). It is consistent with exploration findings.
        -- First class OTIF is exactly 0%: no order can ever be OTIF because it can never be on time ( 1 day promised but 2 days delivery)
        -- In Full is flat across modes (97.68% - 97.95%) which implies cancellations don't depend on shipping mode. So the whole OTIF differences between modes comes from On Time.
        -- The premium modes perform worst: second and first class together are 22,338 orders (about 1/3 of total orders) with OTIF less than 20%
WITH orders AS(
    SELECT order_id, shipping_mode,
        MAX(days_for_shipping_real <= days_for_shipment_scheduled) AS on_time,
        MAX(delivery_status <> 'Shipping canceled') AS in_full
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY order_id, shipping_mode
)
SELECT shipping_mode, COUNT(*) AS n_orders,
    ROUND(100.0 * AVG(on_time), 2) AS on_time_pct,
    ROUND(100.0 * AVG(in_full), 2) AS in_full_pct,
    SUM(NOT in_full) AS n_canceled,
    ROUND(100.0 * AVG(on_time AND in_full), 2) AS otif_pct
FROM orders
GROUP BY shipping_mode
ORDER BY otif_pct DESC;

-- 2. Market, region and department
-- Findings:
--   Market:     OTIF 41.45% (Pacific Asia) to 42.54% (Africa), ~1.1-point spread, every market has 3,768+ orders → no effect.
--   Region:     OTIF 39.08% (Central Africa) to 46.31% (Canada), but both extremes are small
--               (n = 545 and 298 orders, wobble ≈ ±4.3 and ±5.8 pts) and within chance of the 41.78% overall → no real effect.
--   Department: measured per item (41,471 orders mix departments, so per-order counts would overlap).
--               OTIF 37.84% (Pet Shop) to 42.27% (Discs Shop). Pet Shop has only 481 items (wobble ≈ ±4.6 pts),
--               and the four largest departments (Fan Shop, Apparel, Footwear, Golf) are all 41.78%–41.93% → no effect.
--   In Full is flat everywhere (97.19%–99.24%).
--   Conclusion: of the dimensions in this dataset, shipping mode is the only one that changes OTIF (0.00%–58.89%), market, region and department do not.
--   Checks: market and region n_orders sum to 64,264 and n_canceled to 1,367; department n_items sum to 176,457 with 3,692 canceled items.

-- 2a. Market
WITH orders AS(
    SELECT order_id, market,
        MAX(days_for_shipping_real <= days_for_shipment_scheduled) AS on_time,
        MAX(delivery_status <> 'Shipping canceled') AS in_full
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY order_id, market
)
SELECT market, COUNT(*) AS n_orders,
    ROUND(100.0 * AVG(on_time), 2) AS on_time_pct,
    ROUND(100.0 * AVG(in_full), 2) AS in_full_pct,
    SUM(NOT in_full) AS n_canceled,
    ROUND(100.0 * AVG(on_time AND in_full), 2) AS otif_pct
FROM orders
GROUP BY market
ORDER BY otif_pct DESC;

-- 2b. Region
WITH orders AS(
    SELECT order_id, order_region,
        MAX(days_for_shipping_real <= days_for_shipment_scheduled) AS on_time,
        MAX(delivery_status <> 'Shipping canceled') AS in_full
    FROM supply_chain
    WHERE order_status <> 'SUSPECTED_FRAUD'
    GROUP BY order_id, order_region
)
SELECT order_region, COUNT(*) AS n_orders,
    ROUND(100.0 * AVG(on_time), 2) AS on_time_pct,
    ROUND(100.0 * AVG(in_full), 2) AS in_full_pct,
    SUM(NOT in_full) AS n_canceled,
    ROUND(100.0 * AVG(on_time AND in_full), 2) AS otif_pct
FROM orders
GROUP BY order_region
ORDER BY otif_pct DESC;

-- 2c. Department
-- check: orders that contain items from more than one department (result: 41,471)
SELECT COUNT(*) AS orders_with_multiple_departments
FROM (
    SELECT order_id
    FROM supply_chain
    GROUP BY order_id
    HAVING COUNT(DISTINCT department_name) > 1
);

-- per item: each item belongs to exactly one department, so no order is counted twice
SELECT department_name, COUNT(*) AS n_items,
    ROUND(100.0 * AVG(days_for_shipping_real <= days_for_shipment_scheduled), 2) AS on_time_pct,
    ROUND(100.0 * AVG(delivery_status <> 'Shipping canceled'), 2) AS in_full_pct,
    SUM(delivery_status = 'Shipping canceled') AS n_canceled,
    ROUND(100.0 * AVG(days_for_shipping_real <= days_for_shipment_scheduled
                      AND delivery_status <> 'Shipping canceled'), 2) AS otif_pct
FROM supply_chain
WHERE order_status <> 'SUSPECTED_FRAUD'
GROUP BY department_name
ORDER BY otif_pct DESC;




