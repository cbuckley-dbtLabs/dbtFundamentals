select
    id || '|' || sku as supply_product_key,
    id as supply_id,
    name as supply_name,
    cost,
    perishable,
    sku
from {{ source('jaffle_shop', 'supplies') }}

