-- WHICH GROUPS ARE LATE MORE OFTEN
-- 1. Late rate by Shipping mode
-- Shipping mode: Standard Class, First Class, Second Class, Same Day
-- check if any order has more than one mode (items in an order have different modes)
-- Finding: result is 0 which means no order has more than 1 mode

SELECT COUNT(*) AS orders_with_multiple_modes
FROM (
    SELECT order_id
    FROM supply_chain
    GROUP BY order_id
    HAVING COUNT(DISTINCT shipping_mode) > 1
);

-- Findings:
-- First Class (100%) and Second Class (79.8%) have late delivery rate over the 57.3% baseline
-- First Class late delivery rate is 100% - why? a big gap between scheduled day and real shipping day? First Class orders were scheduled with an unrealistically short promise?
--   → confirmed in 03_promise_vs_actual.sql: promise 1 day, actual always 2
-- Same Day (47.93%) and Standard Class (39.77%) have late rate less than the 57.3% baseline
-- Standard Class has the lowest rate of late delivery 39.77%
-- The premium option performs worst and the cheapest one performs best
SELECT shipping_mode,
    COUNT(*) AS n,
    ROUND(100.0*AVG(late_delivery_risk), 2) AS late_rate_pct
FROM supply_chain
WHERE delivery_status<>'Shipping canceled'
GROUP BY shipping_mode
ORDER BY late_rate_pct DESC;

-- 2. Late rate by market, region and segment
-- 2.a Market: LATAM, Africa, USCA, Pacific Asia, Europe
    -- Finding: market has no meaningful effect on the late delivery rate as the spread is 56.84% to 57.69%
SELECT market, COUNT(*) AS n,
    ROUND(100.0 * AVG(late_delivery_risk), 2) as late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY market
ORDER BY late_rate_pct DESC;

-- 2.b region
    -- Finding: late rate per regions ranging from 51.6% to 60.15%
    -- Most of the regions have late rates close to the 57.3% baseline
    -- Central Africa (~ 60 %) and Canada (~51 %) are the two most extreme regions, but their samples are small (1616 and 907) which could be by chance
    -- the differences in this group (51.6 % - 60.15 %) are very small compared to shipping mode (40% - 100%)
    -- Region barely matters

SELECT order_region,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY order_region
ORDER BY late_rate_pct DESC;

-- 2.c Segment
-- Finding: similar to market, segment has no effect on late delivery rate (57.08% - 57.59%)
-- customer type makes no difference (corporate customers don't get faster shipment than consumers)
SELECT customer_segment,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY customer_segment
ORDER BY late_rate_pct DESC;

--- So far, we can say that late delivery is driven by how an order is shipped, not where it goes or who ordered it.

-- 2.d Late rate by product category
    -- category_name: Sporting Goods, Cleats, Shop By Sport, Women's Apparel, Electronics, Boxing & MMA, Cardio Equipment, Trade-In, Kids' Golf Clubs, Hunting & Shooting, Baseball & Softball, Men's FootWear, Camping & Hiking,...
    -- Total of 50 categories


-- SELECT COUNT(DISTINCT(category_name))
-- FROM supply_chain
-- Finding: The late delivery rate swings from 49.27% (Men's Golf Clubs) to 68.85% (Golf Bags & Carts)
        -- but the sample sizes for these extreme groups are too small (Golf Bags & Carts : n = 61, Men's Golf Clubs: n = 274).
        -- The first 5 and last 5 groups have small sample sizes, so treat them with caution.
        -- Hence, adding a threshold might help us avoid making conclusions driven by chance
        -- In previous analysis, we can see the region differences are within 2-3 points, market and segment are within 1 point difference from the average late rate percentage
        -- Hence we can choose a threshold n = 500 as 100/sqrt(500) ~ 4.5 points. If we choose larger n, we will exclude more groups, if we choose smaller n, we will increase the wobble.
        -- After removing the small sample groups (27 groups were removed), we can see the spread is from 55.95% to 61.21% which shows that similar to market, region, and segment, product category barely affects the late delivery rate
SELECT category_name,
    COUNT(*) AS n,
    ROUND(100.0*AVG(late_delivery_risk), 2) as late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY category_name
ORDER BY late_rate_pct DESC;

SELECT category_name,
    COUNT(*) AS n,
    ROUND(100.0*AVG(late_delivery_risk), 2) as late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY category_name
HAVING COUNT(*) >= 500 -- adding threshold to remove small sample groups
ORDER BY late_rate_pct DESC;

-- Conclude finding: shipping mode is the only factor that affects late delivery rate
--                   and First Class at a perfect 100% is alarming
