-- Objets proposés à chaque personnage en bataille personnalisée (clé d unité)
-- Source : db/battle_set_piece_armies_characters_items_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "character_item"                                        as ancillary_key,
    "character_name"                                        as unit_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/battle_set_piece_armies_characters_items_tables/data__.tsv') }}
