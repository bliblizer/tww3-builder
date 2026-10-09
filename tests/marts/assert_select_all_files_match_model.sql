-- Fichiers .army_setup enregistrés avec « Tout sélectionner » : pour chaque personnage, les éléments sélectionnables
-- du modèle (pvp_character_upgrades) doivent être EXACTEMENT ceux du fichier, une fois retirées les capacités innées
-- (non sélectionnables, que le jeu enregistre quand même).
with chars as (
    select a.army_id, a.slot, a.race_key, a.unit_key
    from {{ ref('test_armies') }} a
    join {{ ref('test_army_all_selected') }} s using (army_id)
    where exists (select 1 from {{ ref('pvp_roster_options') }} o
                  where o.race_key = a.race_key and o.unit_key = a.unit_key and o.role in ('lord', 'hero'))
),
innate as (
    select m.unit_key, j.ability_key
    from {{ ref('stg_dump__main_units') }} m
    join {{ ref('stg_dump__land_units_to_unit_abilites_junctions') }} j using (land_unit_key)
),
file_set as (
    select c.army_id, c.slot, c.race_key, c.unit_key, s.upgrade_key
    from chars c join {{ ref('test_army_selected_upgrades') }} s using (army_id, slot)
    where not exists (select 1 from innate i where i.unit_key = c.unit_key and i.ability_key = s.upgrade_key)
       or exists (select 1 from {{ ref('pvp_character_upgrades') }} u where u.race_key = c.race_key and u.unit_key = c.unit_key
                  and u.upgrade_key = s.upgrade_key)
),
model_set as (
    select c.army_id, c.slot, c.race_key, c.unit_key, u.upgrade_key
    from chars c join {{ ref('pvp_character_upgrades') }} u using (race_key, unit_key)
)
select 'dans le fichier, absent du modèle' as ecart, * from (select * from file_set except select * from model_set)
union all
select 'dans le modèle, absent du fichier', * from (select * from model_set except select * from file_set)
