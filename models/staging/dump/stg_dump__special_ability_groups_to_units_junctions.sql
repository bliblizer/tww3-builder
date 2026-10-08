-- Groupes de capacités par unité
-- Source : db/special_ability_groups_to_units_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ability_group"                                         as ability_group_key,
    "unit"                                                  as unit_key,
    cast("group_page_order" as bigint)                      as group_page_order,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_groups_to_units_junctions_tables/data__.tsv') }}
