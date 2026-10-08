-- Factions de bataille personnalisée
-- Source : db/custom_battle_factions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "faction_key"                                           as faction_key,
    cast("sort_order" as bigint)                            as sort_order,
    cast("culture_sort_order" as bigint)                    as culture_sort_order,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/custom_battle_factions_tables/data__.tsv') }}
