# Lake Compute

This project uses Lake Compute as a dev-only sidecar for one pilot branch. The
remaining models continue to run on Snowflake.

## Required setup

Lake Compute is a dbt v2 private beta feature. Before running the pilot:

1. Enable Lake Compute on the Fivetran MDLS destination and generate a token.
2. Set `DBT_ENGINE_EXPERIMENTAL_MULTI_ADAPTER=true`.
3. Keep Snowflake on key-pair authentication for direct JWT access.
4. Add a `lakecompute` output to the `dev` target while keeping Snowflake as
   the default adapter:

```yaml
default:
  target: dev
  outputs:
    dev:
      - name: snowflake
        type: snowflake
        method: keypair
        default: true
        private_key: "{{ env_var('DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY') }}"
        private_key_passphrase: "{{ env_var('DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') }}"
        account: YOUR_ACCOUNT
        user: YOUR_USER
        role: YOUR_ROLE
        database: YOUR_DATABASE
        warehouse: YOUR_WAREHOUSE
        schema: YOUR_SCHEMA
      - name: lakecompute
        type: lakecompute
        method: fivetran
        fivetran_credential: "{{ env_var('DBT_LAKE_COMPUTE_TOKEN') }}"
```

Lake Compute uses two separate credentials in the sidecar setup:

- The Snowflake private key signs a direct JWT for Horizon catalog access.
- `DBT_LAKE_COMPUTE_TOKEN` authenticates dbt to the Lake Compute service and
  remains required even when Snowflake uses JWT authentication.

Do not change the Snowflake method to `self_signed_jwt` to avoid network
policies. Despite its name, that method creates and caches a Snowflake PAT,
which still requires a network policy. The `keypair` method supports the
direct-JWT path and does not require PAT network-policy setup.

For dbt platform environments, configure the Lake Compute extended attribute
and set `DBT_LAKE_COMPUTE_TOKEN` as an environment variable:

```yaml
lakecompute:
  method: fivetran
  token: "{{ env_var('DBT_LAKE_COMPUTE_TOKEN') }}"
```

The sidecar output inherits the Snowflake output's database and schema. The
Snowflake catalog integration for the MDLS destination must be granted to the
role running dbt so Snowflake can read tables propagated from MDLS.

## Pilot

In `dev`, `models/intermediate/finance/int_state_demo__order_enrichment.sql`
runs on Lake Compute and materializes as an Iceberg table. Its four
`state_demo` staging inputs run on Snowflake as Snowflake-managed Iceberg
tables. Other targets retain the existing Snowflake view behavior.

Validate the pilot before moving additional models:

```bash
export DBT_ENGINE_EXPERIMENTAL_MULTI_ADAPTER=true
dbt debug
dbt build --select +int_state_demo__order_enrichment.sql
```

Do not run the pilot build until `dbt debug` passes its MDLS write and read-back
checks. If the write succeeds but read-back fails, confirm that the Snowflake
catalog integration points to the same Fivetran MDLS destination as
`DBT_LAKE_COMPUTE_TOKEN`, its OAuth secret and storage access are current, and
the dbt role can use the integration.

Lake Compute does not support view materializations during the private beta,
and Lake Compute models must read Iceberg inputs. Keep the current
view-heavy staging and intermediate DAG on Snowflake until each branch has
been converted and validated independently.
