{{
    config(
        materialized="table",
        tags=["slow_agg", "customer_lifecycle", "mart", "marketing"]
    )
}}

with

    lifecycle_windows as (

        select
            as_of_date,
            lookback_window_days,
            customer_segment,
            lifecycle_state,
            is_active_in_window,
            customer_id,
            days_since_most_recent_order,
            lifetime_orders_to_date,
            lifetime_revenue_to_date,
            orders_in_window,
            completed_orders_in_window,
            returned_orders_in_window,
            revenue_in_window,
            gift_card_amount_in_window,
            credit_card_amount_in_window

        from {{ ref("int_customer_lifecycle_windows") }}

    ),

    daily_lifecycle as (

        select
            as_of_date,
            lookback_window_days,
            customer_segment,
            lifecycle_state,
            count(customer_id) as customer_count,
            count(case when is_active_in_window then customer_id end) as active_customer_count,
            count(case when lifetime_orders_to_date > 0 then customer_id end) as customers_with_orders_to_date,
            sum(lifetime_orders_to_date) as lifetime_orders_to_date,
            sum(lifetime_revenue_to_date) as lifetime_revenue_to_date,
            sum(orders_in_window) as orders_in_window,
            sum(completed_orders_in_window) as completed_orders_in_window,
            sum(returned_orders_in_window) as returned_orders_in_window,
            sum(revenue_in_window) as revenue_in_window,
            sum(gift_card_amount_in_window) as gift_card_amount_in_window,
            sum(credit_card_amount_in_window) as credit_card_amount_in_window,
            round(avg(days_since_most_recent_order), 1) as avg_days_since_most_recent_order

        from lifecycle_windows

        group by 1, 2, 3, 4

    )

select
    as_of_date,
    lookback_window_days,
    customer_segment,
    lifecycle_state,
    customer_count,
    active_customer_count,
    customers_with_orders_to_date,
    lifetime_orders_to_date,
    lifetime_revenue_to_date,
    orders_in_window,
    completed_orders_in_window,
    returned_orders_in_window,
    revenue_in_window,
    gift_card_amount_in_window,
    credit_card_amount_in_window,
    avg_days_since_most_recent_order,
    revenue_in_window / nullif(active_customer_count, 0) as revenue_per_active_customer,
    active_customer_count / nullif(customer_count, 0) as active_customer_rate,
    returned_orders_in_window / nullif(orders_in_window, 0) as return_rate_in_window

from daily_lifecycle
