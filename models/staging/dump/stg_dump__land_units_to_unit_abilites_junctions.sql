-- Capacités natives de chaque land unit
-- Source : db/land_units_to_unit_abilites_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ability"                                               as ability_key,
    "land_unit"                                             as land_unit_key,
    "culture"                                               as culture_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/land_units_to_unit_abilites_junctions_tables/data__.tsv') }}
