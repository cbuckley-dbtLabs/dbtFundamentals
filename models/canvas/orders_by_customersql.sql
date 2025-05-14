WITH stg_jaffle_shop__customers AS (
  /* Staged customer data from our jaffle shop app. */
  SELECT
    *
  FROM {{ ref('jaffle_shop', 'stg_jaffle_shop__customers') }}
), stg_jaffle_shop__orders AS (
  /* Staged order data from our jaffle shop app. */
  SELECT
    *
  FROM {{ ref('jaffle_shop', 'stg_jaffle_shop__orders') }}
), stg_payments AS (
  SELECT
    *
  FROM {{ ref('jaffle_shop', 'stg_payments') }}
), "join" AS (
  SELECT
    *
  FROM stg_jaffle_shop__orders
  JOIN stg_payments
    ON stg_jaffle_shop__orders.ORDER_ID = stg_payments.ORDER_ID
), join_2 AS (
  SELECT
    *
  FROM "join"
  JOIN stg_jaffle_shop__customers
    ON "join".CUSTOMER_ID = stg_jaffle_shop__customers.CUSTOMER_ID
), aggregate_1 AS (
  SELECT
    FIRST_NAME,
    LAST_NAME,
    MAX(AMOUNT) AS max_AMOUNT,
    AVG(AMOUNT) AS avg_AMOUNT,
    MIN(CREATED_AT) AS first_ORDER,
    COUNT(CREATED_AT) AS count_CREATED_AT
  FROM join_2
  GROUP BY
    FIRST_NAME,
    LAST_NAME
), "order" AS (
  SELECT
    *
  FROM aggregate_1
  ORDER BY
    avg_AMOUNT DESC
), orders_by_customersql AS (
  SELECT
    *
  FROM "order"
)
SELECT
  *
FROM orders_by_customersql