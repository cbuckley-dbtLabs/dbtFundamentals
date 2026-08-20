select
    shipment_id,
    order_id,
    shipping_method,
    shipment_status,
    shipped_at,
    delivered_at,
    _loaded_at as loaded_at,
    _state_demo_run_id as state_demo_run_id

from {{ source("state_demo", "shipments") }}
