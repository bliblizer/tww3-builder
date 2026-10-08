-- Chaque faction du jeu rattachée à sa race.
-- En PvP, le joueur choisit une race (= sous-culture du jeu : Dark Elves, Warriors of Chaos…), pas une faction.
-- Grain : 1 ligne par faction (toutes les factions du jeu, pas seulement celles du builder).

with factions as (
    select faction_key, subculture_key
    from {{ ref('stg_dump__factions') }}
),

subcultures as (
    select subculture_key, culture_key
    from {{ ref('stg_dump__cultures_subcultures') }}
),

texts as (
    select loc_key, resolved_text
    from {{ ref('stg_loc_texts') }}
),

builder_factions as (
    -- factions qui ont au moins une unité dans le builder de bataille
    select distinct faction_key
    from {{ ref('stg_dump__units_custom_battle_permissions') }}
)

select
    f.faction_key,
    faction_name.resolved_text                         as faction_name,
    f.subculture_key                                   as race_key,
    race_name.resolved_text                            as race_name,
    s.culture_key,
    b.faction_key is not null                          as has_builder_units,
    '{{ var("patch") }}'                               as patch
from factions f
left join subcultures s       on s.subculture_key = f.subculture_key
left join texts faction_name  on faction_name.loc_key = 'factions_screen_name_' || f.faction_key
left join texts race_name     on race_name.loc_key = 'cultures_subcultures_name_' || f.subculture_key
left join builder_factions b  on b.faction_key = f.faction_key
