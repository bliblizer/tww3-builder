-- Onglets du builder
-- Source : db/ui_unit_group_parents_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as tab_key,
    "icon"                                                  as icon,
    cast("order" as bigint)                                 as tab_order,
    cast("mp_cap" as bigint)                                as mp_cap,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ui_unit_group_parents_tables/data__.tsv') }}
