-- Étiquettes forces/faiblesses par unité (phase ultérieure)
-- Source : db/ui_unit_bullet_point_unit_overrides_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "bullet_point"                                          as bullet_point_key,
    "unit_key"                                              as unit_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ui_unit_bullet_point_unit_overrides_tables/data__.tsv') }}
