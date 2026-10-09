-- Groupes de rareté (common / uncommon / rare / unique)
-- Source : db/ancillary_uniqueness_groupings_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "group_key"                                             as uniqueness_group_key,
    cast("uniqueness_max" as bigint)                        as uniqueness_max,
    cast("uniqueness_min" as bigint)                        as uniqueness_min,
    "ui_state"                                              as ui_state,
    cast("fusable" as boolean)                              as fusable,
    "col_hex"                                               as col_hex,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillary_uniqueness_groupings_tables/data__.tsv') }}
