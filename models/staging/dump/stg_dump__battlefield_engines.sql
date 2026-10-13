-- Engins de guerre (artillerie) : arme de tir de l'engin (land_units.engine)
-- Source : db/battlefield_engines_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as key,
    "destroyed_model"                                       as destroyed_model,
    "destruction_animation"                                 as destruction_animation,
    "engine_type"                                           as engine_type,
    "gun_animation_table"                                   as gun_animation_table,
    "missile_weapon"                                        as missile_weapon,
    "model"                                                 as model,
    "battle_entity"                                         as battle_entity,
    "asset_folder"                                          as asset_folder,
    "variant"                                               as variant,
    "draught_attachment_point"                              as draught_attachment_point,
    "tech_folder"                                           as tech_folder,
    "rider_attachment_point"                                as rider_attachment_point,
    "destruct_model"                                        as destruct_model,
    "destruct_anim"                                         as destruct_anim,
    "destruct_meta"                                         as destruct_meta,
    "audio_armour_type"                                     as audio_armour_type,
    "riders_shoot_behaviour"                                as riders_shoot_behaviour,
    cast("scale" as decimal(18,4))                          as scale,
    cast("crew_reserve_distance_offset" as decimal(18,4))   as crew_reserve_distance_offset,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/battlefield_engines_tables/data__.tsv') }}
