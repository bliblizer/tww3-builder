-- Effets des objets (pour retrouver la capacité et l icône d un objet)
-- Source : db/ancillary_to_effects_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ancillary"                                             as ancillary,
    "effect"                                                as effect,
    "effect_scope"                                          as effect_scope,
    cast("value" as decimal(18,4))                          as value,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillary_to_effects_tables/data__.tsv') }}
