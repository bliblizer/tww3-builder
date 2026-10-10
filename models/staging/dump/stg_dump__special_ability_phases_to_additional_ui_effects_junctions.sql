-- Lignes d effet affichées dans l info-bulle du jeu
-- Source : db/special_ability_phases_to_additional_ui_effects_junctions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "effect"                                                as ui_effect_key,
    "special_ability_phase"                                 as phase_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_phases_to_additional_ui_effects_junctions_tables/data__.tsv') }}
