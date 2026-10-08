-- Textes du jeu : Noms des onglets
-- Source : text/db/ui_unit_group_parents__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/ui_unit_group_parents__.loc.tsv') }}
