"""Construit l'application de builder (docs/index.html) à partir des tables marts de tww3.duckdb.

Usage (terminal VS Code, (.venv) actif, dans le dossier tww3-builder) :
    dbt build --profiles-dir .
    python scripts/build_app.py
Puis double-clic sur docs/index.html pour l'ouvrir dans le navigateur.
docs/ est le dossier publié par GitHub Pages : après un commit + push, le site en ligne est à jour.

Le fichier produit est autonome (données incluses) : on peut l'ouvrir hors ligne ou le mettre en ligne tel quel.
La mise en page et le code de l'application sont dans app/template.html ; ce script n'y injecte que les données.

Images des cartes (facultatif) :
- extrais le dossier ui/units/icons/ du jeu avec RPFM et copie son contenu dans assets/unit_cards/
  (les sous-dossiers sont acceptés : le script cherche les .png partout dans assets/unit_cards/) ;
- le script copie dans docs/images/ UNIQUEMENT les images utiles au roster PvP et liste celles qui manquent
  dans exports/missing_unit_cards.csv ;
- sans images, l'application affiche des cartes de couleur avec les initiales (comme avant).
"""
import csv, json, os, shutil, sys
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'tww3.duckdb')
TEMPLATE = os.path.join(ROOT, 'app', 'template.html')
OUT = os.path.join(ROOT, 'docs', 'index.html')
ASSETS = os.path.join(ROOT, 'assets', 'unit_cards')
RACE_ASSETS = os.path.join(ROOT, 'assets', 'race_images')   # contenu de ui/frontend ui/race_strip_images/ du jeu
IMAGES_OUT = os.path.join(ROOT, 'docs', 'images')

if not os.path.exists(DB):
    sys.exit("tww3.duckdb introuvable : lance d'abord `dbt build --profiles-dir .`")
try:
    con = duckdb.connect(DB, read_only=True)
except duckdb.IOException:
    sys.exit("La base est ouverte ailleurs (DBeaver ?) : ferme la connexion puis relance.")

def rows(sql, params=()):
    cur = con.execute(sql, params)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]

patch = con.execute("select any_value(patch) from marts.pvp_races").fetchone()[0]
budget, max_units = con.execute("select budget, max_units from marts.pvp_army_rules").fetchone()

tabs = rows("""
    select t.tab_key as key, t.tab_order as ord, x.resolved_text as name
    from staging.stg_dump__ui_unit_group_parents t
    left join staging.stg_loc_texts x on x.loc_key = 'ui_unit_group_parents_onscreen_name_' || t.tab_key
    order by t.tab_order, t.tab_key""")

races = rows("""select race_key as key, race_name as name, nb_cards, accent_hex as accent, race_image
                from marts.pvp_races order by race_name""")

cards = rows("""
    select race_key, card_id, card_name, root_unit_card, tab_key, ui_group_name, can_be_general,
           nb_options, has_variant_choice, has_mount_choice, min_cost, max_cost
    from marts.pvp_roster_cards
    order by race_key, tab_order, min_cost, card_name""")

options = rows("""
    select race_key, card_id, unit_key, unit_name, lore, mark, forest_spirit, other_variant, other_variant_category, mount,
           can_be_general, is_lord, role, is_flying, multiplayer_cost, unit_card
    from marts.pvp_roster_options
    order by card_id, multiplayer_cost, unit_key""")

# ---------- images des cartes ----------
needed = {c['root_unit_card'] for c in cards} | {o['unit_card'] for o in options}
found = {}
if os.path.isdir(ASSETS):
    for dirpath, _, files in os.walk(ASSETS):
        for name in files:
            if name.lower().endswith('.png'):
                found.setdefault(name[:-4].lower(), os.path.join(dirpath, name))
if os.path.isdir(IMAGES_OUT):                       # on repart d'un dossier propre à chaque construction
    shutil.rmtree(IMAGES_OUT)
available = set()
if found:
    os.makedirs(IMAGES_OUT, exist_ok=True)
    for card_name in sorted(needed):
        src = found.get(card_name.lower())
        if src:
            shutil.copyfile(src, os.path.join(IMAGES_OUT, card_name + '.png'))
            available.add(card_name)
missing = sorted(needed - available)
os.makedirs(os.path.join(ROOT, 'exports'), exist_ok=True)
with open(os.path.join(ROOT, 'exports', 'missing_unit_cards.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\r\n'); w.writerow(['unit_card', 'game_file_path'])
    w.writerows([m, f'ui/units/icons/{m}.png'] for m in missing)
img = lambda name: name if name in available else None

# ---------- personnalisation : sorts, capacités, objets (dictionnaire par race + liste de clés par option) ----------
TYPE = {'spell': 's', 'ability': 'a', 'item': 'i'}
up_dict, up_by_option = {}, {}
for r in rows("""
    select race_key, unit_key, upgrade_type, upgrade_key, upgrade_name, cost, rarity_state, rarity_hex
    from marts.pvp_character_upgrades
    order by race_key, unit_key, case upgrade_type when 'spell' then 1 when 'ability' then 2 else 3 end, upgrade_name"""):
    up_dict.setdefault(r['race_key'], {})[r['upgrade_key']] = [r['upgrade_name'], TYPE[r['upgrade_type']], r['cost'],
                                                               r['rarity_state'], r['rarity_hex']]
    up_by_option.setdefault((r['race_key'], r['unit_key']), []).append(r['upgrade_key'])

opts_by_card = {}
for o in options:
    opts_by_card.setdefault(o['card_id'], []).append({
        'u': o['unit_key'], 'n': o['unit_name'], 'c': o['multiplayer_cost'], 'g': o['can_be_general'], 'l': o['is_lord'],
        'role': o['role'], 'fly': o['is_flying'], 'ovc': o['other_variant_category'],
        'lore': o['lore'], 'mark': o['mark'], 'spirit': o['forest_spirit'], 'other': o['other_variant'], 'mount': o['mount'],
        'img': img(o['unit_card']), 'race': o['race_key']})

# options : liste des éléments de personnalisation + coût par défaut (tout coché, comme le prix affiché en jeu)
for opts in opts_by_card.values():
    for o in opts:
        race_key = o.pop('race')
        o['up'] = up_by_option.get((race_key, o['u']), [])
        o['dc'] = o['c'] + sum((up_dict[race_key][k][2] or 0) for k in o['up'])
    opts.sort(key=lambda o: (o['dc'], o['u']))

roster = {}
for c in cards:
    roster.setdefault(c['race_key'], []).append({
        'id': c['card_id'], 'n': c['card_name'], 'img': img(c['root_unit_card']), 't': c['tab_key'], 'grp': c['ui_group_name'], 'g': c['can_be_general'],
        'min': min(o['dc'] for o in opts_by_card[c['card_id']]), 'max': max(o['dc'] for o in opts_by_card[c['card_id']]),
        'opts': opts_by_card[c['card_id']]})

# ---------- caps : groupes, membres, plafonds spéciaux selon le général ----------
caps = {}
for r in rows("select race_key, unit_set_key, cap_group_name, default_cap from marts.pvp_cap_groups"):
    caps.setdefault(r['race_key'], {'g': {}, 'm': {}, 'o': {}})['g'][r['unit_set_key']] = [r['cap_group_name'], r['default_cap']]
for r in rows("select race_key, unit_set_key, unit_key from marts.pvp_cap_group_members order by unit_set_key"):
    caps[r['race_key']]['m'].setdefault(r['unit_key'], []).append(r['unit_set_key'])
for r in rows("select race_key, unit_set_key, general_card_id, cap from marts.pvp_cap_overrides"):
    caps[r['race_key']]['o'].setdefault(r['general_card_id'], {})[r['unit_set_key']] = r['cap']

# ---------- forces / faiblesses, rangs d'expérience, catégories de variantes ----------
tags = {}
for r in rows("select unit_key, tag_name, state from marts.pvp_unit_tags order by unit_key, sort_order, tag_name"):
    tags.setdefault(r['unit_key'], []).append([r['tag_name'], r['state']])
xp = [[float(r['cost_multiplier']), r['fixed_cost']] for r in rows("select * from marts.pvp_xp_ranks order by rank")]
type_cats = {r['k']: r['n'] for r in rows("""
    select replace(loc_key, 'units_custom_battle_type_categories_category_name_', '') as k, resolved_text as n
    from staging.stg_loc_texts where loc_key like 'units_custom_battle_type_categories_category_name_%'""")}

# ---------- illustrations des races (facultatif) ----------
race_found = {}
if os.path.isdir(RACE_ASSETS):
    for dirpath, _, files in os.walk(RACE_ASSETS):
        for name in files:
            if name.lower().endswith('.png'):
                race_found.setdefault(name[:-4].lower(), os.path.join(dirpath, name))
for r in races:
    src = race_found.get((r['race_image'] or '').lower())
    if src:
        os.makedirs(os.path.join(IMAGES_OUT, 'races'), exist_ok=True)
        shutil.copyfile(src, os.path.join(IMAGES_OUT, 'races', r['race_image'] + '.png'))
    else:
        r['race_image'] = None

data = {'patch': patch, 'budget': budget, 'maxUnits': max_units, 'tabs': tabs, 'races': races, 'roster': roster, 'caps': caps, 'up': up_dict,
        'tags': tags, 'xp': xp, 'typeCats': type_cats}
payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')

html = open(TEMPLATE, encoding='utf-8').read()
marker = '/*__DATA__*/null'
if marker not in html:
    sys.exit("Marqueur /*__DATA__*/null introuvable dans app/template.html")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8').write(html.replace(marker, payload))
print(f"{OUT}\n{len(races)} races, {len(cards)} cartes, {len(options)} options, budget {budget}, {max_units} unités max ({patch})")
print(f"Illustrations de race : {sum(1 for r in races if r['race_image'])} / {len(races)} (dossier assets/race_images/)")
if not found:
    print(f"Images : aucune trouvée dans {ASSETS} -> cartes sans image (initiales).")
else:
    print(f"Images : {len(available)} / {len(needed)} copiées dans docs/images/ ; "
          f"{len(missing)} manquante(s), listées dans exports/missing_unit_cards.csv")
