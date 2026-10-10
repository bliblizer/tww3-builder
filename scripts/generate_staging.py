"""Crée le modèle de staging dbt des fichiers bruts qui n'en ont pas encore.

Usage : python scripts/generate_staging.py [patch]      (patch par défaut : patch_9.0)
À lancer après avoir ajouté une ligne dans config/sources.csv et retéléchargé le patch.
- Les modèles existants ne sont JAMAIS réécrits (tes modifications manuelles sont préservées).
- Les nouveaux modèles sont ajoutés à la fin de models/staging/dump/_stg_dump.yml.
- Le test de nombre de lignes (tests/assert_staging_row_counts_match_manifest.sql) est régénéré entièrement.
- Les types sont déduits des valeurs du patch : à relire avant de valider.
"""
import csv, re, os, sys, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATCH = sys.argv[1] if len(sys.argv) > 1 else 'patch_9.0'
RAW = f'{ROOT}/raw/{PATCH}'
man = list(csv.DictReader(open(f'{RAW}/_manifest.csv', encoding='utf-8')))
purpose = {r['path']: r['purpose'] for r in csv.DictReader(open(f'{ROOT}/config/sources.csv', encoding='utf-8'))}

RENAME = {  # renommages vers des clés homogènes (par table)
 'units_custom_battle_permissions': {'faction': 'faction_key', 'unit': 'unit_key'},
 'factions': {'key': 'faction_key', 'subculture': 'subculture_key'},
 'cultures_subcultures': {'subculture': 'subculture_key', 'culture': 'culture_key'},
 'main_units': {'unit': 'unit_key', 'land_unit': 'land_unit_key', 'caste': 'caste_key', 'ui_unit_group_land': 'ui_group_key'},
 'ui_unit_group_parents': {'key': 'tab_key'},
 'ui_unit_groupings': {'key': 'ui_group_key', 'parent_group': 'tab_key'},
 'units_custom_battle_mounts': {'base_unit': 'base_unit_key', 'mounted_unit': 'mounted_unit_key'},
 'units_custom_battle_types': {'alternate_unit': 'alternate_unit_key', 'base_unit': 'base_unit_key', 'id': 'type_id', 'type_category': 'type_category_key'},
 'units_custom_battle_types_to_factions': {'faction': 'faction_key', 'type': 'type_id'},
 'units_custom_battle_type_categories': {'category_key': 'type_category_key'},
 'unit_set_to_mp_unit_caps': {'unit_set': 'unit_set_key', 'subculture': 'subculture_key'},
 'unit_set_to_unit_junctions': {'unit_set': 'unit_set_key', 'unit_record': 'unit_key', 'unit_caste': 'caste_key', 'unit_category': 'unit_category_key', 'unit_class': 'unit_class_key'},
 'mp_budgets': {'key': 'budget_key'},
 'agent_subtypes': {'key': 'agent_subtype_key', 'associated_unit_override': 'unit_key'},
 'agent_subtype_subculture_overrides': {'subculture': 'subculture_key', 'subtype': 'agent_subtype_key', 'associated_unit_override': 'unit_key'},
 'special_ability_groups': {'ability_group': 'ability_group_key'},
 'special_ability_groups_to_units_junctions': {'ability_group': 'ability_group_key', 'unit': 'unit_key'},
 'special_ability_groups_to_unit_abilities_junctions': {'special_ability_groups': 'ability_group_key', 'unit_special_abilities': 'ability_key'},
 'unit_abilities': {'key': 'ability_key'},
 'land_units_to_unit_abilites_junctions': {'ability': 'ability_key', 'land_unit': 'land_unit_key', 'culture': 'culture_key'},
 'ancillaries': {'key': 'ancillary_key'},
 'ancillaries_included_agent_subtypes': {'agent_subtype': 'agent_subtype_key', 'ancillary': 'ancillary_key'},
 'ancillary_to_included_agents': {'ancillary': 'ancillary_key'},
 'ancillaries_categories': {'category': 'ancillary_category_key'},
 'ancillaries_categories_agent_subtype_override_junctions': {'agent_subtype': 'agent_subtype_key'},
 'ui_unit_bullet_point_enums': {'key': 'bullet_point_key'},
 'ui_unit_bullet_point_unit_overrides': {'bullet_point': 'bullet_point_key'},
 'character_skill_node_sets': {'key': 'node_set_key', 'agent_subtype_key': 'agent_subtype_key'},
 'character_skill_node_set_items': {'set': 'node_set_key', 'item': 'node_key'},
 'character_skill_nodes': {'key': 'node_key', 'character_skill_key': 'skill_key', 'subculture': 'subculture_key', 'faction_key': 'faction_key'},
 'character_skill_level_to_effects_junctions': {'character_skill_key': 'skill_key', 'effect_key': 'effect_key'},
 'effect_bonus_value_unit_ability_junctions': {'effect': 'effect_key', 'unit_ability': 'ability_key'},
 'unit_special_abilities': {'key': 'ability_key'},
 'ancillary_uniqueness_groupings': {'group_key': 'uniqueness_group_key'},
 'land_units': {'key': 'land_unit_key'},
 'battle_entities': {'key': 'battle_entity_key'},
 'mounts': {'key': 'mount_key', 'entity': 'battle_entity_key'},
 'battle_set_piece_armies_characters_items': {'character_item': 'ancillary_key', 'character_name': 'unit_key'},
 'unit_armour_types': {'key': 'armour_key'},
 'unit_shield_types': {'key': 'shield_key'},
 'melee_weapons': {'key': 'melee_weapon_key'},
 'missile_weapons': {'key': 'missile_weapon_key', 'default_projectile': 'projectile_key'},
 'projectiles': {'key': 'projectile_key', 'explosion_type': 'explosion_key'},
 'projectiles_explosions': {'key': 'explosion_key'},
 'unit_attributes': {'key': 'attribute_key'},
 'unit_attributes_to_groups_junctions': {'attribute': 'attribute_key'},
 'special_ability_to_special_ability_phase_junctions': {'special_ability': 'ability_key', 'phase': 'phase_key'},
 'special_ability_phases': {'id': 'phase_key'},
 'special_ability_phase_stat_effects': {'phase': 'phase_key', 'stat': 'stat_key'},
 'special_ability_phase_attribute_effects': {'attribute': 'attribute_key', 'phase': 'phase_key'},
 'special_ability_phases_to_additional_ui_effects_junctions': {'effect': 'ui_effect_key', 'special_ability_phase': 'phase_key'},
 'unit_variants': {'faction': 'faction_key', 'unit': 'land_unit_key', 'name': 'variant_name', 'variant': 'variant_key'},
}
PK = {  # clé primaire attendue (testée unique + non nulle si les données le confirment)
 'units_custom_battle_permissions': "faction_key || '|' || unit_key", 'custom_battle_factions': 'faction_key',
 'factions': 'faction_key', 'cultures_subcultures': 'subculture_key', 'main_units': 'unit_key',
 'ui_unit_group_parents': 'tab_key', 'ui_unit_groupings': 'ui_group_key',
 'units_custom_battle_mounts': "base_unit_key || '|' || mounted_unit_key", 'units_custom_battle_types': 'type_id',
 'units_custom_battle_types_to_factions': "faction_key || '|' || type_id", 'units_custom_battle_type_categories': 'type_category_key',
 'unit_set_to_mp_unit_caps': "unit_set_key || '|' || coalesce(subculture_key,'') || '|' || coalesce(character_name,'')",
 'mp_budgets': 'budget_key', 'battle_unit_caps_for_team_sizes': 'team_size', 'unit_stats_land_experience_bonuses': 'xp_level',
 'agent_subtypes': 'agent_subtype_key', 'special_ability_groups': 'ability_group_key', 'unit_abilities': 'ability_key',
 'ancillaries': 'ancillary_key', 'ancillaries_categories': 'ancillary_category_key', 'ui_unit_bullet_point_enums': 'bullet_point_key',
 'ui_unit_bullet_point_unit_overrides': "unit_key || '|' || bullet_point_key",
}

def read(path):
    lines = open(path, encoding='utf-8', newline='').read().split('\n')
    if lines[-1] == '': lines = lines[:-1]
    h = lines[0].split('\t'); return h, [l.split('\t') for l in lines[2:]]

def infer(vals):
    v = [x for x in vals if x != '']
    if not v: return 'varchar'
    if all(x in ('true', 'false') for x in v): return 'boolean'
    if all(re.fullmatch(r'-?(0|[1-9]\d*)', x) for x in v) and all(abs(int(x)) < 2**63 for x in v): return 'bigint'
    if all(re.fullmatch(r'-?\d+\.\d{1,4}', x) for x in v): return 'decimal(18,4)'
    return 'varchar'

os.makedirs(f'{ROOT}/models/staging/dump', exist_ok=True)
yml, counts = [], []
for m in man:
    p = m['path']
    if not p.endswith('.tsv'): continue
    h, rows = read(f'{RAW}/{p}')
    if p.startswith('text/'):
        t = p.split('/')[-1].replace('__.loc.tsv', ''); name = f'stg_dump_loc__{t}'
        sql = f"""-- Textes du jeu : {purpose[p]}
-- Source : {p}
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{{{ var("patch") }}}}'            as patch
from {{{{ read_raw('{p}') }}}}
"""
        pk = 'loc_key'; uniq = len({r[0] for r in rows}) == len(rows)
    else:
        t = p.split('/')[1].replace('_tables', ''); name = f'stg_dump__{t}'
        ren = RENAME.get(t, {})
        cols = []
        for i, c in enumerate(h):
            typ = infer([r[i] for r in rows]); new = ren.get(c, c)
            expr = f'"{c}"' if typ == 'varchar' else f'cast("{c}" as {typ})'
            cols.append(f'    {expr:<55} as {new}')
        sql = f"-- {purpose[p]}\n-- Source : {p}  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)\nselect\n" \
              + ',\n'.join(cols) + f",\n    '{{{{ var(\"patch\") }}}}' as patch\nfrom {{{{ read_raw('{p}') }}}}\n"
        pk = PK.get(t)
        uniq = None
        if pk:  # vérifie que la clé annoncée est vraiment unique dans les données
            idx = {ren.get(c, c): i for i, c in enumerate(h)}
            parts = [x.strip().strip("'") for x in re.split(r"\|\|", re.sub(r"coalesce\((\w+),''\)", r'\1', pk))]
            keycols = [x for x in parts if x in idx]
            uniq = len({tuple(r[idx[k]] for k in keycols) for r in rows}) == len(rows)
    counts.append((name, p))
    if os.path.exists(f'{ROOT}/models/staging/dump/{name}.sql'):
        continue
    open(f'{ROOT}/models/staging/dump/{name}.sql', 'w', encoding='utf-8').write(sql.replace('var(\\"patch\\")', 'var("patch")'))
    print('nouveau modèle :', name)
    yml += [f'  - name: {name}', f'    description: "{purpose[p]} (source : {p})"']
    if pk and uniq:
        yml += ['    data_tests:', '      - unique:', f'          column_name: "{pk}"', '      - not_null:', f'          column_name: "{pk}"']
    elif pk:
        print('CLÉ NON UNIQUE :', name, pk)
if yml:
    with open(f'{ROOT}/models/staging/dump/_stg_dump.yml', 'a', encoding='utf-8') as f: f.write('\n'.join(yml) + '\n')

# test singulier : chaque modèle de staging a exactement le nombre de lignes du manifest
union = '\n    union all\n'.join(f"    select '{p}' as path, count(*) as n from {{{{ ref('{n}') }}}}" for n, p in counts)
test = f"""-- Échoue si un modèle de staging n'a pas le même nombre de lignes que le fichier brut (manifest).
with staged as (
{union}
),
manifest as (
    select path, cast(rows as bigint) as n
    from read_csv('{{{{ var("raw_root") }}}}/{{{{ var("patch") }}}}/_manifest.csv', header=true, all_varchar=true)
    where rows is not null and rows <> ''
)
select m.path, m.n as rows_manifest, s.n as rows_staged
from manifest m full outer join staged s using (path)
where m.n is distinct from s.n
"""
os.makedirs(f'{ROOT}/tests', exist_ok=True)
open(f'{ROOT}/tests/assert_staging_row_counts_match_manifest.sql', 'w', encoding='utf-8').write(test)
print(len(counts), 'fichiers bruts couverts par le staging')
