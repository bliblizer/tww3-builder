-- Points forts et faibles affichés dans l info-bulle des capacités
-- Source : db/unit_abilities_to_additional_ui_effects_juncs_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ability"                                               as ability,
    "effect"                                                as effect,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_abilities_to_additional_ui_effects_juncs_tables/data__.tsv') }}
