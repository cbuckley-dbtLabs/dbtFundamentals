-- customers.sql
with

customers as (select * from {{ ref("stg_jaffle_shop__customers") }}),

order_history as (select * from {{ ref("int_customer_order_history") }}),

customer_orders as (

    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as number_of_orders,
        sum(amount) as lifetime_value

    from order_history

    group by 1

),

order_gaps as (

    select
        customer_id,
        round(avg(days_since_previous_order), 1) as avg_days_between_orders

    from order_history

    where days_since_previous_order is not null

    group by 1

),

customers_enriched as (

    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        customer_orders.lifetime_value,
        order_gaps.avg_days_between_orders,
        coalesce(customer_orders.number_of_orders, 0) as number_of_orders,
        datediff(
            'day', customer_orders.most_recent_order_date, current_date
        ) as days_since_last_order,
        case
            when
                coalesce(customer_orders.number_of_orders, 0) = 0
                then 'No Orders'
            when coalesce(customer_orders.number_of_orders, 0) = 1 then 'New'
            when
                coalesce(customer_orders.number_of_orders, 0) <= 4
                then 'Repeat'
            else 'Loyal'
        end as customer_segment

    from customers

    left join
        customer_orders
        on customers.customer_id = customer_orders.customer_id
    left join order_gaps on customers.customer_id = order_gaps.customer_id

)

select *
from customers_enriched
