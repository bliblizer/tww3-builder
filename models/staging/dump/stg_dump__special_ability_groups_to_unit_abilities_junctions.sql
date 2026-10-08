-- Capacités/sorts de chaque groupe
-- Source : db/special_ability_groups_to_unit_abilities_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "special_ability_groups"                                as ability_group_key,
    "unit_special_abilities"                                as ability_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_groups_to_unit_abilities_junctions_tables/data__.tsv') }}
