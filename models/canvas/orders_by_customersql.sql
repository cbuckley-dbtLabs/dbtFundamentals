WITH stg_jaffle_shop__customers AS (
  SELECT
    *
  FROM {{ ref('stg_jaffle_shop__customers') }}
), stg_jaffle_shop__orders AS (
  SELECT
    *
  FROM {{ ref('stg_jaffle_shop__orders') }}
), stg_stripe__payments AS (
  SELECT
    *
  FROM {{ ref('stg_stripe__payments') }}
), join_1 AS (
  SELECT
    *
  FROM stg_jaffle_shop__orders
  JOIN stg_stripe__payments
    USING (ORDER_ID)
), join_2 AS (
  SELECT
    *
  FROM join_1
  JOIN stg_jaffle_shop__customers
    USING (CUSTOMER_ID)
), aggregate_1 AS (
  SELECT
    FIRST_NAME,
    LAST_NAME,
    MAX(AMOUNT) AS MAX_AMOUNT,
    AVG(AMOUNT) AS AVG_AMOUNT,
    MIN(CREATED_AT) AS FIRST_ORDER,
    COUNT(CREATED_AT) AS COUNT_CREATED_AT
  FROM join_2
  GROUP BY
    FIRST_NAME,
    LAST_NAME
), order_1 AS (
  SELECT
    *
  FROM aggregate_1
  ORDER BY
    AVG_AMOUNT DESC
  LIMIT 100
), orders_by_customersql_sql AS (
  SELECT
    *
  FROM order_1
)
SELECT
  *
FROM orders_by_customersql_sql