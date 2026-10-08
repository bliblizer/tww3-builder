-- Plafonds MP par groupe (0 = interdit)
-- Source : db/unit_set_to_mp_unit_caps_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "unit_set"                                              as unit_set_key,
    "subculture"                                            as subculture_key,
    "character_name"                                        as character_name,
    cast("cap" as bigint)                                   as cap,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_set_to_mp_unit_caps_tables/data__.tsv') }}
