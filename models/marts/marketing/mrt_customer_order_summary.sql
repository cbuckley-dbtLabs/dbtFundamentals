with

    customers as (select * from {{ ref("stg_jaffle_shop__customers") }}),

    orders as (select * from {{ ref("fct_orders") }}),

    customer_orders as (

        select
            customer_id,
            min(order_date) as first_order_date,
            max(order_date) as most_recent_order_date,
            count(order_id) as total_orders,
            count(case when order_status = 'completed' then order_id end) as completed_orders,
            count(case when order_status = 'returned' then order_id end) as returned_orders,
            count(case when amount > 0 then order_id end) as successful_paid_orders,
            coalesce(sum(amount), 0) as total_revenue

        from orders

        group by 1

    ),

    customer_order_summary as (

        select
            customers.customer_id,
            customers.first_name,
            customers.last_name,
            customer_orders.first_order_date,
            customer_orders.most_recent_order_date,
            coalesce(customer_orders.total_orders, 0) as total_orders,
            coalesce(customer_orders.completed_orders, 0) as completed_orders,
            coalesce(customer_orders.returned_orders, 0) as returned_orders,
            coalesce(customer_orders.total_revenue, 0) as total_revenue,
            coalesce(
                customer_orders.total_revenue
                / nullif(customer_orders.successful_paid_orders, 0),
                0
            ) as average_order_value,
            coalesce(customer_orders.total_revenue, 0) as customer_lifetime_value,
            datediff(
                'day', customer_orders.most_recent_order_date, current_date
            ) as days_since_last_order,
            coalesce(customer_orders.total_orders, 0) > 1 as is_repeat_customer,
            case
                when coalesce(customer_orders.total_orders, 0) = 0 then 'No Orders'
                when coalesce(customer_orders.total_orders, 0) = 1 then 'New'
                when coalesce(customer_orders.total_orders, 0) <= 4 then 'Repeat'
                else 'Loyal'
            end as customer_segment

        from customers

        left join customer_orders on customers.customer_id = customer_orders.customer_id

    )

select *
from customer_order_summary
