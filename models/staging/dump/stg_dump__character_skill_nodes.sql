-- Nœud -> compétence
-- Source : db/character_skill_nodes_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as node_key,
    "campaign_key"                                          as campaign_key,
    "character_skill_key"                                   as skill_key,
    "faction_key"                                           as faction_key,
    cast("indent" as bigint)                                as indent,
    cast("tier" as bigint)                                  as tier,
    "subculture"                                            as subculture_key,
    cast("points_on_creation" as bigint)                    as points_on_creation,
    cast("required_num_parents" as bigint)                  as required_num_parents,
    cast("visible_in_ui" as boolean)                        as visible_in_ui,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/character_skill_nodes_tables/data__.tsv') }}
