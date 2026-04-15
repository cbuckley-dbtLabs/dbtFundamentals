WITH fct_orders AS (
  SELECT
    *
  FROM {{ ref('fct_orders') }}
), dim_customers AS (
  SELECT
    *
  FROM {{ ref('dim_customers') }}
), join_1 AS (
  SELECT
    *
  FROM fct_orders
  JOIN dim_customers
    ON fct_orders.O_CUSTOMER_ID = dim_customers.C_CUSTOMER_ID
), aggregate_1 AS (
  SELECT
    O_CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    MIN(ORDER_DATE) AS FIRST_ORDER_DATE,
    MAX(ORDER_DATE) AS MOST_RECENT_ORDER_DATE,
    COUNT(ORDER_ID) AS NUMBER_OF_ORDERS,
    SUM(AMOUNT) AS TOTAL_SPENT,
    SUM(GIFT_CARD_AMOUNT) AS TOTAL_GIFT_CARD_USED
  FROM join_1
  GROUP BY
    O_CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME
), rename_1 AS (
  SELECT
    O_CUSTOMER_ID AS CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    FIRST_ORDER_DATE,
    MOST_RECENT_ORDER_DATE,
    NUMBER_OF_ORDERS,
    TOTAL_SPENT,
    TOTAL_GIFT_CARD_USED
  FROM aggregate_1
), order_1 AS (
  SELECT
    *
  FROM rename_1
  ORDER BY
    TOTAL_SPENT DESC
), canvas_model_sql AS (
  SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    FIRST_ORDER_DATE,
    MOST_RECENT_ORDER_DATE,
    NUMBER_OF_ORDERS,
    TOTAL_SPENT,
    TOTAL_GIFT_CARD_USED
  FROM order_1
)
SELECT
  *
FROM canvas_model_sql