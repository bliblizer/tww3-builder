-- Aucun nom vide ni renvoi de texte non résolu dans ce que le builder affiche.
select 'carte' as objet, card_id as cle, card_name as texte from {{ ref('pvp_roster_cards') }}
where card_name = '' or contains(card_name, '{' || '{tr:') or contains(coalesce(tab_name, ''), '{' || '{tr:')
   or contains(coalesce(ui_group_name, ''), '{' || '{tr:')
union all
select 'option', unit_key, unit_name from {{ ref('pvp_roster_options') }}
where unit_name = '' or contains(unit_name, '{' || '{tr:')
   or contains(concat_ws('|', lore, mark, forest_spirit, other_variant, mount), '{' || '{tr:')
union all
select 'race', race_key, race_name from {{ ref('pvp_races') }}
where race_name = '' or contains(race_name, '{' || '{tr:')
