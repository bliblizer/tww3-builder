-- Variantes : domaine de magie / marque / esprit…
-- Source : db/units_custom_battle_types_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "alternate_unit"                                        as alternate_unit_key,
    "base_unit"                                             as base_unit_key,
    "type_category"                                         as type_category_key,
    "type_icon"                                             as type_icon,
    cast("show_base_in_unit_list" as boolean)               as show_base_in_unit_list,
    cast("id" as bigint)                                    as type_id,
    "colour"                                                as colour,
    cast("sort_order" as bigint)                            as sort_order,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/units_custom_battle_types_tables/data__.tsv') }}
