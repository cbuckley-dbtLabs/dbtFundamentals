#!/usr/bin/env python3
"""Create Snowflake source tables for dbt state demonstrations.

The script reads the same dbt profile used by this project and prints the
STATE_DEMO_ tables it creates in ANALYTICS.DBT_CBUCKLEY. It does not print
Snowflake connection details or secrets.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any
import yaml


PROJECT_PROFILE_NAME = "default"
DATABASE = "ANALYTICS"
SCHEMA = "DBT_CBUCKLEY"
TABLE_PREFIX = "STATE_DEMO_"

ENV_VAR_PATTERN = re.compile(
    r"\{\{\s*env_var\(\s*['\"]([^'\"]+)['\"]\s*(?:,\s*['\"]([^'\"]*)['\"])?\s*\)\s*\}\}"
)


def expand_env_vars(value: str) -> str:
    def replace_env_var(match: re.Match[str]) -> str:
        name = match.group(1)
        default = match.group(2)
        resolved_value = os.getenv(name, default)
        if resolved_value is None:
            raise RuntimeError(f"Environment variable {name} is required by profiles.yml")
        return resolved_value

    return ENV_VAR_PATTERN.sub(replace_env_var, value)


def env_var_constructor(loader: yaml.SafeLoader, node: yaml.Node) -> str:
    return expand_env_vars(loader.construct_scalar(node))


def resolve_env_vars(value: Any) -> Any:
    if isinstance(value, str):
        return expand_env_vars(value)
    if isinstance(value, dict):
        return {key: resolve_env_vars(item) for key, item in value.items()}
    if isinstance(value, list):
        return [resolve_env_vars(item) for item in value]
    return value


yaml.SafeLoader.add_implicit_resolver("!env_var", ENV_VAR_PATTERN, None)
yaml.SafeLoader.add_constructor("!env_var", env_var_constructor)


def profiles_path() -> Path:
    profiles_dir = os.getenv("DBT_PROFILES_DIR")
    if profiles_dir:
        return Path(profiles_dir).expanduser() / "profiles.yml"
    return Path.home() / ".dbt" / "profiles.yml"


def load_profile(profile_name: str, target_override: str | None) -> tuple[str, dict[str, Any]]:
    path = profiles_path()
    if not path.exists():
        raise FileNotFoundError(f"No dbt profile found at {path}")

    with path.open(encoding="utf-8") as profile_file:
        profiles = resolve_env_vars(yaml.safe_load(profile_file))

    if profile_name not in profiles:
        raise KeyError(f"Profile {profile_name!r} was not found in {path}")

    profile = profiles[profile_name]
    target_name = target_override or profile.get("target")
    outputs = profile.get("outputs", {})
    if not target_name:
        if len(outputs) == 1:
            target_name = next(iter(outputs))
        else:
            raise KeyError(f"Profile {profile_name!r} must define target or use --target")

    if target_name not in outputs:
        raise KeyError(f"Target {target_name!r} was not found in profile {profile_name!r}")

    return target_name, normalize_output(outputs[target_name], target_name, profile_name)


def normalize_output(
    output: Any, target_name: str, profile_name: str
) -> dict[str, Any]:
    if isinstance(output, dict):
        return output

    if not isinstance(output, list):
        raise ValueError(f"Target {target_name!r} in profile {profile_name!r} is invalid")

    snowflake_entries = [entry for entry in output if entry.get("type") == "snowflake"]
    default_entries = [entry for entry in snowflake_entries if entry.get("default") is True]
    selected_entries = default_entries or snowflake_entries
    if len(selected_entries) != 1:
        raise ValueError(
            f"Target {target_name!r} in profile {profile_name!r} must have exactly one "
            "Snowflake connection entry (mark the intended one with default: true)"
        )

    return selected_entries[0]


def q(identifier: str) -> str:
    return f'"{identifier.upper()}"'


def fq_table(table_name: str) -> str:
    return f"{q(DATABASE)}.{q(SCHEMA)}.{q(table_name)}"


def rows_clause(rows: list[tuple[Any, ...]]) -> tuple[str, list[Any]]:
    placeholders = []
    values: list[Any] = []
    for row in rows:
        placeholders.append("(" + ", ".join(["%s"] * len(row)) + ")")
        values.extend(row)
    return ",\n        ".join(placeholders), values


def table_sql_and_values(
    table_name: str,
    columns: list[str],
    column_types: list[str],
    rows: list[tuple[Any, ...]],
) -> tuple[str, list[Any]]:
    if not table_name.startswith(TABLE_PREFIX):
        raise ValueError(f"Refusing to write non-demo table {table_name}")

    select_values, values = rows_clause(rows)
    typed_columns = ", ".join(
        f"column{index + 1}::{column_type} as {q(column_name)}"
        for index, (column_name, column_type) in enumerate(zip(columns, column_types))
    )
    sql = f"""
create or replace table {fq_table(table_name)} as
select {typed_columns}
from values
        {select_values}
""".strip()
    return sql, values


def table_summary(table: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": table["name"],
        "fully_qualified_name": f"{DATABASE}.{SCHEMA}.{table['name']}",
        "row_count": len(table["rows"]),
    }


def snowflake_connection_kwargs(profile: dict[str, Any]) -> dict[str, Any]:
    allowed_keys = (
        "account",
        "user",
        "password",
        "warehouse",
        "role",
        "authenticator",
        "token",
        "private_key",
        "private_key_passphrase",
    )
    connection_kwargs = {
        key: profile[key]
        for key in allowed_keys
        if profile.get(key) is not None
    }
    connection_kwargs["database"] = DATABASE
    connection_kwargs["schema"] = SCHEMA
    private_key = connection_kwargs.get("private_key")
    if isinstance(private_key, str):
        if "-----BEGIN" in private_key:
            connection_kwargs["private_key"] = private_key.encode("utf-8")
        else:
            connection_kwargs["private_key"] = base64.b64decode(private_key)
    private_key_passphrase = connection_kwargs.get("private_key_passphrase")
    if isinstance(private_key_passphrase, str):
        connection_kwargs["private_key_passphrase"] = private_key_passphrase.encode("utf-8")
    return connection_kwargs


def create_demo_tables(profile: dict[str, Any], tables: list[dict[str, Any]]) -> list[dict[str, Any]]:
    try:
        import snowflake.connector
    except ImportError as exc:
        raise RuntimeError(
            "Missing dependency: install snowflake-connector-python to run this script"
        ) from exc

    created_tables = []
    with snowflake.connector.connect(**snowflake_connection_kwargs(profile)) as connection:
        with connection.cursor() as cursor:
            for table in tables:
                sql, bind_values = table_sql_and_values(
                    table["name"], table["columns"], table["types"], table["rows"]
                )
                cursor.execute(sql, bind_values)
                created_tables.append(table_summary(table))
    return created_tables


def demo_tables(run_id: str, loaded_at: datetime) -> list[dict[str, Any]]:
    campaigns = [
        (1, "Welcome Back", "email", "retention", Decimal("1250.00"), "active", loaded_at, run_id),
        (2, "Weekend Waffles", "paid_search", "acquisition", Decimal("2100.00"), "active", loaded_at, run_id),
        (3, "Gift Card Push", "paid_social", "revenue", Decimal("975.50"), "paused", loaded_at, run_id),
        (4, "Loyalty Launch", "email", "loyalty", Decimal("1500.00"), "active", loaded_at, run_id),
        (5, "Brunch Bundle", "email", "revenue", Decimal("800.00"), "active", loaded_at, run_id),
        (6, "Cold Brew Season", "paid_social", "acquisition", Decimal("1800.00"), "active", loaded_at, run_id),
        (7, "Waffle Fest", "paid_search", "acquisition", Decimal("2400.00"), "ended", loaded_at, run_id),
        (8, "Student Discount", "email", "acquisition", Decimal("650.00"), "paused", loaded_at, run_id),
        (9, "Family Pack Promo", "paid_social", "revenue", Decimal("1150.00"), "active", loaded_at, run_id),
        (10, "Referral Rewards", "email", "retention", Decimal("1350.00"), "active", loaded_at, run_id),
    ]

    order_items = [
        (101, 1, 1, "classic_waffle", "Classic Waffle", 2, Decimal("12.00"), 1, loaded_at, run_id),
        (102, 1, 2, "coffee", "Drip Coffee", 1, Decimal("3.50"), 1, loaded_at, run_id),
        (103, 2, 1, "belgian_waffle", "Belgian Waffle", 1, Decimal("14.00"), 2, loaded_at, run_id),
        (104, 3, 1, "gift_card_25", "Gift Card $25", 1, Decimal("25.00"), 3, loaded_at, run_id),
        (105, 4, 1, "vegan_waffle", "Vegan Waffle", 2, Decimal("13.25"), 4, loaded_at, run_id),
        (106, 5, 1, "latte", "Latte", 2, Decimal("5.50"), 2, loaded_at, run_id),
        (107, 6, 1, "seasonal_waffle", "Seasonal Waffle", 1, Decimal("16.00"), 4, loaded_at, run_id),
        (108, 6, 2, "iced_coffee", "Iced Coffee", 1, Decimal("4.25"), 4, loaded_at, run_id),
        (109, 7, 1, "family_pack", "Family Pack", 1, Decimal("45.00"), 7, loaded_at, run_id),
        (110, 8, 1, "student_combo", "Student Combo", 1, Decimal("9.75"), 8, loaded_at, run_id),
    ]

    shipments = [
        (1001, 1, "standard", "shipped", "2026-08-14", "2026-08-16", loaded_at, run_id),
        (1002, 2, "express", "delivered", "2026-08-14", "2026-08-15", loaded_at, run_id),
        (1003, 3, "standard", "returned", "2026-08-15", "2026-08-18", loaded_at, run_id),
        (1004, 4, "standard", "processing", "2026-08-16", None, loaded_at, run_id),
        (1005, 6, "pickup", "delivered", "2026-08-17", "2026-08-17", loaded_at, run_id),
        (1006, 7, "express", "delivered", "2026-08-17", "2026-08-18", loaded_at, run_id),
        (1007, 8, "standard", "in_transit", "2026-08-18", None, loaded_at, run_id),
        (1008, 9, "pickup", "delivered", "2026-08-18", "2026-08-18", loaded_at, run_id),
        (1009, 10, "express", "processing", "2026-08-19", None, loaded_at, run_id),
        (1010, 3, "standard", "returned", "2026-08-19", "2026-08-22", loaded_at, run_id),
    ]

    refunds = [
        (5001, 3, 3, Decimal("25.00"), "customer_return", "approved", "2026-08-18", loaded_at, run_id),
        (5002, 5, 5, Decimal("5.50"), "payment_error", "pending", "2026-08-19", loaded_at, run_id),
        (5003, 6, 6, Decimal("16.00"), "customer_return", "approved", "2026-08-20", loaded_at, run_id),
        (5004, 7, 7, Decimal("4.25"), "duplicate_charge", "approved", "2026-08-20", loaded_at, run_id),
        (5005, 8, 8, Decimal("9.75"), "customer_return", "denied", "2026-08-21", loaded_at, run_id),
        (5006, 9, 9, Decimal("13.25"), "payment_error", "pending", "2026-08-21", loaded_at, run_id),
        (5007, 10, 10, Decimal("45.00"), "customer_return", "approved", "2026-08-22", loaded_at, run_id),
        (5008, 11, 11, Decimal("12.00"), "duplicate_charge", "approved", "2026-08-22", loaded_at, run_id),
        (5009, 12, 12, Decimal("3.50"), "customer_return", "denied", "2026-08-23", loaded_at, run_id),
        (5010, 13, 13, Decimal("14.00"), "payment_error", "approved", "2026-08-23", loaded_at, run_id),
    ]

    return [
        {
            "name": "STATE_DEMO_CAMPAIGNS",
            "columns": ["campaign_id", "campaign_name", "channel", "objective", "budget", "status", "_loaded_at", "_state_demo_run_id"],
            "types": ["number", "varchar", "varchar", "varchar", "number(10,2)", "varchar", "timestamp_tz", "varchar"],
            "rows": campaigns,
        },
        {
            "name": "STATE_DEMO_ORDER_ITEMS",
            "columns": ["order_item_id", "order_id", "line_number", "product_sku", "product_name", "quantity", "unit_price", "campaign_id", "_loaded_at", "_state_demo_run_id"],
            "types": ["number", "number", "number", "varchar", "varchar", "number", "number(10,2)", "number", "timestamp_tz", "varchar"],
            "rows": order_items,
        },
        {
            "name": "STATE_DEMO_SHIPMENTS",
            "columns": ["shipment_id", "order_id", "shipping_method", "shipment_status", "shipped_at", "delivered_at", "_loaded_at", "_state_demo_run_id"],
            "types": ["number", "number", "varchar", "varchar", "date", "date", "timestamp_tz", "varchar"],
            "rows": shipments,
        },
        {
            "name": "STATE_DEMO_REFUNDS",
            "columns": ["refund_id", "order_id", "payment_id", "refund_amount", "refund_reason", "refund_status", "refunded_at", "_loaded_at", "_state_demo_run_id"],
            "types": ["number", "number", "number", "number(10,2)", "varchar", "varchar", "date", "timestamp_tz", "varchar"],
            "rows": refunds,
        },
    ]


def main() -> None:
    parser = argparse.ArgumentParser(description="Create STATE_DEMO source tables in Snowflake.")
    parser.add_argument("--profile", default=PROJECT_PROFILE_NAME, help="dbt profile name to read")
    parser.add_argument("--target", help="dbt profile target to read")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Deprecated no-op; the script now creates the STATE_DEMO tables",
    )
    args = parser.parse_args()

    loaded_at = datetime.now(timezone.utc)
    run_id = loaded_at.strftime("%Y%m%dT%H%M%SZ")
    tables = demo_tables(run_id=run_id, loaded_at=loaded_at)

    try:
        target_name, profile = load_profile(args.profile, args.target)
        tables_created = create_demo_tables(profile, tables)
    except Exception as exc:
        print(f"Failed to create STATE_DEMO tables in {DATABASE}.{SCHEMA}: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    output = {
        "status": "success",
        "profile_name": args.profile,
        "target_name": target_name,
        "destination": {
            "database": DATABASE,
            "schema": SCHEMA,
            "table_prefix": TABLE_PREFIX,
        },
        "run_id": run_id,
        "loaded_at": loaded_at.isoformat(),
        "tables_created": tables_created,
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
