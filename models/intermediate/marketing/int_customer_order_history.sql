with

    orders as (select * from {{ ref("fct_orders") }}),

    order_with_lag as (

        select
            order_id,
            customer_id,
            order_date,
            amount,
            order_status,

            row_number() over (
                partition by customer_id order by order_date
            ) as order_number,

            lag(order_date) over (
                partition by customer_id order by order_date
            ) as previous_order_date

        from orders

    ),

    order_history as (

        select
            order_id,
            customer_id,
            order_date,
            amount,
            order_status,
            order_number,
            previous_order_date,
            datediff(
                'day', previous_order_date, order_date
            ) as days_since_previous_order

        from order_with_lag

    )

select *
from order_history
