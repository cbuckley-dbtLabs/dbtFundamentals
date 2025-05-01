-- models/country_codes_model.sql

WITH country_codes AS (
    SELECT *
    FROM {{ ref('countries') }}
)

SELECT
    Country_Name,
    ISO
FROM country_codes