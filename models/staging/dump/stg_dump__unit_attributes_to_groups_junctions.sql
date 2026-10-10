-- Attributs de chaque groupe d attributs (land_units.attribute_group)
-- Source : db/unit_attributes_to_groups_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "attribute"                                             as attribute_key,
    "attribute_group"                                       as attribute_group,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_attributes_to_groups_junctions_tables/data__.tsv') }}
