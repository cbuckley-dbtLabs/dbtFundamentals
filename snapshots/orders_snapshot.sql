{% snapshot orders_snapshot %}

{{
    config(
        target_schema='dbt_cbuckley_snapshots',
        unique_key='order_id',
        strategy='check',
        check_cols=['status'],
    )
}}

select
    id as order_id,
    user_id as customer_id,
    order_date,
    status

from {{ source('jaffle_shop', 'orders') }}

{% endsnapshot %}
