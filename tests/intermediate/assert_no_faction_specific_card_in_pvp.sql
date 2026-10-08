-- Garde-fou : int_unit_card_images ignore les images propres à une faction.
-- Si un patch ajoute une image propre à une faction pour une unité jouable en PvP, ce test échoue
-- et il faudra choisir l'image faction par faction.
select v.faction_key, s.unit_key, v.unit_card
from {{ ref('stg_dump__unit_variants') }} v
join {{ ref('stg_dump__main_units') }} m on m.land_unit_key = v.land_unit_key
join {{ ref('int_unit_faction_status') }} s on s.unit_key = m.unit_key and s.faction_key = v.faction_key
where v.faction_key is not null and s.is_selectable_pvp
