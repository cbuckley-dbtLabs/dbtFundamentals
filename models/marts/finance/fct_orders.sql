-- orders.sql
with
    orders as (select * from {{ ref("stg_jaffle_shop__orders") }}),

    order_payments as (select * from {{ ref("int_payments_pivoted_to_orders") }}),

    combined_info as (

        select
            orders.order_id,
            orders.customer_id,
            orders.order_date,
            orders.status as order_status,
            coalesce(order_payments.total_amount, 0) as amount,
            coalesce(order_payments.gift_card_amount, 0) as gift_card_amount,
            case
                when orders.status in ('returned', 'return_pending') then 1 else 0
            end as is_return

        from orders

        left join order_payments on orders.order_id = order_payments.order_id

    )

select *
from combined_info
