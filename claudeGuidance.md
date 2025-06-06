# Claude Analysis Guidance

## Overview

This document provides guidance for Claude on how to answer questions regarding the data warehouse modeled by this dbt project. It defines business terms, outlines recommended analysis patterns, and sets expectations for prompt engineering within the project context.

## Business Context

- This project models transactional sales data for Acme Corp.
- Source data originates from the `raw.sales_orders` and `raw.customers` tables.
- Data is updated daily via incremental loads.

## Key Models and Relationships

### Fact Tables:

- `fct_sales_orders`: Transaction-level sales data
  - Key fields: `order_id`, `customer_id`, `order_date`, `total_amount`, `discount_applied`, `region`

### Dimension Tables:

- `dim_customers`
  - Key fields: `customer_id`, `customer_tier`, `signup_date`, `country`

- `dim_dates`
  - Key fields: `date_id`, `date`, `month`, `quarter`, `year`

## Analysis Patterns

### 1. Revenue by Country and Month

- Definition: Sum of `total_amount` grouped by `country` and the relevant `month`.
- Example SQL:
sql
  SELECT
    dim_customers.country,
    dim_dates.month,
    SUM(fct_sales_orders.total_amount) AS total_revenue
  FROM fct_sales_orders
  JOIN dim_customers ON fct_sales_orders.customer_id = dim_customers.customer_id
  JOIN dim_dates ON fct_sales_orders.order_date = dim_dates.date
  GROUP BY dim_customers.country, dim_dates.month

### 2. Customer Retention Rate

- Definition: Percentage of customers in a selected cohort who placed a repeat order within 90 days.
- Prompt Guidance: "Compute the 90-day retention rate for customers who first purchased in Q1 2025."

### 3. Top Products by Net Sales

- Use the `product_name` and sum `total_amount - discount_applied` to identify top selling products.
- Exclude refunded orders where applicable (`order_status <> 'refunded'`).

## Business Definitions

- **Order**: A confirmed sale record; cancelled or test orders are excluded.
- **Customer Tier**: Segmentation label—one of ["bronze", "silver", "gold"]—defined in `dim_customers.customer_tier`.
- **Net Sales**: Total revenue after subtracting discounts but before tax.

## Example Prompts for Claude

- "List monthly revenue for each country in 2025."
- "What is the retention rate for customers who signed up in February?"
- "Who are the top five gold-tier customers by lifetime spend?"

## Notes for Claude

- Always clarify if revenue should be gross or net of discounts.
- When querying trends, default aggregation is monthly unless a different period is specified.
- Use field and model names as documented here or in the dbt project schema.yml files.