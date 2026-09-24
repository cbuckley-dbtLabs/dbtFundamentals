# dbtFundamentals — project overview

This document summarizes the dbtFundamentals dbt project for agents and new team members. It reflects the state of the project as of 2026-08-21.

## What this project is

dbtFundamentals is a demo dbt project built on the classic Jaffle Shop dataset (customers, orders, Stripe payments), extended with a "state_demo" dataset (campaigns, order items, shipments, refunds) used to demonstrate dbt's state and lineage features. It has a semantic layer configured, so metrics can be queried directly rather than written as raw SQL each time.

- dbt platform project id: 9407
- Repository: `cbuckley-dbtLabs/dbtFundamentals`
- Environments: Demo Env (production), CanvasTest (generic), STG Test (staging), DevEnv (development)

## Data sources

| Source group | Tables | Notes |
|---|---|---|
| `jaffle_shop` | customers, orders | Raw application data. No freshness check configured. |
| `stripe` | payment | Payment events. Freshness technically "pass" but last load was Oct 2024 — treat as stale/inactive. |
| `state_demo` | campaigns, order_items, refunds, shipments | Generated demo data for state/lineage exercises. Freshness checks configured and passing. |

## Model layers

**Staging** — one row per source record, standardized naming:
`stg_jaffle_shop__orders`, `stg_jaffle_shop__customers`, `stg_stripe__payments`, `stg_state_demo__campaigns`, `stg_state_demo__order_items`, `stg_state_demo__refunds`, `stg_state_demo__shipments`

**Intermediate** — reusable business logic between staging and marts:
- `int_payments_pivoted_to_orders` — successful payments aggregated to order grain, pivoted by payment method
- `int_customer_order_history` — order history enriched with per-customer sequence number and days-since-previous-order
- `int_state_demo__order_enrichment` — rolls up state_demo item/campaign/shipment/refund events to one row per order
- `int_customer_lifecycle_windows` — dense customer feature table: rolling activity and lifetime value per customer, as-of date, and lookback window

**Marts (presentation layer)** — the tables analysts and dashboards should query:
- `fct_orders` — central order fact: order id, customer id, date, status, total amount, gift card usage, return flag
- `dim_customers` — customer dimension with order history, behavioral segments, retention signals
- `mrt_customer_order_summary` — one row per customer, rolled-up order activity, payment revenue, fulfillment status counts
- `agg_customer_lifecycle_daily` — daily active/lapsed/dormant/not-yet-ordering customer counts by segment
- `agg_customer_retention_cohorts` — monthly retention cohorts by first-order month and lookback window
- `fiscal_calendar`, `time_spine_daily`, `time_spine_yearly` — calendar/date spine helpers used across marts

## Semantic layer

**Metrics** (query via the Semantic Layer rather than writing raw SQL against marts):

| Metric | Type | Description |
|---|---|---|
| `total_amount` | simple | Total monetary value of all orders (closest proxy for "sales") |
| `total_net_amount` | simple | Total order amount after state_demo refunds |
| `total_refund_amount` | simple | Total state_demo refund amount |
| `refund_amount_rate` | ratio | Share of gross order amount refunded |
| `count_order` | simple | Total number of orders placed |
| `count_ordering_customer` | simple | Distinct customers with at least one order |
| `orders_per_customer` | ratio | Average orders per ordering customer |
| `avg_order_value` | ratio | Average revenue per order |
| `revenue_per_customer` | ratio | Average revenue per ordering customer |
| `cumulative_revenue` | cumulative | Running month-to-date total of order revenue |
| `gift_card_amount` / `gift_card_rate` | simple / ratio | Gift-card-paid amount and its share of revenue |
| `return_count` / `return_rate` | simple / ratio | Orders returned or pending return, and their share |
| `state_demo_order_count` | simple | Orders with state_demo enrichment attached |

**Saved queries** (pre-built combinations, good starting points):
- `weekly_revenue_by_status` — total_amount, count_order, avg_order_value by order status and week
- `monthly_return_analysis` — return_count, return_rate, total_amount, count_order by order status and month

## Macros

Project-specific macro package `dbt_fundamentals` contains one macro: `cents_to_dollars` (used in `stg_stripe__payments` to convert Stripe's cent-denominated amounts). Community `dbt_utils` macros are also available.

## Downstream exposures

- `weekly_jaffle_metrics` — weekly dashboard for order volume, revenue, customer activity (bi.tool/dashboards/1)
- `daily_customer_spend` — daily dashboard for customer spend and revenue performance (bi.tool/dashboards/2)

## Orchestration

Three jobs run in the Demo Env:
- **Catalog Population Job** — scheduled, most recent run succeeded
- **AdvancedCI Build** — CI job triggered on GitHub webhook, most recent run succeeded
- **Airflow_Job** — externally triggered, no active schedule; last ran Nov 2025

## Known gaps / things to watch

- `jaffle_shop.customers` and `jaffle_shop.orders` have no freshness checks configured — staleness would go undetected.
- `stripe.payment` freshness shows "pass" but the underlying data hasn't loaded since October 2024; the threshold isn't strict enough to catch this.
- The demo order/sales data only spans a few months (Jan–Apr 2018 for core orders), so trend analysis on raw fct_orders data is limited — use with that context.
