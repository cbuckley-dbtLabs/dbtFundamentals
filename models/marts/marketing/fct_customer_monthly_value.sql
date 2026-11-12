with orders as (

    select
        customer_id,
        order_id,
        order_date,
        amount,
        net_amount,
        total_refund_amount
    from {{ ref("fct_orders") }}

),

customer_monthly_value as (

    select
        customer_id,
        date_trunc('month', order_date) as order_month,
        count(order_id) as total_orders,
        count(case when amount > 0 then order_id end) as successful_paid_orders,
        coalesce(sum(amount), 0) as gross_value,
        coalesce(sum(net_amount), 0) as net_value,
        coalesce(sum(total_refund_amount), 0) as refund_amount,
        coalesce(
            sum(amount) / nullif(count(case when amount > 0 then order_id end), 0),
            0
        ) as average_order_value
    from orders
    group by 1, 2

)

select *
from customer_monthly_value
