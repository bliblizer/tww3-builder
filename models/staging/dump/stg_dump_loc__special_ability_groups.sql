-- Textes du jeu : Noms des groupes de capacités
-- Source : text/db/special_ability_groups__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/special_ability_groups__.loc.tsv') }}
