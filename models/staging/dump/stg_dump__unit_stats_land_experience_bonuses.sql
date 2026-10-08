-- Coût MP des rangs d'expérience (fixe + multiplicateur)
-- Source : db/unit_stats_land_experience_bonuses_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    cast("xp_level" as bigint)                              as xp_level,
    cast("fatigue" as bigint)                               as fatigue,
    cast("mp_fixed_cost" as bigint)                         as mp_fixed_cost,
    cast("mp_experience_cost_multiplier" as decimal(18,4))  as mp_experience_cost_multiplier,
    cast("additional_melee_cp" as decimal(18,4))            as additional_melee_cp,
    cast("additional_missile_cp" as decimal(18,4))          as additional_missile_cp,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_stats_land_experience_bonuses_tables/data__.tsv') }}
