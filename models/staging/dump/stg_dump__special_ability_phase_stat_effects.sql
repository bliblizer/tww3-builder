-- Effets chiffrés des phases sur les statistiques
-- Source : db/special_ability_phase_stat_effects_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "phase"                                                 as phase_key,
    "stat"                                                  as stat_key,
    cast("value" as decimal(18,4))                          as value,
    "how"                                                   as how,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_phase_stat_effects_tables/data__.tsv') }}
