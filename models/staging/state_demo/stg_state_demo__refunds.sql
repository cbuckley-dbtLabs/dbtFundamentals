select
    refund_id,
    order_id,
    payment_id,
    refund_amount,
    refund_reason,
    refund_status,
    refunded_at,
    _loaded_at as loaded_at,
    _state_demo_run_id as state_demo_run_id

from {{ source("state_demo", "refunds") }}
