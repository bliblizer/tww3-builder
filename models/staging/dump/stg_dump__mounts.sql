-- Montures -> entité de combat
-- Source : db/mounts_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as mount_key,
    "animation"                                             as animation,
    "entity"                                                as battle_entity_key,
    "audio_armour_type"                                     as audio_armour_type,
    "variant"                                               as variant,
    "voiceover"                                             as voiceover,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/mounts_tables/data__.tsv') }}
