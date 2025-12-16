WITH fct_orders AS (
  SELECT
    *
  FROM {{ ref('fct_orders') }}
), filter_1 AS (
  SELECT
    *
  FROM fct_orders
  WHERE
    NOT ORDER_DATE IS NULL
), formula_1 AS (
  SELECT
    *,
    DATE_PART(DAYOFWEEK, ORDER_DATE) AS DAY_NUM,
    CASE DATE_PART(DAYOFWEEK, ORDER_DATE)
      WHEN 0
      THEN 'Sunday'
      WHEN 1
      THEN 'Monday'
      WHEN 2
      THEN 'Tuesday'
      WHEN 3
      THEN 'Wednesday'
      WHEN 4
      THEN 'Thursday'
      WHEN 5
      THEN 'Friday'
      WHEN 6
      THEN 'Saturday'
    END AS DAY_NAME
  FROM filter_1
), rename_1 AS (
  SELECT
    AMOUNT,
    DAY_NUM,
    DAY_NAME
  FROM formula_1
), formula_2 AS (
  SELECT
    *,
    ROUND(AVG(AMOUNT), 2) AS AVG_AMOUNT,
    ROUND(SUM(AMOUNT), 2) AS TOTAL_AMOUNT
  FROM rename_1
), aggregate_1 AS (
  SELECT
    DAY_NUM,
    DAY_NAME,
    COUNT(*) AS ORDER_COUNT
  FROM formula_2
  GROUP BY
    DAY_NUM,
    DAY_NAME
), order_1 AS (
  SELECT
    *
  FROM aggregate_1
  ORDER BY
    DAY_NUM ASC
), output_1 AS (
  SELECT
    DAY_NUM,
    DAY_NAME,
    AVG_AMOUNT,
    ORDER_COUNT,
    TOTAL_AMOUNT
  FROM order_1
)
SELECT
  *
FROM output_1