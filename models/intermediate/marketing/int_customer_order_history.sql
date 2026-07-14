with

    orders as (select * from {{ ref("stg_jaffle_shop__orders") }}),

    order_payments as (select * from {{ ref("int_payments_pivoted_to_orders") }}),

    order_with_lag as (

        select
            orders.order_id,
            orders.customer_id,
            orders.order_date,
            coalesce(order_payments.total_amount, 0) as amount,
            orders.status as order_status,

            row_number() over (
                partition by orders.customer_id order by orders.order_date
            ) as order_number,

            lag(orders.order_date) over (
                partition by orders.customer_id order by orders.order_date
            ) as previous_order_date

        from orders
        left join order_payments on orders.order_id = order_payments.order_id

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
