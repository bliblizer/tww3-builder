-- Textes du jeu : Libellés forces/faiblesses (phase ultérieure)
-- Source : text/db/ui_unit_bullet_point_enums__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/ui_unit_bullet_point_enums__.loc.tsv') }}
