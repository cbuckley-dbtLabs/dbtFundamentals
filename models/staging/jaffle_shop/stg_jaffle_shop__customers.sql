select 
    id as customer_id,
    first_name,
    last_name,
    email,
    value
from {{ source('jaffle_shop', 'customers') }}