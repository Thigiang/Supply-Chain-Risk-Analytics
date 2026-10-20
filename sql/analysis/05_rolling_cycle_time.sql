-- Monthly trend: does lateness or cycle time change over time?
-- Level: per item, grouped by order month
-- Rules:
    -- exclude 'Shipping canceled' (never shipped, also removes suspected fraud)
    -- cycle time = days_for_shipping_real (calendar days from order date to shipping date, 0-6)
    -- daily rolling averages were skipped: monthly values are already flat, so a rolling line adds nothing
-- Finding:
    -- No trend over time (2015-01 to 2018-01, 37 months):
    --   avg cycle time stays between 3.44 and 3.59 days every month
    --   late rate stays between 55.17% (2016-07) and 59.31% (2016-06), around the 57.3% baseline
    --   → lateness is structural (shipping mode promises), not seasonal and not getting better or worse.
    -- Data break from 2017-10: items per month drop from ~4,500-5,200 to ~2,000,
    --   while orders per month stay similar (1,505-1,731 before, 1,956-2,037 after),
    --   so orders become ~1 item each (2017-11 to 2018-01: n_items = n_orders exactly).
    --   → a change in how the data was recorded, not a business change. Note it as a README limitation.

SELECT strftime('%Y-%m', order_date_dateorders) AS order_month,
    COUNT(*) AS n_items,
    COUNT(DISTINCT order_id) AS n_orders,
    ROUND(AVG(days_for_shipping_real), 2) AS avg_cycle_days,
    ROUND(100.0 * AVG(late_delivery_risk), 2) AS late_rate_pct
FROM supply_chain
WHERE delivery_status <> 'Shipping canceled'
GROUP BY order_month
ORDER BY order_month;
