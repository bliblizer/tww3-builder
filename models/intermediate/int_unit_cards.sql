-- Regroupement des unités en cartes du builder : 1 carte = 1 unité de base + ses options (variantes, montures).
-- Grain : 1 ligne par race x unité (toutes les unités du builder, sélectionnables ou non).
--
-- Règle : deux unités d'une même race sont sur la même carte si l'une est la monture ou la variante de l'autre
-- (tables units_custom_battle_mounts / units_custom_battle_types), de proche en proche.
-- Unité racine de la carte (donne nom, onglet, sous-groupe) : la première selon
--   1. à pied plutôt que montée   2. base de variante affichée dans le jeu (show_base_in_unit_list)
--   3. base de variante plutôt que variante   4. la moins chère   5. ordre alphabétique de la clé

with recursive race_units as (
    select * from {{ ref('int_race_units') }}
),

labels as (
    select * from {{ ref('int_unit_option_labels') }}
),

edges as (
    -- liens entre unités d'une même race (dans les deux sens)
    select r1.race_key, m.base_unit_key as a, m.mounted_unit_key as b
    from {{ ref('stg_dump__units_custom_battle_mounts') }} m
    join race_units r1 on r1.unit_key = m.base_unit_key
    join race_units r2 on r2.unit_key = m.mounted_unit_key and r2.race_key = r1.race_key
    union
    select r1.race_key, t.base_unit_key, t.alternate_unit_key
    from {{ ref('stg_dump__units_custom_battle_types') }} t
    join race_units r1 on r1.unit_key = t.base_unit_key
    join race_units r2 on r2.unit_key = t.alternate_unit_key and r2.race_key = r1.race_key
    where t.base_unit_key <> t.alternate_unit_key
),

undirected as (
    select race_key, a, b from edges
    union
    select race_key, b, a from edges
),

reach(race_key, unit_key, reached_key) as (
    -- toutes les unités atteignables de proche en proche (UNION : s'arrête quand plus rien de nouveau)
    select race_key, unit_key, unit_key from race_units
    union
    select r.race_key, r.unit_key, u.b
    from reach r
    join undirected u on u.race_key = r.race_key and u.a = r.reached_key
),

components as (
    -- identifiant technique de la composante = plus petite clé atteignable
    select race_key, unit_key, min(reached_key) as component_key
    from reach group by race_key, unit_key
),

type_bases as (
    select
        base_unit_key as unit_key,
        bool_or(show_base_in_unit_list and base_unit_key = alternate_unit_key) as shown_as_base
    from {{ ref('stg_dump__units_custom_battle_types') }}
    group by base_unit_key
),

ranked as (
    select
        c.race_key, c.unit_key, c.component_key,
        row_number() over (
            partition by c.race_key, c.component_key
            order by
                (l.mount_name is not null and l.foot_unit_key <> c.unit_key),   -- 1. à pied d'abord
                coalesce(tb.shown_as_base, false) = false,                      -- 2. base affichée
                tb.unit_key is null,                                            -- 3. base de variante
                ru.multiplayer_cost,                                            -- 4. la moins chère
                c.unit_key                                                      -- 5. clé
        ) as root_rank
    from components c
    join race_units ru using (race_key, unit_key)
    left join labels l using (unit_key)
    left join type_bases tb using (unit_key)
),

roots as (
    select r.race_key, r.component_key, r.unit_key as root_unit_key, ru.unit_name as root_unit_name,
           l.lore, l.mark, l.forest_spirit, l.other_variant
    from ranked r
    join race_units ru using (race_key, unit_key)
    left join labels l using (unit_key)
    where r.root_rank = 1
),

card_names as (
    -- nom de carte = nom de l'unité racine sans la (ou les) parenthèse(s) finale(s) de ses variantes
    -- ex. « Spellweaver (Beasts) » -> « Spellweaver »
    select
        race_key, component_key, root_unit_key,
        {% set cols = ['lore', 'mark', 'forest_spirit', 'other_variant'] %}
        {% set ns = namespace(expr='root_unit_name') %}
        {% for _ in range(2) %}{% for c in cols %}
        {% set ns.expr = "regexp_replace(" ~ ns.expr ~ ", '\\s*\\(' || regexp_escape(coalesce(" ~ c ~ ", chr(1))) || '\\)\\s*$', '')" %}
        {% endfor %}{% endfor %}
        {{ ns.expr }} as card_name
    from roots
)

select
    ru.race_key,
    ro.race_key || '|' || ro.root_unit_key                    as card_id,
    ro.root_unit_key,
    ro.card_name,
    ru.unit_key,
    ru.unit_key = ro.root_unit_key                            as is_root,
    ru.unit_name,
    -- libellé de monture seulement si la version à pied est aussi dans la race
    case when exists (select 1 from race_units b where b.race_key = ru.race_key and b.unit_key = l.mount_base_unit_key)
         then l.mount_name end                                as mount_name,
    l.lore,
    l.mark,
    l.forest_spirit,
    l.other_variant,
    ru.is_selectable_pvp,
    ru.is_general_unit,
    ru.is_general_unit_pvp,
    ru.multiplayer_cost,
    ru.caste_key,
    ru.ui_group_key,
    ru.tab_key,
    ru.faction_keys,
    ru.faction_keys_pvp,
    ru.blocking_reasons,
    '{{ var("patch") }}'                                      as patch
from race_units ru
join ranked rk using (race_key, unit_key)
join card_names ro on ro.race_key = rk.race_key and ro.component_key = rk.component_key
left join labels l using (unit_key)
