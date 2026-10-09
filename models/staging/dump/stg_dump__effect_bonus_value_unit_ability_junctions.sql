-- Effet -> capacité ou sort débloqué
-- Source : db/effect_bonus_value_unit_ability_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "effect"                                                as effect_key,
    "bonus_value_id"                                        as bonus_value_id,
    "unit_ability"                                          as ability_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/effect_bonus_value_unit_ability_junctions_tables/data__.tsv') }}
