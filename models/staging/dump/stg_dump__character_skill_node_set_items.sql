-- Nœuds de chaque arbre de compétences
-- Source : db/character_skill_node_set_items_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "set"                                                   as node_set_key,
    "item"                                                  as node_key,
    cast("mod_disabled" as boolean)                         as mod_disabled,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/character_skill_node_set_items_tables/data__.tsv') }}
