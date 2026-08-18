{{
    config(
        materialized="table",
        tags=["slow_agg", "customer_lifecycle", "intermediate", "marketing"]
    )
}}

{% set as_of_start_date = var("customer_lifecycle_as_of_start_date", "2018-01-01") %}
{% set as_of_end_date = var("customer_lifecycle_as_of_end_date", "current_date") %}
{% set window_days = var("customer_lifecycle_window_days", [7, 14, 30, 60, 90, 180, 365, 730, 1095, 1460, 1825, 2555]) %}

with

    date_bounds as (

        select
            to_date('{{ as_of_start_date }}') as start_date,
            {% if as_of_end_date | lower in ["current_date", "current_date()"] %}
                current_date
            {% else %}
                to_date('{{ as_of_end_date }}')
            {% endif %} as end_date

    ),

    as_of_dates as (

        select dateadd(day, flattened_dates.value::integer, date_bounds.start_date) as as_of_date

        from date_bounds,
            table(
                flatten(
                    input => array_generate_range(
                        0,
                        datediff(day, date_bounds.start_date, date_bounds.end_date) + 1
                    )
                )
            ) as flattened_dates

    ),

    lifecycle_windows as (

        select lookback_window_days::integer as lookback_window_days

        from values
        {% for window_day in window_days %}
            ({{ window_day }}){% if not loop.last %},{% endif %}
        {% endfor %}
            as configured_windows(lookback_window_days)

    ),

    customers as (

        select
            customer_id,
            first_order_date,
            customer_segment

        from {{ ref("dim_customers") }}

    ),

    orders as (

        select
            order_id,
            customer_id,
            order_date,
            order_status,
            amount,
            gift_card_amount,
            credit_card_amount,
            is_return

        from {{ ref("fct_orders") }}

    ),

    customer_date_windows as (

        select
            customers.customer_id,
            customers.first_order_date,
            date_trunc(month, customers.first_order_date) as first_order_month,
            customers.customer_segment,
            as_of_dates.as_of_date,
            lifecycle_windows.lookback_window_days,
            dateadd(
                day, 1 - lifecycle_windows.lookback_window_days, as_of_dates.as_of_date
            ) as window_start_date

        from customers

        cross join as_of_dates
        cross join lifecycle_windows

    ),

    customer_lifecycle_features as (

        select
            customer_date_windows.customer_id,
            customer_date_windows.as_of_date,
            customer_date_windows.lookback_window_days,
            customer_date_windows.window_start_date,
            customer_date_windows.first_order_date,
            customer_date_windows.first_order_month,
            customer_date_windows.customer_segment,
            max(orders.order_date) as most_recent_order_date,
            count(orders.order_id) as lifetime_orders_to_date,
            coalesce(sum(orders.amount), 0) as lifetime_revenue_to_date,
            count(
                case
                    when orders.order_date >= customer_date_windows.window_start_date
                        then orders.order_id
                end
            ) as orders_in_window,
            count(
                case
                    when
                        orders.order_date >= customer_date_windows.window_start_date
                        and orders.order_status = 'completed'
                        then orders.order_id
                end
            ) as completed_orders_in_window,
            count(
                case
                    when
                        orders.order_date >= customer_date_windows.window_start_date
                        and orders.is_return = 1
                        then orders.order_id
                end
            ) as returned_orders_in_window,
            coalesce(
                sum(
                    case
                        when orders.order_date >= customer_date_windows.window_start_date
                            then orders.amount
                    end
                ),
                0
            ) as revenue_in_window,
            coalesce(
                sum(
                    case
                        when orders.order_date >= customer_date_windows.window_start_date
                            then orders.gift_card_amount
                    end
                ),
                0
            ) as gift_card_amount_in_window,
            coalesce(
                sum(
                    case
                        when orders.order_date >= customer_date_windows.window_start_date
                            then orders.credit_card_amount
                    end
                ),
                0
            ) as credit_card_amount_in_window

        from customer_date_windows

        left join orders
            on customer_date_windows.customer_id = orders.customer_id
            and orders.order_date <= customer_date_windows.as_of_date

        group by
            customer_date_windows.customer_id,
            customer_date_windows.as_of_date,
            customer_date_windows.lookback_window_days,
            customer_date_windows.window_start_date,
            customer_date_windows.first_order_date,
            customer_date_windows.first_order_month,
            customer_date_windows.customer_segment

    ),

    final as (

        select
            customer_id,
            as_of_date,
            lookback_window_days,
            window_start_date,
            first_order_date,
            first_order_month,
            customer_segment,
            most_recent_order_date,
            datediff(day, most_recent_order_date, as_of_date) as days_since_most_recent_order,
            lifetime_orders_to_date,
            lifetime_revenue_to_date,
            orders_in_window,
            completed_orders_in_window,
            returned_orders_in_window,
            revenue_in_window,
            gift_card_amount_in_window,
            credit_card_amount_in_window,
            orders_in_window > 0 as is_active_in_window,
            case
                when lifetime_orders_to_date = 0 then 'No Orders Yet'
                when orders_in_window > 0 then 'Active'
                when datediff(day, most_recent_order_date, as_of_date) > 365 then 'Dormant'
                else 'Lapsed'
            end as lifecycle_state

        from customer_lifecycle_features

    )

select
    customer_id,
    as_of_date,
    lookback_window_days,
    window_start_date,
    first_order_date,
    first_order_month,
    customer_segment,
    lifecycle_state,
    is_active_in_window,
    most_recent_order_date,
    days_since_most_recent_order,
    lifetime_orders_to_date,
    lifetime_revenue_to_date,
    orders_in_window,
    completed_orders_in_window,
    returned_orders_in_window,
    revenue_in_window,
    gift_card_amount_in_window,
    credit_card_amount_in_window

from final
