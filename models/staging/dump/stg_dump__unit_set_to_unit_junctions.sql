-- Composition des groupes de caps
-- Source : db/unit_set_to_unit_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "unit_caste"                                            as caste_key,
    "unit_category"                                         as unit_category_key,
    "unit_class"                                            as unit_class_key,
    "unit_record"                                           as unit_key,
    "unit_set"                                              as unit_set_key,
    cast("exclude" as boolean)                              as exclude,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_set_to_unit_junctions_tables/data__.tsv') }}
