-- Montures : unité de base -> unité montée
-- Source : db/units_custom_battle_mounts_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "base_unit"                                             as base_unit_key,
    "mounted_unit"                                          as mounted_unit_key,
    "icon_name"                                             as icon_name,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/units_custom_battle_mounts_tables/data__.tsv') }}
