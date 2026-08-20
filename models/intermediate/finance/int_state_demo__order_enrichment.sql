with

    order_items as (

        select
            order_id,
            order_item_id,
            product_sku,
            quantity,
            unit_price,
            campaign_id

        from {{ ref("stg_state_demo__order_items") }}

    ),

    campaigns as (

        select
            campaign_id,
            campaign_name,
            channel

        from {{ ref("stg_state_demo__campaigns") }}

    ),

    shipments as (

        select
            order_id,
            shipment_id,
            shipment_status,
            shipped_at,
            delivered_at

        from {{ ref("stg_state_demo__shipments") }}

    ),

    refunds as (

        select
            order_id,
            refund_id,
            refund_amount,
            refund_status

        from {{ ref("stg_state_demo__refunds") }}

    ),

    order_item_rollup as (

        select
            order_items.order_id,
            count(order_items.order_item_id) as order_item_count,
            sum(order_items.quantity) as item_quantity,
            sum(order_items.quantity * order_items.unit_price) as item_subtotal,
            count(distinct order_items.product_sku) as distinct_product_count,
            count(distinct order_items.campaign_id) as campaign_count,
            min(order_items.campaign_id) as primary_campaign_id,
            max(campaigns.campaign_name) as campaign_name,
            case
                when count(distinct campaigns.channel) > 1 then 'multi_channel'
                else max(campaigns.channel)
            end as campaign_channel

        from order_items

        left join campaigns on order_items.campaign_id = campaigns.campaign_id

        group by 1

    ),

    shipment_rollup as (

        select
            order_id,
            count(shipment_id) as shipment_count,
            max(shipped_at) as latest_shipped_at,
            max(delivered_at) as latest_delivered_at,
            max(case when shipment_status in ('shipped', 'delivered') then 1 else 0 end) as is_shipped,
            max(case when shipment_status = 'delivered' then 1 else 0 end) as is_delivered,
            max(case when shipment_status = 'returned' then 1 else 0 end) as is_fulfillment_return

        from shipments

        group by 1

    ),

    refund_rollup as (

        select
            order_id,
            count(refund_id) as refund_count,
            sum(refund_amount) as total_refund_amount,
            sum(case when refund_status = 'approved' then refund_amount else 0 end) as approved_refund_amount,
            sum(case when refund_status = 'pending' then refund_amount else 0 end) as pending_refund_amount,
            max(case when refund_status = 'approved' then 1 else 0 end) as has_approved_refund,
            max(case when refund_status = 'pending' then 1 else 0 end) as has_pending_refund

        from refunds

        group by 1

    ),

    final as (

        select
            order_item_rollup.order_id,
            order_item_rollup.order_item_count,
            order_item_rollup.item_quantity,
            order_item_rollup.item_subtotal,
            order_item_rollup.distinct_product_count,
            order_item_rollup.campaign_count,
            order_item_rollup.primary_campaign_id,
            order_item_rollup.campaign_name,
            order_item_rollup.campaign_channel,
            coalesce(shipment_rollup.shipment_count, 0) as shipment_count,
            shipment_rollup.latest_shipped_at,
            shipment_rollup.latest_delivered_at,
            coalesce(shipment_rollup.is_shipped, 0) as is_shipped,
            coalesce(shipment_rollup.is_delivered, 0) as is_delivered,
            coalesce(shipment_rollup.is_fulfillment_return, 0) as is_fulfillment_return,
            coalesce(refund_rollup.refund_count, 0) as refund_count,
            coalesce(refund_rollup.total_refund_amount, 0) as total_refund_amount,
            coalesce(refund_rollup.approved_refund_amount, 0) as approved_refund_amount,
            coalesce(refund_rollup.pending_refund_amount, 0) as pending_refund_amount,
            coalesce(refund_rollup.has_approved_refund, 0) as has_approved_refund,
            coalesce(refund_rollup.has_pending_refund, 0) as has_pending_refund

        from order_item_rollup

        left join shipment_rollup on order_item_rollup.order_id = shipment_rollup.order_id
        left join refund_rollup on order_item_rollup.order_id = refund_rollup.order_id

    )

select *
from final
