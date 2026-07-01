-- 03_funnel_conversion_rates.sql
-- Step-to-step and overall conversion rates for the purchase funnel.
-- Builds on the session flags from 02 and computes the ratios between stages.

WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
),

sessions AS (
  SELECT
    user_pseudo_id,
    session_id,
    MAX(IF(event_name = 'view_item',      1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart',    1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
    MAX(IF(event_name = 'purchase',       1, 0)) AS purchased
  FROM events
  GROUP BY user_pseudo_id, session_id
)

SELECT
  SUM(viewed_item)    AS view_item,
  SUM(added_to_cart)  AS add_to_cart,
  SUM(began_checkout) AS begin_checkout,
  SUM(purchased)      AS purchase,
  -- step-to-step conversion
  ROUND(SUM(added_to_cart)  / NULLIF(SUM(viewed_item),   0) * 100, 2) AS view_to_cart_pct,
  ROUND(SUM(began_checkout) / NULLIF(SUM(added_to_cart), 0) * 100, 2) AS cart_to_checkout_pct,
  ROUND(SUM(purchased)      / NULLIF(SUM(began_checkout),0) * 100, 2) AS checkout_to_purchase_pct,
  -- overall view_item -> purchase
  ROUND(SUM(purchased)      / NULLIF(SUM(viewed_item),   0) * 100, 2) AS overall_conversion_pct
FROM sessions;
