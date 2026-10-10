-- Détail des sorts, capacités et objets du builder, pour l'info-bulle au survol (comme l'info-bulle du jeu).
-- Grain : 1 ligne par sort / capacité / objet utilisé dans le builder (personnalisation ou capacité innée).
--   description : texte du jeu ; mana, recharge, durée, nombre d'utilisations : unit_special_abilities ;
--   effects     : lignes d'effet, séparées par « | » : effets chiffrés des phases sur les statistiques,
--                 attributs donnés, et lignes d'effet affichées par le jeu (additional_ui_effects).

with keys as (
    select distinct upgrade_key as key, case when upgrade_type = 'item' then 'item' else 'ability' end as kind
    from {{ ref('pvp_character_upgrades') }}
    union
    select distinct trait_key, 'ability' from {{ ref('pvp_unit_traits') }} where kind = 'ability'
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
    where j.ability_key in (select key from keys)
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
    '{{ var("patch") }}'                                           as patch
from keys k
left join {{ ref('stg_dump__unit_special_abilities') }} sa on sa.ability_key = k.key
left join clean nm      on nm.loc_key = 'unit_abilities_onscreen_name_' || k.key
left join clean d       on d.loc_key  = 'unit_abilities_tooltip_text_' || k.key
left join clean nm_item on nm_item.loc_key = 'ancillaries_onscreen_name_' || k.key
left join clean d_item  on d_item.loc_key  = 'ancillaries_colour_text_' || k.key
left join effects ef on ef.ability_key = k.key
left join phase_summary ps on ps.ability_key = k.key
