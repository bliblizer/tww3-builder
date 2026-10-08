"""Construit l'application de builder (docs/index.html) à partir des tables marts de tww3.duckdb.

Usage (terminal VS Code, (.venv) actif, dans le dossier tww3-builder) :
    dbt build --profiles-dir .
    python scripts/build_app.py
Puis double-clic sur docs/index.html pour l'ouvrir dans le navigateur.
docs/ est le dossier publié par GitHub Pages : après un commit + push, le site en ligne est à jour.

Le fichier produit est autonome (données incluses) : on peut l'ouvrir hors ligne ou le mettre en ligne tel quel.
La mise en page et le code de l'application sont dans app/template.html ; ce script n'y injecte que les données.
"""
import json, os, sys
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'tww3.duckdb')
TEMPLATE = os.path.join(ROOT, 'app', 'template.html')
OUT = os.path.join(ROOT, 'docs', 'index.html')

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
budget = con.execute("select budget from staging.stg_dump__mp_budgets where budget_key = 'land_large'").fetchone()[0]
max_units = con.execute("select starting_unit_cap from staging.stg_dump__battle_unit_caps_for_team_sizes where team_size = 1").fetchone()[0]

tabs = rows("""
    select t.tab_key as key, t.tab_order as ord, x.resolved_text as name
    from staging.stg_dump__ui_unit_group_parents t
    left join staging.stg_loc_texts x on x.loc_key = 'ui_unit_group_parents_onscreen_name_' || t.tab_key
    order by t.tab_order, t.tab_key""")

races = rows("select race_key as key, race_name as name, nb_cards from marts.pvp_races order by race_name")

cards = rows("""
    select race_key, card_id, card_name, tab_key, ui_group_name, can_be_general,
           nb_options, has_variant_choice, has_mount_choice, min_cost, max_cost
    from marts.pvp_roster_cards
    order by race_key, tab_order, min_cost, card_name""")

options = rows("""
    select card_id, unit_key, unit_name, lore, mark, forest_spirit, other_variant, mount, can_be_general, multiplayer_cost
    from marts.pvp_roster_options
    order by card_id, multiplayer_cost, unit_key""")

opts_by_card = {}
for o in options:
    opts_by_card.setdefault(o['card_id'], []).append({
        'u': o['unit_key'], 'n': o['unit_name'], 'c': o['multiplayer_cost'], 'g': o['can_be_general'],
        'lore': o['lore'], 'mark': o['mark'], 'spirit': o['forest_spirit'], 'other': o['other_variant'], 'mount': o['mount']})

roster = {}
for c in cards:
    roster.setdefault(c['race_key'], []).append({
        'id': c['card_id'], 'n': c['card_name'], 't': c['tab_key'], 'grp': c['ui_group_name'], 'g': c['can_be_general'],
        'min': c['min_cost'], 'max': c['max_cost'], 'opts': opts_by_card[c['card_id']]})

data = {'patch': patch, 'budget': budget, 'maxUnits': max_units, 'tabs': tabs, 'races': races, 'roster': roster}
payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')

html = open(TEMPLATE, encoding='utf-8').read()
marker = '/*__DATA__*/null'
if marker not in html:
    sys.exit("Marqueur /*__DATA__*/null introuvable dans app/template.html")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8').write(html.replace(marker, payload))
print(f"{OUT}\n{len(races)} races, {len(cards)} cartes, {len(options)} options, budget {budget}, {max_units} unités max ({patch})")
