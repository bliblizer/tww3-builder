-- Attributs d unités
-- Source : db/unit_attributes_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as attribute_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_attributes_tables/data__.tsv') }}
