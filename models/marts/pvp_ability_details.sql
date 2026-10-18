-- Détail des sorts, capacités et objets du builder, pour l'info-bulle au survol (comme l'info-bulle du jeu).
-- Grain : 1 ligne par sort / capacité / objet utilisé dans le builder (personnalisation ou capacité innée).
--   description : texte du jeu ; mana, recharge, durée, nombre d'utilisations : unit_special_abilities ;
--   effects     : lignes d'effet, séparées par « | » : effets chiffrés des phases sur les statistiques,
--                 attributs donnés, et lignes d'effet affichées par le jeu (additional_ui_effects).
--   dégâts      : projectile lancé (activated_projectile), bombardement (projectile_bombardments) ou vortex (battle_vortexs) ;
--                 dmg_base / dmg_ap = dégâts d'un impact (explosion comprise), dmg_hits = nombre d'impacts,
--                 dmg_duration = durée d'un vortex ; range = portée de lancement (target_intercept_range).

with keys as (
    select distinct upgrade_key as key, case when upgrade_type = 'item' then 'item' else 'ability' end as kind
    from {{ ref('pvp_character_upgrades') }}
    union
    select distinct trait_key, 'ability' from {{ ref('pvp_unit_traits') }} where kind = 'ability'
),

item_ability as (
    -- un objet donne le plus souvent une capacité (ancillary_to_effects -> effet -> capacité) : ses détails
    -- (mana, recharge, dégâts, effets) sont ceux de cette capacité
    select ae.ancillary as item_key, min(ej.ability_key) as ability_key
    from {{ ref('stg_dump__ancillary_to_effects') }} ae
    join {{ ref('stg_dump__effect_bonus_value_unit_ability_junctions') }} ej on ej.effect_key = ae.effect
    where ae.ancillary in (select key from keys where kind = 'item')
    group by ae.ancillary
),

src as (   -- clé dont on lit les détails : la capacité de l'objet, sinon la clé elle-même
    select k.key, k.kind, coalesce(ia.ability_key, k.key) as akey
    from keys k left join item_ability ia on ia.item_key = k.key
),

texts as (select loc_key, resolved_text from {{ ref('stg_loc_texts') }}),

clean as (
    -- texte affichable : sans balises d'image du jeu ([[img:…]][[/img]]) ni balises de mise en forme
    select loc_key, trim(regexp_replace(regexp_replace(resolved_text, '\[\[img:[^\]]*\]\]\[\[/img\]\]', '', 'g'),
                                        '\[\[/?[a-z_]+(:[^\]]*)?\]\]', '', 'g')) as txt
    from texts
),

phases as (
    select j.ability_key, j."order" as phase_order, j.target_self, j.target_friends, j.target_enemies, p.*
    from {{ ref('stg_dump__special_ability_to_special_ability_phase_junctions') }} j
    join {{ ref('stg_dump__special_ability_phases') }} p using (phase_key)
    where j.ability_key in (select akey from src)
),

effect_lines as (
    -- 1. effets chiffrés : « +32 Bonus vs. Large », « +25% Turn Speed »
    select ph.ability_key, ph.phase_order, 1 as kind_order,
           case se.how
             when 'add'  then (case when se.value >= 0 then '+' else '' end) || regexp_replace(round(se.value, 2)::varchar, '\.0+$|(\.\d*[1-9])0+$', '\1')
             when 'mult' then (case when se.value >= 1 then '+' else '' end) || round((se.value - 1) * 100)::int || '%'
             else '= ' || round(se.value, 2)::varchar
           end || ' ' || coalesce(n.txt, se.stat_key) as line
    from phases ph
    join {{ ref('stg_dump__special_ability_phase_stat_effects') }} se using (phase_key)
    left join clean n on n.loc_key = 'unit_stat_localisations_onscreen_name_' || se.stat_key
    union all
    -- 2. attributs donnés ou retirés : « Gains: Stalk »
    select ph.ability_key, ph.phase_order, 2,
           case when ae.attribute_type = 'negative' then 'Inflicts: ' else 'Gains: ' end
             || coalesce(nullif(split_part(n.txt, '||', 1), ''), ae.attribute_key)
    from phases ph
    join {{ ref('stg_dump__special_ability_phase_attribute_effects') }} ae using (phase_key)
    left join clean n on n.loc_key = 'unit_attributes_bullet_text_' || ae.attribute_key
    union all
    -- 3. lignes d'effet propres au jeu : « Summons a unit of Ushabti »
    select ph.ability_key, ph.phase_order, 3, n.txt
    from phases ph
    join {{ ref('stg_dump__special_ability_phases_to_additional_ui_effects_junctions') }} ue using (phase_key)
    join clean n on n.loc_key = 'unit_abilities_additional_ui_effects_localised_text_' || ue.ui_effect_key
),

effects as (
    select ability_key, string_agg(distinct line, ' | ' order by line) as effects
    from effect_lines where line is not null and line <> '' group by ability_key
),

phase_summary as (
    select ability_key,
           max(duration) filter (where duration > 0)              as phase_duration,
           bool_or(target_enemies)                                 as targets_enemies,
           bool_or(target_friends or target_self)                  as targets_allies,
           max(damage_amount) filter (where damage_amount > 0)     as damage_per_tick,
           bool_or(imbue_magical)                                   as imbue_magical
    from phases group by ability_key
),

proj as (
    -- dégâts d'un projectile : impact + explosion, normaux et perforants ; nombre de projectiles par tir
    select p.projectile_key,
           coalesce(p.damage, 0) + coalesce(e.detonation_damage, 0)                         as dmg_base,
           coalesce(p.ap_damage, 0) + coalesce(e.detonation_damage_ap, 0)                   as dmg_ap,
           coalesce(nullif(p.projectile_number, 0), 1) * coalesce(nullif(p.shots_per_volley, 0), 1)
             * coalesce(nullif(p.burst_size, 0), 1)                                         as hits,
           coalesce(p.is_magical, false) or coalesce(e.is_magical, false)                   as magical,
           coalesce(p.ignition_amount, 0) + coalesce(e.ignition_amount, 0) > 0              as flaming
    from {{ ref('stg_dump__projectiles') }} p
    left join {{ ref('stg_dump__projectiles_explosions') }} e on e.explosion_key = p.explosion_key
),

damage as (
    select sa.ability_key,
           case when v.vortex_key is not null then 'vortex' when pb.bombardment_key is not null then 'bombardment'
                when pa.projectile_key is not null then 'projectile' end                     as dmg_kind,
           coalesce(v.damage, pb_p.dmg_base, pa.dmg_base)                                    as dmg_base,
           coalesce(v.damage_ap, pb_p.dmg_ap, pa.dmg_ap)                                     as dmg_ap,
           coalesce(nullif(v.num_vortexes, 0), pb.num_projectiles * pb_p.hits, pa.hits)      as dmg_hits,
           v.duration                                                                        as dmg_duration,
           coalesce(nullif(v.goal_radius, 0), nullif(v.start_radius, 0), nullif(pb.radius_spread, 0)) as dmg_radius,
           nullif(v.movement_speed, 0)                                                       as dmg_speed,
           coalesce(v.is_magical, pb_p.magical, pa.magical)                                  as dmg_magical,
           coalesce(v.ignition_amount > 0, pb_p.flaming, pa.flaming)                         as dmg_flaming
    from {{ ref('stg_dump__unit_special_abilities') }} sa
    left join proj pa on pa.projectile_key = nullif(sa.activated_projectile, '')
    left join {{ ref('stg_dump__projectile_bombardments') }} pb on pb.bombardment_key = nullif(sa.bombardment, '')
    left join proj pb_p on pb_p.projectile_key = pb.projectile_type
    left join {{ ref('stg_dump__battle_vortexs') }} v on v.vortex_key = nullif(sa.vortex, '')
    where sa.ability_key in (select akey from src)
),

ui_pros_cons as (
    -- points forts et faibles affichés en bas de l'info-bulle du jeu (« Strong vs multiple units »…),
    -- dans l'ordre du jeu : « positive|texte » ou « negative|texte », séparés par « ¦ »
    select j.ability as ability_key,
           string_agg(e.effect_state || '|' || n.txt, ' ¦ ' order by e.sort_order, n.txt) as pros_cons
    from {{ ref('stg_dump__unit_abilities_to_additional_ui_effects_juncs') }} j
    join {{ ref('stg_dump__unit_abilities_additional_ui_effects') }} e on e.key = j.effect
    join clean n on n.loc_key = 'unit_abilities_additional_ui_effects_localised_text_' || j.effect
    where j.ability in (select akey from src) and nullif(n.txt, '') is not null
    group by j.ability
),

targets as (
    -- unités touchées, comme la ligne « Affected units » du jeu
    select sa.ability_key,
           nullif(concat_ws(', ',
             case when sa.target_enemies then 'enemies' || case when sa.num_effected_enemy_units > 0 then ' (max: ' || sa.num_effected_enemy_units || ')' else '' end end,
             case when sa.target_friends then 'allies' || case when sa.num_effected_friendly_units > 0 then ' (max: ' || sa.num_effected_friendly_units || ')' else '' end end,
             case when sa.target_self or sa.affect_self then 'self' end), '')                as affects,
           case when sa.effect_range > 0 then sa.effect_range end                        as area_radius
    from {{ ref('stg_dump__unit_special_abilities') }} sa
    where sa.ability_key in (select akey from src)
)

select
    k.key, k.kind,
    coalesce(nm.txt, nm_item.txt, k.key)                           as name,
    coalesce(d.txt, d_item.txt)                                    as description,
    case when sa.mana_cost > 0 then sa.mana_cost end               as mana_cost,
    case when sa.recharge_time > 0 then sa.recharge_time end       as cooldown,   -- -1 dans le jeu = sans objet
    case when sa.active_time > 0 then sa.active_time
         when ps.phase_duration > 0 then ps.phase_duration end     as duration,
    case when sa.num_uses > 0 then sa.num_uses end                 as uses,
    coalesce(sa.passive, false)                                    as is_passive,
    ps.targets_enemies, ps.targets_allies,
    ef.effects,
    case when sa.target_intercept_range > 0 then sa.target_intercept_range end   as range,
    dm.dmg_kind,
    case when coalesce(dm.dmg_base, 0) + coalesce(dm.dmg_ap, 0) > 0 then dm.dmg_base end  as dmg_base,
    case when coalesce(dm.dmg_base, 0) + coalesce(dm.dmg_ap, 0) > 0 then dm.dmg_ap end    as dmg_ap,
    case when coalesce(dm.dmg_base, 0) + coalesce(dm.dmg_ap, 0) > 0 then dm.dmg_hits end  as dmg_hits,
    case when dm.dmg_duration > 0 then dm.dmg_duration end                       as dmg_duration,
    coalesce(dm.dmg_magical, false)                                             as dmg_magical,
    coalesce(dm.dmg_flaming, false)                                             as dmg_flaming,
    ps.damage_per_tick,
    ty.txt                                                         as ability_type,   -- « Wind », « Direct damage »…
    dm.dmg_radius, dm.dmg_speed,                                                     -- rayon et vitesse d'un vortex / bombardement
    tg.affects, tg.area_radius,                                                      -- unités touchées, rayon de la zone d'effet
    pc.pros_cons,
    '{{ var("patch") }}'                                           as patch
from src k
left join {{ ref('stg_dump__unit_special_abilities') }} sa on sa.ability_key = k.akey
left join {{ ref('stg_dump__unit_abilities') }} ua on ua.ability_key = k.akey
left join clean ty on ty.loc_key = 'unit_ability_types_onscreen_name_' || ua.type
left join ui_pros_cons pc on pc.ability_key = k.akey
left join targets tg on tg.ability_key = k.akey
left join clean nm      on nm.loc_key = 'unit_abilities_onscreen_name_' || k.key
left join clean d       on d.loc_key  = 'unit_abilities_tooltip_text_' || k.key
left join clean nm_item on nm_item.loc_key = 'ancillaries_onscreen_name_' || k.key
left join clean d_item  on d_item.loc_key  = 'ancillaries_colour_text_' || k.key
left join effects ef on ef.ability_key = k.akey
left join phase_summary ps on ps.ability_key = k.akey
left join damage dm on dm.ability_key = k.akey
