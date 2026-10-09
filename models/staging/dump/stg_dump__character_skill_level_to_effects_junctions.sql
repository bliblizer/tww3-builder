-- Compétence -> effets
-- Source : db/character_skill_level_to_effects_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "character_skill_key"                                   as skill_key,
    "effect_key"                                            as effect_key,
    cast("level" as bigint)                                 as level,
    "effect_scope"                                          as effect_scope,
    cast("value" as decimal(18,4))                          as value,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/character_skill_level_to_effects_junctions_tables/data__.tsv') }}
