-- 02_funnel_counts.sql
-- Session-level purchase funnel: how many sessions reached each stage.
-- A "session" is identified by user_pseudo_id + ga_session_id (from event_params).
-- Technique: UNNEST the event_params array to pull ga_session_id, then use
-- conditional aggregation (MAX(IF(...))) to flag which stages each session hit.

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
  SUM(purchased)      AS purchase
FROM sessions;
