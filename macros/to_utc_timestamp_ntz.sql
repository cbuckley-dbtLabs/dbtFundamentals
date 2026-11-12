{% macro to_utc_timestamp_ntz(column_name) %}
    convert_timezone('UTC', {{ column_name }})::timestamp_ntz(6)
{% endmacro %}
