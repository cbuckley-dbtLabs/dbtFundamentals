{{
    config(
        materialized="table",
        tags=["slow_agg", "customer_lifecycle", "mart", "marketing"]
    )
}}

with

    lifecycle_windows as (

        select
            first_order_month,
            date_trunc(month, as_of_date) as as_of_month,
            datediff(month, first_order_month, date_trunc(month, as_of_date)) as months_since_first_order,
            lookback_window_days,
            lifecycle_state,
            is_active_in_window,
            customer_id,
            lifetime_orders_to_date,
            lifetime_revenue_to_date,
            lifetime_net_revenue_to_date,
            lifetime_refund_amount_to_date,
            orders_in_window,
            state_demo_orders_in_window,
            revenue_in_window,
            net_revenue_in_window,
            refund_amount_in_window

        from {{ ref("int_customer_lifecycle_windows") }}

        where first_order_month is not null
            and as_of_date >= first_order_date

    ),

    retention_cohorts as (

        select
            first_order_month,
            as_of_month,
            months_since_first_order,
            lookback_window_days,
            lifecycle_state,
            count(customer_id) as cohort_customer_count,
            count(case when is_active_in_window then customer_id end) as active_customer_count,
            sum(lifetime_orders_to_date) as lifetime_orders_to_date,
            sum(lifetime_revenue_to_date) as lifetime_revenue_to_date,
            sum(lifetime_net_revenue_to_date) as lifetime_net_revenue_to_date,
            sum(lifetime_refund_amount_to_date) as lifetime_refund_amount_to_date,
            sum(orders_in_window) as orders_in_window,
            sum(state_demo_orders_in_window) as state_demo_orders_in_window,
            sum(revenue_in_window) as revenue_in_window,
            sum(net_revenue_in_window) as net_revenue_in_window,
            sum(refund_amount_in_window) as refund_amount_in_window

        from lifecycle_windows

        group by 1, 2, 3, 4, 5

    )

select
    first_order_month,
    as_of_month,
    months_since_first_order,
    lookback_window_days,
    lifecycle_state,
    cohort_customer_count,
    active_customer_count,
    lifetime_orders_to_date,
    lifetime_revenue_to_date,
    lifetime_net_revenue_to_date,
    lifetime_refund_amount_to_date,
    orders_in_window,
    state_demo_orders_in_window,
    revenue_in_window,
    net_revenue_in_window,
    refund_amount_in_window,
    active_customer_count / nullif(cohort_customer_count, 0) as retention_rate,
    revenue_in_window / nullif(active_customer_count, 0) as revenue_per_active_customer,
    net_revenue_in_window / nullif(active_customer_count, 0) as net_revenue_per_active_customer

from retention_cohorts
