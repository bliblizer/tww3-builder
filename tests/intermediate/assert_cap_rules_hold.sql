-- Hypothèses sur lesquelles reposent les caps du builder. Si un patch les casse, la règle est à revoir.
--   1. aucun groupe n'a à la fois une ligne globale et une ligne propre à une sous-culture
--   2. toute unité jouable appartient à au moins un groupe (au minimum son plafond individuel)
select 'groupe global ET sous-culture' as hypothese_cassee, unit_set_key as detail
from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }}
where cap > 0 and character_name is null
group by unit_set_key
having bool_or(subculture_key is null) and bool_or(subculture_key is not null)
union all
select 'unité jouable sans groupe', o.race_key || '|' || o.unit_key
from {{ ref('pvp_roster_options') }} o
where not exists (select 1 from {{ ref('pvp_cap_group_members') }} m where m.race_key = o.race_key and m.unit_key = o.unit_key)
