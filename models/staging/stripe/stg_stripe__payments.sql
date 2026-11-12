select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    created as created_at,

    -- amount is stored in cents, convert it to dollars
    {{ cents_to_dollars('amount') }} as amount

from {{ source('stripe', 'payment') }}