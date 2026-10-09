-- Arbre de compétences de chaque type de personnage
-- Source : db/character_skill_node_sets_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as node_set_key,
    "agent_key"                                             as agent_key,
    cast("for_army" as boolean)                             as for_army,
    "faction_key"                                           as faction_key,
    "subculture"                                            as subculture,
    cast("for_navy" as boolean)                             as for_navy,
    "campaign_key"                                          as campaign_key,
    "agent_subtype_key"                                     as agent_subtype_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/character_skill_node_sets_tables/data__.tsv') }}
