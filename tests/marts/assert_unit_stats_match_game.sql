-- Statistiques relevées en jeu (captures du panneau d'unité). Renvoie chaque valeur qui diffère.
with expected(unit_key, stat, value) as (
    values
    ('wh_main_dwf_inf_dwarf_warrior_1', 'unit_size', 100), ('wh_main_dwf_inf_dwarf_warrior_1', 'health', 7800),
    ('wh_main_dwf_inf_dwarf_warrior_1', 'armour', 85), ('wh_main_dwf_inf_dwarf_warrior_1', 'leadership', 70),
    ('wh_main_dwf_inf_dwarf_warrior_1', 'speed', 28), ('wh_main_dwf_inf_dwarf_warrior_1', 'melee_attack', 24),
    ('wh_main_dwf_inf_dwarf_warrior_1', 'melee_defence', 30), ('wh_main_dwf_inf_dwarf_warrior_1', 'weapon_strength', 32),
    ('wh_main_dwf_inf_dwarf_warrior_1', 'charge_bonus', 18), ('wh_main_dwf_inf_dwarf_warrior_1', 'spell_resistance', 35),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'unit_size', 100), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'health', 7600),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'armour', 80), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'leadership', 78),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'speed', 28), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'melee_attack', 29),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'melee_defence', 24), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'weapon_strength', 22),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'charge_bonus', 12), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'ammunition', 3),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'range', 55), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'missile_strength', 31),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'spell_resistance', 35)
),
actual as (
    unpivot (select unit_key, unit_size, health, armour, leadership, speed, melee_attack, melee_defence, weapon_strength,
                    charge_bonus, ammunition, range, missile_strength, spell_resistance from {{ ref('pvp_unit_stats') }})
    on unit_size, health, armour, leadership, speed, melee_attack, melee_defence, weapon_strength, charge_bonus,
       ammunition, range, missile_strength, spell_resistance
    into name stat value value
)
select e.*, a.value as computed
from expected e left join actual a using (unit_key, stat)
where a.value is distinct from e.value
union all
-- traits attendus : Frenzy (capacité innée), Vanguard Deployment et Hide (forest) (attributs)
select unit_key, trait_name, null, null from (values
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'Frenzy'), ('wh_dlc06_dwf_inf_ekrund_miners_0', 'Vanguard Deployment'),
    ('wh_dlc06_dwf_inf_ekrund_miners_0', 'Hide (forest)'), ('wh_main_dwf_inf_dwarf_warrior_1', 'Hide (forest)')) x(unit_key, trait_name)
where not exists (select 1 from {{ ref('pvp_unit_traits') }} t where t.unit_key = x.unit_key and t.trait_name = x.trait_name)
