-- Objets autorisés par catégorie d'agent
-- Source : db/ancillary_to_included_agents_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ancillary"                                             as ancillary_key,
    "agent"                                                 as agent,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillary_to_included_agents_tables/data__.tsv') }}
