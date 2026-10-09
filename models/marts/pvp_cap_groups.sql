-- Groupes de caps du builder PvP : plafond par défaut de chaque groupe, par race.
-- Grain : 1 ligne par race x groupe.
select race_key, unit_set_key, cap_group_name, default_cap, nb_member_units, patch
from {{ ref('int_cap_groups') }}
