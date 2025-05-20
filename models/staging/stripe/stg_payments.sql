{{ config(
    materialized='incremental',
    unique_key='payment_id',
    on_schema_change='sync_all_columns'
) }}

select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    -- amount is stored in cents, convert it to dollars
    amount / 100 as amount,
    created as created_at
from {{ source('stripe', 'payment') }}