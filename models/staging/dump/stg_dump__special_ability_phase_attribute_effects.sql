-- Attributs donnés par les phases
-- Source : db/special_ability_phase_attribute_effects_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "attribute"                                             as attribute_key,
    "phase"                                                 as phase_key,
    "attribute_type"                                        as attribute_type,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_phase_attribute_effects_tables/data__.tsv') }}
