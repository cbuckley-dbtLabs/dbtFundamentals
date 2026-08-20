select
    order_item_id,
    order_id,
    line_number,
    product_sku,
    product_name,
    quantity,
    unit_price,
    campaign_id,
    _loaded_at as loaded_at,
    _state_demo_run_id as state_demo_run_id

from {{ source("state_demo", "order_items") }}
