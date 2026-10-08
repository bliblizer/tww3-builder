-- Sous-groupes du builder -> onglet
-- Source : db/ui_unit_groupings_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as ui_group_key,
    "icon"                                                  as icon,
    "parent_group"                                          as tab_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ui_unit_groupings_tables/data__.tsv') }}
