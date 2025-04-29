with customers as (

     select * from {{ ref('stg_jaffle_shop__customers') }}

),
orders as ( 

    select * from {{ ref('stg_jaffle_shop__orders') }}

),
payments as (
    select * from {{ ref("stg_stripe__payments")}}
)

select orders.order_id, orders.customer_id, payments.amount 
from orders 
inner join customers on orders.customer_id = customers.customer_id
inner join payments on orders.order_id = payments.orderid
