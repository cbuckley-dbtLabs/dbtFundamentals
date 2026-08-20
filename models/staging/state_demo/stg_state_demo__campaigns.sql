select
    campaign_id,
    campaign_name,
    channel,
    objective,
    budget,
    status,
    _loaded_at as loaded_at,
    _state_demo_run_id as state_demo_run_id

from {{ source("state_demo", "campaigns") }}
