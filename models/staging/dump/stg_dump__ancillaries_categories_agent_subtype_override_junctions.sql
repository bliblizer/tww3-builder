-- Nombre d'objets par catégorie (exceptions)
-- Source : db/ancillaries_categories_agent_subtype_override_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "agent_subtype"                                         as agent_subtype_key,
    "ancillary_category"                                    as ancillary_category,
    cast("allowed_per_character" as bigint)                 as allowed_per_character,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillaries_categories_agent_subtype_override_junctions_tables/data__.tsv') }}
