-- Groupes de caps multijoueur applicables à chaque race (hors caps à 0, déjà traités comme interdictions).
-- Grain : 1 ligne par race x groupe de caps ayant au moins une unité jouable de la race.
--
-- Règles (déduites des données) :
--   - un groupe limite le NOMBRE TOTAL d'unités de ses membres dans l'armée ;
--   - plafond par défaut de la race = ligne propre à la sous-culture si elle existe, sinon ligne globale
--     (aucun groupe n'a les deux au patch 9.0, voir tests) ;
--   - certaines lignes dépendent d'un personnage : voir int_cap_group_overrides.

with caps as (
    select unit_set_key, subculture_key, character_name, cap
    from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }}
    where cap > 0
),

members as (
    select * from {{ ref('int_cap_group_members') }}
),

races as (
    select distinct race_key from members
),

defaults as (
    -- plafond par défaut : ligne de la sous-culture, sinon ligne globale (sans personnage dans les deux cas)
    select r.race_key, c.unit_set_key,
           coalesce(max(c.cap) filter (where c.subculture_key = r.race_key),
                    max(c.cap) filter (where c.subculture_key is null))     as default_cap
    from races r
    join caps c on c.character_name is null and (c.subculture_key is null or c.subculture_key = r.race_key)
    group by r.race_key, c.unit_set_key
),

texts as (
    select loc_key, resolved_text from {{ ref('stg_loc_texts') }}
)

select
    d.race_key,
    d.unit_set_key,
    coalesce(n_sub.resolved_text, n_glob.resolved_text, d.unit_set_key)   as cap_group_name,
    d.default_cap,
    count(m.unit_key)                                                      as nb_member_units,
    '{{ var("patch") }}'                                                   as patch
from defaults d
join members m using (race_key, unit_set_key)
left join texts n_sub  on n_sub.loc_key  = 'unit_set_to_mp_unit_caps_localised_name_' || d.unit_set_key || d.race_key
left join texts n_glob on n_glob.loc_key = 'unit_set_to_mp_unit_caps_localised_name_' || d.unit_set_key
where d.default_cap is not null
group by all
