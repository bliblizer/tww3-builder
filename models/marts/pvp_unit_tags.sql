-- Forces et faiblesses affichées pour chaque unité jouable (étiquettes du jeu : « Armour-Piercing », « Very Fast »…).
-- Grain : 1 ligne par unité x étiquette. state : positive / very_positive / negative / very_negative.
select distinct
    o.unit_key,
    b.bullet_point_key,
    coalesce(t.resolved_text, b.bullet_point_key)   as tag_name,
    e.state,
    e.sort_order,
    '{{ var("patch") }}'                            as patch
from {{ ref('pvp_roster_options') }} o
join {{ ref('stg_dump__ui_unit_bullet_point_unit_overrides') }} b using (unit_key)
join {{ ref('stg_dump__ui_unit_bullet_point_enums') }} e using (bullet_point_key)
left join {{ ref('stg_loc_texts') }} t on t.loc_key = 'ui_unit_bullet_point_enums_onscreen_name_' || b.bullet_point_key
