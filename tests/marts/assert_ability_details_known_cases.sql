-- Info-bulles : cas vérifiables dans les données du jeu.
select 'Frenzy : effets attendus' as cas from {{ ref('pvp_ability_details') }}
where key = 'wh_main_unit_passive_frenzy' and not (effects like '%+10 Melee Attack%' and effects like '%Immune to Psychology%')
union all
select 'Wind of Death : mana 15, recharge 44' from {{ ref('pvp_ability_details') }}
where key = 'wh_main_spell_vampires_wind_of_death' and not (mana_cost = 15 and cooldown = 44)
union all
select 'Frenzy : passif sans recharge' from {{ ref('pvp_ability_details') }}
where key = 'wh_main_unit_passive_frenzy' and not (is_passive and cooldown is null)
