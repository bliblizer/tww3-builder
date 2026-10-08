-- Définition des étiquettes (phase ultérieure)
-- Source : db/ui_unit_bullet_point_enums_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as bullet_point_key,
    "state"                                                 as state,
    cast("sort_order" as bigint)                            as sort_order,
    "icon_path"                                             as icon_path,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ui_unit_bullet_point_enums_tables/data__.tsv') }}
