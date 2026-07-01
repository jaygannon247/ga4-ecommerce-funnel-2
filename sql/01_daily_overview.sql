-- 01_daily_overview.sql
-- Warm-up: daily active users and core e-commerce event volumes.
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce (Google Merchandise Store)
-- Window:  2020-11-01 to 2021-01-31 (full range of the public sample)

SELECT
  PARSE_DATE('%Y%m%d', event_date)        AS date,
  COUNT(DISTINCT user_pseudo_id)          AS active_users,
  COUNTIF(event_name = 'view_item')       AS view_item,
  COUNTIF(event_name = 'add_to_cart')     AS add_to_cart,
  COUNTIF(event_name = 'begin_checkout')  AS begin_checkout,
  COUNTIF(event_name = 'purchase')        AS purchase
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY date
ORDER BY date;
