-- Next we will look into promise vs actual delivery days to see if the promised days for some class
-- might be unrealistic

SELECT days_for_shipment_scheduled AS days_promised,
    days_for_shipping_real AS days_taken,
    -- delay in days: > 0 late, 0 on time, < 0 early
    days_for_shipping_real - days_for_shipment_scheduled AS delay
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
LIMIT 20;

-- check by group (shipping_mode)
-- Finding: promised vs actual delivery days by shipping mode (canceled excluded)
-- First Class:    promise always 1 day, actual always 2 days
--                 → can never be on time → 100% late
-- Second Class:   promise always 2 days, actual 2–6 days (avg 3.99)
--                 → late whenever delivery takes 3+ days → ~80% late (79.83%)
-- Same Day:       promise 0 days, actual 0–1 day (avg 0.48)
--                 → late whenever delivery slips to the next day → ~48% late (47.93%)
-- Standard Class: promise always 4 days, actual 2–6 days spread evenly (~20% at each day, avg 3.99)
--                 → avg delay ≈ 0, BUT deliveries on day 5 and 6 are late → ~40% late (39.77%)
--                 → an average delay of 0 hides the spread: early and late deliveries cancel out
--
-- Key comparison: Second Class and Standard Class have the SAME actual delivery time
--   (both avg 3.99 days, both 2–6 days). The only difference is the promise (2 vs 4 days).
--   → Paying for Second Class does not get the order there faster, it only gets a stricter promise.
--
-- Conclusion: late deliveries are caused by overpromising, not by slow shipping.
--   The premium modes (First, Second Class) promise speeds the operation does not deliver.
--   Business implication: either fix the promised days to match reality,
--   or improve the actual speed of premium modes.

SELECT shipping_mode,
    ROUND(AVG(days_for_shipment_scheduled), 2) AS avg_days_promised,
    ROUND(AVG(days_for_shipping_real), 2) AS avg_days_taken,
    -- average delay in days (can hide spread, see min/max)
    ROUND(AVG(days_for_shipping_real - days_for_shipment_scheduled), 2) AS avg_delay,
    MIN(days_for_shipping_real) AS min_real,
    MAX(days_for_shipping_real) AS max_real,
    MIN(days_for_shipment_scheduled) AS min_promise,
    MAX(days_for_shipment_scheduled) AS max_promise,
    COUNT(DISTINCT days_for_shipment_scheduled)  AS n_distinct_promises
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY shipping_mode
ORDER BY avg_delay DESC;
