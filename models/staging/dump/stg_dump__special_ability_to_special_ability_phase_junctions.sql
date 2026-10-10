-- Capacité -> phases d effet
-- Source : db/special_ability_to_special_ability_phase_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    cast("order" as bigint)                                 as order,
    "special_ability"                                       as ability_key,
    cast("target_self" as boolean)                          as target_self,
    cast("target_friends" as boolean)                       as target_friends,
    cast("target_enemies" as boolean)                       as target_enemies,
    "phase"                                                 as phase_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_to_special_ability_phase_junctions_tables/data__.tsv') }}
