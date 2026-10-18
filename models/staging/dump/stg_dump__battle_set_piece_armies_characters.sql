-- Personnages des listes d objets de bataille (nom du personnage -> unité)
-- Source : db/battle_set_piece_armies_characters_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "character_name"                                        as character_name,
    cast("character_level" as bigint)                       as character_level,
    cast("forename" as bigint)                              as forename,
    "magic_lore"                                            as magic_lore,
    cast("num_men" as bigint)                               as num_men,
    cast("surname" as bigint)                               as surname,
    "unit_type"                                             as unit_type,
    "agent_type"                                            as agent_type,
    "agent_subtype"                                         as agent_subtype,
    "portrait"                                              as portrait,
    cast("character_model" as bigint)                       as character_model,
    "skillset"                                              as skillset,
    cast("male" as boolean)                                 as male,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/battle_set_piece_armies_characters_tables/data__.tsv') }}
