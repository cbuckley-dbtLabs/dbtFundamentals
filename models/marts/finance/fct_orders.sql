with
    orders as (
        select
            order_id,
            customer_id,
            order_date,
            status
        from {{ ref("stg_jaffle_shop__orders") }}
    ),

    order_payments as (
        select
            order_id,
            total_amount,
            gift_card_amount,
            credit_card_amount
        from {{ ref("int_payments_pivoted_to_orders") }}
    ),

    state_demo_order_enrichment as (
        select
            order_id,
            total_refund_amount,
            approved_refund_amount,
            pending_refund_amount,
            order_item_count,
            item_quantity,
            item_subtotal,
            distinct_product_count,
            campaign_count,
            primary_campaign_id,
            campaign_name,
            campaign_channel,
            shipment_count,
            latest_shipped_at,
            latest_delivered_at,
            is_shipped,
            is_delivered,
            is_fulfillment_return,
            refund_count,
            has_approved_refund,
            has_pending_refund
        from {{ ref("int_state_demo__order_enrichment") }}
    )

select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status as order_status,
    coalesce(order_payments.total_amount, 0) as amount,
    coalesce(order_payments.gift_card_amount, 0) as gift_card_amount,
    coalesce(order_payments.credit_card_amount, 0) as credit_card_amount,
    coalesce(state_demo_order_enrichment.total_refund_amount, 0) as total_refund_amount,
    coalesce(state_demo_order_enrichment.approved_refund_amount, 0) as approved_refund_amount,
    coalesce(state_demo_order_enrichment.pending_refund_amount, 0) as pending_refund_amount,
    coalesce(order_payments.total_amount, 0)
    - coalesce(state_demo_order_enrichment.total_refund_amount, 0) as net_amount,
    coalesce(state_demo_order_enrichment.order_item_count, 0) as order_item_count,
    coalesce(state_demo_order_enrichment.item_quantity, 0) as item_quantity,
    coalesce(state_demo_order_enrichment.item_subtotal, 0) as item_subtotal,
    coalesce(state_demo_order_enrichment.distinct_product_count, 0) as distinct_product_count,
    coalesce(state_demo_order_enrichment.campaign_count, 0) as campaign_count,
    state_demo_order_enrichment.primary_campaign_id,
    state_demo_order_enrichment.campaign_name,
    state_demo_order_enrichment.campaign_channel,
    coalesce(state_demo_order_enrichment.shipment_count, 0) as shipment_count,
    state_demo_order_enrichment.latest_shipped_at,
    state_demo_order_enrichment.latest_delivered_at,
    coalesce(state_demo_order_enrichment.is_shipped, 0) as is_shipped,
    coalesce(state_demo_order_enrichment.is_delivered, 0) as is_delivered,
    coalesce(state_demo_order_enrichment.is_fulfillment_return, 0) as is_fulfillment_return,
    coalesce(state_demo_order_enrichment.refund_count, 0) as refund_count,
    coalesce(state_demo_order_enrichment.has_approved_refund, 0) as has_approved_refund,
    coalesce(state_demo_order_enrichment.has_pending_refund, 0) as has_pending_refund,
    case
        when state_demo_order_enrichment.order_id is not null then 1 else 0
    end as is_state_demo_order,
    case
        when orders.status in ('returned', 'return_pending') then 1 else 0
    end as is_return
from orders
left join order_payments
    on orders.order_id = order_payments.order_id
left join state_demo_order_enrichment
    on orders.order_id = state_demo_order_enrichment.order_id
