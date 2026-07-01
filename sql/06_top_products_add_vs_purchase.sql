-- 06_top_products_add_vs_purchase.sql
-- Cart abandonment by product: which items are added to cart most, and how
-- often those adds convert to a purchase. Low add-to-purchase % = friction.
-- Technique: UNNEST the items array so each product line becomes its own row.

WITH item_events AS (
  SELECT
    event_name,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
       UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('add_to_cart', 'purchase')
    AND item.item_name IS NOT NULL
)

SELECT
  item_name,
  COUNTIF(event_name = 'add_to_cart') AS times_added,
  COUNTIF(event_name = 'purchase')    AS times_purchased,
  ROUND(COUNTIF(event_name = 'purchase') / NULLIF(COUNTIF(event_name = 'add_to_cart'), 0) * 100, 2) AS add_to_purchase_pct
FROM item_events
GROUP BY item_name
HAVING times_added >= 50
ORDER BY times_added DESC
LIMIT 20;
