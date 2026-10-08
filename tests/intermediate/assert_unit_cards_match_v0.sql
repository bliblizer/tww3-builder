-- Non-régression du regroupement en cartes et des libellés d'options contre la V0 (scripts Python).
-- Les écarts assumés (corrections) sont listés dans seeds/reference/ref_v0_accepted_differences.csv.
-- La V0 complétait le libellé de monture par « On foot » au niveau de la carte : on reproduit ce calcul ici.
with new_options as (
    select
        race_key, card_id, unit_key, unit_name,
        coalesce(lore, '') as lore, coalesce(mark, '') as mark,
        coalesce(forest_spirit, '') as forest_spirit, coalesce(other_variant, '') as other_variant,
        coalesce(case when bool_or(mount_name is not null) over (partition by card_id)
                      then coalesce(mount_name, 'On foot') end, '') as mount,
        is_selectable_pvp
    from {{ ref('int_unit_cards') }}
),
accepted as (
    select unit_key, new_value from {{ ref('ref_v0_accepted_differences') }} where column_name = 'mount'
),
new_cmp as (   -- pour un écart assumé, on compare avec la valeur V0 si la nouvelle valeur est bien celle attendue
    select n.* replace (case when a.new_value = n.mount then v.mount else n.mount end as mount)
    from new_options n
    left join accepted a using (unit_key)
    left join {{ ref('ref_v0_roster_options') }} v using (race_key, unit_key)
),
old_options as (
    select race_key, card_id, unit_key, unit_name,
           coalesce(lore, ''), coalesce(mark, ''), coalesce(forest_spirit, ''), coalesce(other_variant, ''),
           coalesce(mount, ''), is_selectable_pvp
    from {{ ref('ref_v0_roster_options') }}
),
new_cards as (
    select race_key, card_id, root_unit_key, card_name, tab_key from {{ ref('int_unit_cards') }} where is_root
),
old_cards as (
    select race_key, card_id, root_unit_key, card_name, tab_key from {{ ref('ref_v0_roster_cards') }}
)
select 'option - nouveau' as ecart, unit_key as detail from (select * from new_cmp except select * from old_options)
union all
select 'option - v0', unit_key from (select * from old_options except select * from new_cmp)
union all
select 'carte - nouveau', card_id from (select * from new_cards except select * from old_cards)
union all
select 'carte - v0', card_id from (select * from old_cards except select * from new_cards)
