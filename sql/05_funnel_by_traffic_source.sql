-- 05_funnel_by_traffic_source.sql
-- Top acquisition sources by funnel volume and overall conversion.
-- Uses the user-acquisition traffic_source STRUCT (source / medium).

WITH events AS (
  SELECT
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
),

sessions AS (
  SELECT
    source,
    medium,
    user_pseudo_id,
    session_id,
    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_item,
    MAX(IF(event_name = 'purchase',  1, 0)) AS purchased
  FROM events
  GROUP BY source, medium, user_pseudo_id, session_id
)

SELECT
  source,
  medium,
  SUM(viewed_item) AS view_item_sessions,
  SUM(purchased)   AS purchase_sessions,
  ROUND(SUM(purchased) / NULLIF(SUM(viewed_item), 0) * 100, 2) AS conversion_pct
FROM sessions
GROUP BY source, medium
HAVING SUM(viewed_item) >= 100          -- ignore tiny long-tail sources
ORDER BY view_item_sessions DESC
LIMIT 15;
