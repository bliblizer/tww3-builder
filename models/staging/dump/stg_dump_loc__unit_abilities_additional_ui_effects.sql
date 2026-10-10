-- Textes du jeu : Lignes d effet des info-bulles de capacités
-- Source : text/db/unit_abilities_additional_ui_effects__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/unit_abilities_additional_ui_effects__.loc.tsv') }}
