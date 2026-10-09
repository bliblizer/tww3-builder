-- Unités jouables en PvP membres de chaque groupe de caps, par race.
-- Grain : 1 ligne par race x groupe x unité.
-- Un membre est désigné par sa clé d'unité, ou par sa caste (ex. tous les héros) ; aucune exclusion n'est utilisée.

with race_units as (
    select r.race_key, r.unit_key, r.caste_key
    from {{ ref('int_race_units') }} r
    where r.is_selectable_pvp
),

junctions as (
    select unit_set_key, unit_key, caste_key
    from {{ ref('stg_dump__unit_set_to_unit_junctions') }}
    where unit_set_key in (select unit_set_key from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }} where cap > 0)
)

select distinct ru.race_key, j.unit_set_key, ru.unit_key, '{{ var("patch") }}' as patch
from race_units ru
join junctions j
  on j.unit_key = ru.unit_key
  or (j.unit_key is null and j.caste_key = ru.caste_key)
