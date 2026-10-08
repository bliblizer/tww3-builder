-- Textes du jeu : Noms des groupes de caps
-- Source : text/db/unit_set_to_mp_unit_caps__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/unit_set_to_mp_unit_caps__.loc.tsv') }}
