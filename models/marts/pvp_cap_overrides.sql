-- Plafonds spéciaux selon les personnages présents dans l'armée (général ou héros, voir int_cap_group_overrides).
-- Plafond effectif d'un groupe = max(plafond par défaut, plafonds spéciaux des cartes présentes dans l'armée).
-- Grain : 1 ligne par race x groupe x carte de personnage. Seules les lignes rattachées à une carte sont gardées.
-- Plusieurs character_name peuvent tomber sur la même carte (variantes d'un même personnage) : ils ont
-- alors le même plafond (vérifié par tests/marts/assert_cap_overrides_consistent.sql).
select
    o.race_key,
    o.unit_set_key,
    o.general_card_id,
    string_agg(o.character_name, ' | ' order by o.character_name)   as character_names,
    max(o.cap)                                                      as cap,
    any_value(o.patch)                                              as patch
from {{ ref('int_cap_group_overrides') }} o
join {{ ref('int_cap_groups') }} g using (race_key, unit_set_key)
where o.general_card_id is not null
group by o.race_key, o.unit_set_key, o.general_card_id
