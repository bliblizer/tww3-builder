-- Sous-cultures (races)
-- Source : db/cultures_subcultures_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "subculture"                                            as subculture_key,
    "culture"                                               as culture_key,
    cast("index" as bigint)                                 as index,
    "audio_state_override"                                  as audio_state_override,
    "audio_corruption_state_override"                       as audio_corruption_state_override,
    "audio_rtpc_override"                                   as audio_rtpc_override,
    "region_owner_audio_switch"                             as region_owner_audio_switch,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/cultures_subcultures_tables/data__.tsv') }}
