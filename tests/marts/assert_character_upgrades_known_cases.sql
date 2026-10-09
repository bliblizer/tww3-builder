-- Personnalisation : cas vérifiés.
-- 1. Panneau de Neferata sur Destrier Infernal (capture d'écran du jeu) : 6 sorts, 6 capacités, 3 objets, coûts visibles conformes.
-- 2. Fichiers .army_setup : tout élément coché est soit proposé (pvp_character_upgrades), soit une capacité innée
--    de l'unité (non sélectionnable, enregistrée quand même dans le fichier).
with nef as (
    select * from {{ ref('pvp_character_upgrades') }}
    where race_key = 'wh_main_sc_vmp_vampire_counts' and unit_key = 'wh3_dlc29_vmp_cha_neferata_hellsteed_mp'
),
expected(upgrade_type, upgrade_name, cost) as (
    values ('spell', 'Invocation of Nehek', null), ('spell', 'Spirit Leech', null), ('spell', 'Raise Dead', null),
           ('spell', 'The Withering', null), ('spell', 'Wind of Death', null), ('spell', 'Pit of Shades', null),
           ('ability', 'The Curse of Undeath', 100), ('ability', 'Life Leeching', 100), ('ability', 'Smoke & Mirrors', 100),
           ('ability', 'The Hunger', 150), ('ability', 'Bastet', 150), ('ability', 'Shadowblood', 200),
           ('item', 'Akmet-kar, the Dagger of Jet', 200), ('item', 'Ruby of Lahmia', 200), ('item', 'Aken-seth, the Staff of Pain', 200)
),
neferata_diff as (
    select 'Neferata : manquant' as ecart, upgrade_name as detail from (select upgrade_type, upgrade_name, cost from expected except select upgrade_type, upgrade_name, cost from nef)
    union all
    select 'Neferata : en trop', upgrade_name from (select upgrade_type, upgrade_name, cost from nef except select upgrade_type, upgrade_name, cost from expected)
),
fixture as (
    select s.army_id, s.slot, s.upgrade_key, a.race_key, a.unit_key
    from {{ ref('test_army_selected_upgrades') }} s
    join {{ ref('test_armies') }} a using (army_id, slot)
),
innate as (
    select m.unit_key, j.ability_key
    from {{ ref('stg_dump__main_units') }} m
    join {{ ref('stg_dump__land_units_to_unit_abilites_junctions') }} j using (land_unit_key)
),
fixture_diff as (
    select 'fichier .army_setup : élément inexpliqué', f.army_id || ' / ' || f.unit_key || ' / ' || f.upgrade_key
    from fixture f
    where not exists (select 1 from {{ ref('int_character_upgrades') }} u
                      where u.race_key = f.race_key and u.unit_key = f.unit_key and u.upgrade_key = f.upgrade_key)
      and not exists (select 1 from innate i where i.unit_key = f.unit_key and i.ability_key = f.upgrade_key)
)
select * from neferata_diff
union all
select * from fixture_diff
