-- Image de carte de chaque unité du jeu.
-- Grain : 1 ligne par unité de main_units.
-- La table unit_variants est indexée par LAND unit : on passe par main_units.land_unit_key.
-- On retient l'image générique (sans faction) ; les images propres à une faction ne concernent pas le PvP
-- (garde-fou : tests/intermediate/assert_no_faction_specific_card_in_pvp.sql).

select
    m.unit_key,
    m.land_unit_key,
    v.unit_card,
    'ui/units/icons/' || v.unit_card || '.png'      as game_file_path,   -- chemin du fichier dans les packs du jeu
    '{{ var("patch") }}'                            as patch
from {{ ref('stg_dump__main_units') }} m
left join {{ ref('stg_dump__unit_variants') }} v
       on v.land_unit_key = m.land_unit_key
      and v.faction_key is null
