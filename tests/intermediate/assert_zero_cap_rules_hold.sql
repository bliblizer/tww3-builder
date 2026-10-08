-- Hypothèses sur lesquelles repose int_unit_faction_status. Si un patch les casse, la règle de blocage est à revoir.
--   1. aucun cap à 0 n'est propre à un personnage (character_name)
--   2. aucun membre d'un groupe à 0 n'utilise le mécanisme d'exclusion
--   3. les membres d'un groupe à 0 sont désignés par unité ou par caste (jamais par catégorie ou classe)
with zero_caps as (
    select * from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }} where cap = 0
)
select 'cap à 0 propre à un personnage' as hypothese_cassee, unit_set_key, character_name as detail
from zero_caps where character_name is not null
union all
select 'exclusion dans un groupe à 0', j.unit_set_key, coalesce(j.unit_key, j.caste_key)
from {{ ref('stg_dump__unit_set_to_unit_junctions') }} j
join zero_caps z using (unit_set_key)
where j.exclude
union all
select 'membre désigné par catégorie ou classe', j.unit_set_key, coalesce(j.unit_category_key, j.unit_class_key)
from {{ ref('stg_dump__unit_set_to_unit_junctions') }} j
join zero_caps z using (unit_set_key)
where j.unit_key is null and j.caste_key is null
