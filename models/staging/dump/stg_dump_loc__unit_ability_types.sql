-- Textes du jeu : Types de capacités (Wind / Direct damage)
-- Source : text/db/unit_ability_types__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/unit_ability_types__.loc.tsv') }}
