-- Cas connus du roster PvP. Renvoie une ligne par attente non respectée.
with cards as (select * from {{ ref('pvp_roster_cards') }}),
options as (select * from {{ ref('pvp_roster_options') }}),
checks as (
    -- Spellweaver (Wood Elves) : 1 carte, 5 domaines x 4 montures = 20 options
    select 'Spellweaver : 20 options' as attente,
           (select nb_options = 20 and has_variant_choice and has_mount_choice
            from cards where card_id = 'wh_dlc05_sc_wef_wood_elves|wh2_dlc16_wef_cha_spellweaver_beasts_0') as ok
    union all
    select 'Spellweaver : 5 domaines et 4 montures',
           (select count(distinct lore) = 5 and count(distinct mount) = 4
            from options where card_id = 'wh_dlc05_sc_wef_wood_elves|wh2_dlc16_wef_cha_spellweaver_beasts_0')
    union all
    -- Coeddil : interdit en PvP (validé en jeu) -> absent du roster
    select 'Coeddil absent du roster PvP',
           not exists (select 1 from options where unit_key = 'wh2_dlc16_wef_cha_ancient_treeman_coeddil_0')
    union all
    -- Ancient Treeman : seule l'option Athel Loren est jouable -> plus de choix d'esprit, coût unique
    select 'Ancient Treeman : 1 option, pas de choix',
           (select nb_options = 1 and not has_variant_choice and min_cost = max_cost
            from cards where race_key = 'wh_dlc05_sc_wef_wood_elves' and card_name = 'Ancient Treeman')
    union all
    -- Chaos Lord of Khorne : toutes ses options portent la même marque -> pas de faux choix de variante
    select 'Chaos Lord of Khorne : pas de choix de variante',
           (select bool_and(not has_variant_choice) from cards where card_name = 'Chaos Lord of Khorne')
    union all
    -- Chaos Sorcerer Lord (Warriors of Chaos) : domaine + marque + monture sur une seule carte
    select 'Chaos Sorcerer Lord : domaine, marque et monture',
           (select count(distinct lore) > 1 and count(distinct mark) > 1 and count(distinct mount) > 1
            from options o join cards c using (card_id)
            where c.race_key = 'wh_main_sc_chs_chaos' and c.root_unit_key = 'wh_dlc01_chs_cha_chaos_sorcerer_lord_death_0')
    union all
    -- personnages « héros » en campagne mais lords en PvP : onglet Lords (validé en jeu)
    select 'Drycha, Vlad, Isabella, Great Shaman-Sorcerers dans l''onglet Lords',
           (select count(*) = 0 from cards
            where (card_name in ('Drycha', 'Vlad von Carstein', 'Isabella von Carstein') or card_name like 'Great Shaman-Sorcerer%')
              and tab_key <> 'commander')
    union all
    -- compositions sauvegardées en jeu : les unités jouables doivent être dans le roster de leur race
    select 'compo wc_test.army_setup (Warriors of Chaos) : 7 unités jouables',
           (select count(*) = 7 from options where race_key = 'wh_main_sc_chs_chaos' and unit_key in (
               'wh3_dlc29_chs_cha_bloab_bilespurter', 'wh3_dlc29_chs_cha_orghotts_whippermaw', 'wh3_dlc29_chs_mon_basilisk',
               'wh3_main_sla_cav_hellstriders_0', 'wh_dlc01_chs_cha_prince_sigvald_the_magnificent',
               'wh_main_chs_inf_chaos_marauders_0', 'wh_main_chs_inf_chaos_marauders_1'))
    union all
    select 'compo 1_1.army_setup (Wood Elves) : 3 unités jouables (Coeddil exclu)',
           (select count(*) = 3 from options where race_key = 'wh_dlc05_sc_wef_wood_elves' and unit_key in (
               'wh2_dlc16_wef_inf_dryads_ror_0', 'wh_dlc05_wef_cha_durthu_0', 'wh_dlc05_wef_inf_wardancers_1'))
)
select attente from checks where ok is not true
