-- Cas connus (validés en jeu ou servant de témoins). Renvoie les cas dont le statut calculé diffère de l'attendu.
with expected(faction_key, unit_key, expected_selectable, source) as (
    values
    ('wh_dlc05_wef_wood_elves', 'wh2_dlc16_wef_cha_ancient_treeman_coeddil_0', false, 'validé en jeu (test 1_1.army_setup)'),
    ('wh_dlc05_wef_wood_elves', 'wh_dlc05_wef_cha_durthu_0',                    true,  'validé en jeu (test 1_1.army_setup)'),
    ('wh_main_chs_chaos',       'wh_dlc01_chs_cha_prince_sigvald_the_magnificent', true, 'validé en jeu (wc_test.army_setup)'),
    ('wh2_dlc09_tmb_tomb_kings','wh2_dlc09_tmb_inf_crypt_ghouls',               false, 'témoin : unité VC empruntée par les Tomb Kings'),
    ('wh3_main_kho_khorne',     'wh3_main_kho_mon_spawn_of_khorne_0',           true,  'témoin : statut qui dépend de la faction'),
    ('wh_main_chs_chaos',       'wh3_main_kho_mon_spawn_of_khorne_0',           false, 'témoin : statut qui dépend de la faction')
)
select e.*, s.is_selectable_pvp as computed_selectable
from expected e
left join {{ ref('int_unit_faction_status') }} s using (faction_key, unit_key)
where s.is_selectable_pvp is distinct from e.expected_selectable
