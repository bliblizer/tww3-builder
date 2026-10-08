-- Objets autorisés par type de personnage
-- Source : db/ancillaries_included_agent_subtypes_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "agent_subtype"                                         as agent_subtype_key,
    "ancillary"                                             as ancillary_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillaries_included_agent_subtypes_tables/data__.tsv') }}
