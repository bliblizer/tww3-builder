-- Textes du jeu : Noms des catégories de variantes (Bloodlines…)
-- Source : text/db/units_custom_battle_type_categories__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/units_custom_battle_type_categories__.loc.tsv') }}
