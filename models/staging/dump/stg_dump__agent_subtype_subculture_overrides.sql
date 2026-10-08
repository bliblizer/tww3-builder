-- Surcharges de personnage par sous-culture
-- Source : db/agent_subtype_subculture_overrides_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "subculture"                                            as subculture_key,
    "subtype"                                               as agent_subtype_key,
    "agent"                                                 as agent,
    "associated_unit_override"                              as unit_key,
    "small_icon"                                            as small_icon,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/agent_subtype_subculture_overrides_tables/data__.tsv') }}
