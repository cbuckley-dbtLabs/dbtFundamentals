# dbt Fundamentals — Jaffle Shop Analytics

This Snowflake dbt project models Jaffle Shop customers, orders, and Stripe payments, then enriches the order grain with demo campaign, item, shipment, and refund data. It publishes finance and marketing marts, customer lifecycle and retention aggregates, and a governed dbt Semantic Layer for order analysis.

## Current status

- Runs on dbt Fusion and parses successfully with strict static analysis enabled by default.
- Contains 19 models: 7 staging views, 4 intermediate models, and 8 marts.
- Publishes two semantic models (`fct_orders` and `dim_customers`), 15 order metrics, two saved queries, and two dashboard exposures.
- Uses `dbt_utils` `1.4.1` for reusable tests and utilities.
- Includes source freshness configuration for Stripe and the generated `state_demo` sources.

The project is actively beyond the original dbt starter state. `fusion_migration_summary.md` records an earlier migration checkpoint and should be treated as historical context rather than the current resource inventory.

## Design

The project follows a staging → intermediate → marts pattern:

```text
raw.jaffle_shop ──> staging/jaffle_shop ───────────────┐
raw.stripe ───────> staging/stripe ──> intermediate ───┼──> marts/finance/fct_orders
state_demo ───────> staging/state_demo ─> intermediate ┘              │
                                                                      ├──> marts/marketing/dim_customers
                                                                      ├──> customer order summary
                                                                      └──> lifecycle and retention aggregates
```

Materialization defaults are defined in `dbt_project.yml`:

- `staging`: views that rename and standardize source data.
- `intermediate`: views by default, with the dense lifecycle-window model explicitly materialized as a table.
- `marts`: tables for reporting and semantic consumption.

### Core marts

- `fct_orders` — one row per order. Combines Jaffle Shop orders, pivoted Stripe payments, and optional `state_demo` fulfillment/refund enrichment. This is the central finance fact and primary metric source.
- `dim_customers` — one row per customer. Adds order history, lifetime gross and net value, refund totals, order cadence, and behavioural segments. This model contains PII.
- `mrt_customer_order_summary` — dashboard-ready customer rollup of ordering, payment, fulfillment, refund, and segmentation measures.
- `agg_customer_lifecycle_daily` — daily lifecycle monitoring by lookback window, customer segment, and lifecycle state.
- `agg_customer_retention_cohorts` — monthly first-order cohort retention and revenue analysis.
- `time_spine_daily`, `time_spine_yearly`, and `fiscal_calendar` — standard and custom calendar spines for time-based analysis.

### Semantic Layer

The Semantic Layer is configured directly on the published marts:

- `fct_orders` exposes the order and customer entities, order date/status dimensions, and order metrics including revenue, net revenue, refunds, order count, average order value, return rate, gift-card rate, and month-to-date cumulative revenue.
- `dim_customers` exposes customer attributes and a derived customer value tier.
- Saved queries provide weekly revenue by status and monthly return analysis.
- Exposures document the weekly finance and daily customer-spend dashboards.

Cross-model ratio metrics intentionally live on `fct_orders`, which keeps common MetricFlow queries on a single semantic model and avoids an unnecessary semantic join.

## Data sources

| Source | Location | Purpose |
|---|---|---|
| `jaffle_shop` | `raw.jaffle_shop` | Customers and orders |
| `stripe` | `raw.stripe` | Payment transactions |
| `state_demo` | `analytics.dbt_cbuckley` | Generated campaigns, order items, shipments, and refunds used to demonstrate state-aware development |

`state_demo` is supplemental demo data, not a system-of-record source. The marts preserve all Jaffle Shop orders and default missing enrichment measures to zero.

## Customer lifecycle configuration

The lifecycle feature table creates a dense customer × date × lookback-window data set. Its range and windows are controlled in `dbt_project.yml`:

```yaml
vars:
  customer_lifecycle_as_of_start_date: '2018-01-01'
  customer_lifecycle_as_of_end_date: current_date
  customer_lifecycle_window_days: [7, 14, 30, 60, 90, 180, 365, 730, 1095, 1460, 1825, 2555]
```

Models tagged `slow_agg` can be expensive because the dense lifecycle model grows with customers, dates, and configured windows. Override these vars for bounded development runs when appropriate.

## Project structure

```text
models/
  staging/       Source-aligned cleanup for Jaffle Shop, Stripe, and state_demo
  intermediate/  Payment, fulfillment, order-history, and lifecycle logic
  marts/         Finance, marketing, calendar, semantic models, and saved queries
snapshots/        Order-status history using the check strategy
seeds/            Country reference data
analyses/         Non-materialized exploratory SQL
macros/           Shared SQL helpers
```

## Working with the project

Install dependencies and validate the project:

```bash
dbt deps
dbt parse --no-partial-parse
dbt build
```

Useful focused commands:

```bash
# Build the central order mart and its dependency slice
dbt build --select +fct_orders+

# Build the customer lifecycle models
dbt build --select tag:customer_lifecycle

# Exclude the expensive lifecycle aggregates during routine development
dbt build --exclude tag:slow_agg

# Check configured source freshness
dbt source freshness

# Capture order-status history
dbt snapshot --select orders_snapshot
```

Project-wide model defaults use `static_analysis: strict`. A small number of calendar helper models opt into baseline analysis where required.

## Documentation and ownership

Model grains, column definitions, tests, domains, and ownership metadata live alongside the models in YAML. Published marts are tagged by domain (`finance` or `marketing`) and as `published`; use those tags for targeted builds and discovery.

For deeper migration history, see `fusion_migration_summary.md`. For SQL conventions, see `dbt-styleguide.md`.
