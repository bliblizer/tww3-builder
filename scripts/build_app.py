"""Construit l'application de builder (docs/index.html) à partir des tables marts de tww3.duckdb.

Usage (terminal VS Code, (.venv) actif, dans le dossier tww3-builder) :
    dbt build --profiles-dir .
    python scripts/build_app.py
Puis double-clic sur docs/index.html pour l'ouvrir dans le navigateur.
docs/ est le dossier publié par GitHub Pages : après un commit + push, le site en ligne est à jour.

Le fichier produit est autonome (données incluses) : on peut l'ouvrir hors ligne ou le mettre en ligne tel quel.
La mise en page et le code de l'application sont dans app/template.html ; ce script n'y injecte que les données.

Images des cartes (facultatif) :
- ui/units/icons/ du jeu        -> assets/unit_cards/      (cartes des unités : <unit_card>.png)
- ui/portraits/units/ du jeu    -> assets/portraits_units/ (personnages dont la carte du jeu est « placeholder » :
                                                             <portrait>.png, en ignorant les masques *_maskN.png
                                                             et les morceaux de Daemon Prince du dossier dae_prince/)
- ui/common ui/unit_category_icons/ -> assets/unit_category_icons/ (icône de catégorie en bas de carte)
- ui/skins/default/unit_card_*  -> assets/ui_skins/      (cadre, sélection, survol et demi-cercles des cartes)
  + experience_1 à experience_9  -> assets/ui_skins/      (chevrons des rangs d'expérience)
- ui/battle ui/ability_icons/   -> assets/ability_icons/  (icônes des sorts, capacités et domaines de magie)
- ui/campaign ui/mounts/        -> assets/mount_icons/    (icônes des montures)
- fichiers .png ou .webp acceptés partout
- les sous-dossiers sont acceptés : le script cherche les .png partout dans ces deux dossiers ;
- le script copie dans docs/images/ (cartes) et docs/images/portraits/ (portraits) UNIQUEMENT les images utiles
  au roster PvP, et liste celles qui manquent dans exports/missing_unit_cards.csv ;
- à relancer après chaque ajout d'images dans assets/ ;
- sans image, l'application affiche des cartes de couleur avec les initiales.
"""
import csv, json, math, os, re, shutil, sys
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'tww3.duckdb')
TEMPLATE = os.path.join(ROOT, 'app', 'template.html')
OUT = os.path.join(ROOT, 'docs', 'index.html')
ASSETS = os.path.join(ROOT, 'assets', 'unit_cards')
PORTRAIT_ASSETS = os.path.join(ROOT, 'assets', 'portraits_units')
ICON_ASSETS = os.path.join(ROOT, 'assets', 'unit_category_icons')
SKIN_ASSETS = os.path.join(ROOT, 'assets', 'ui_skins')
ABILITY_ICON_ASSETS = os.path.join(ROOT, 'assets', 'ability_icons')
MOUNT_ICON_ASSETS = os.path.join(ROOT, 'assets', 'mount_icons')
SKIN_FILES = {   # habillage des cartes : clé de l'application -> fichier du jeu (ui/skins/default/)
    'frame': 'unit_card_frame_plain', 'selected': 'unit_card_selected', 'hover': 'unit_card_hover',
    'semi': 'unit_card_semicircle', 'semiHero': 'unit_card_semicircle_hero', 'semiRenown': 'unit_card_semicircle_renown'}
EXTS = ('.png', '.webp')
PLACEHOLDERS = {'placeholder', 'a_character_placeholder'}   # cartes génériques du jeu : jamais affichées
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
    select race_key, card_id, card_name, root_unit_card, root_portrait_image, root_image_source, tab_key, ui_group_name, can_be_general,
           nb_options, has_variant_choice, has_mount_choice, min_cost, max_cost
    from marts.pvp_roster_cards
    order by race_key, tab_order, min_cost, card_name""")

options = rows("""
    select race_key, card_id, unit_key, unit_name, lore, mark, forest_spirit, other_variant, other_variant_category, mount,
           can_be_general, is_lord, role, is_flying, multiplayer_cost, unit_card, portrait_image, image_source,
           category_icon, is_renown, lore_icon, lore_colour, mount_icon
    from marts.pvp_roster_options
    order by card_id, multiplayer_cost, unit_key""")

# ---------- images : cartes (ui/units/icons) et portraits des personnages (ui/portraits/units) ----------
def scan(folder, skip=lambda path: False):
    found = {}
    if os.path.isdir(folder):
        for dirpath, _, files in os.walk(folder):
            for name in files:
                path = os.path.join(dirpath, name)
                stem, ext = os.path.splitext(name)
                if ext.lower() in EXTS and not skip(path):
                    found.setdefault(stem.lower(), path)
    return found

def is_campaign_only_portrait(path):
    """masques techniques (*_maskN.png) et morceaux de Daemon Prince (dae_prince/) : servent à la campagne"""
    low = path.lower().replace('\\', '/')
    return re.search(r'_mask\d*\.(png|webp)$', low) is not None or '/dae_prince/' in low

card_found = scan(ASSETS)
portrait_found = scan(PORTRAIT_ASSETS, is_campaign_only_portrait)

def wanted(source, card, portrait):
    """(type, nom de fichier) de l'image à afficher pour une option ou une carte"""
    if source == 'portrait' or card in PLACEHOLDERS:
        return ('portrait', portrait) if portrait else None
    return ('card', card)

needed = {wanted(c['root_image_source'], c['root_unit_card'], c['root_portrait_image']) for c in cards} \
       | {wanted(o['image_source'], o['unit_card'], o['portrait_image']) for o in options}
needed.discard(None)
if os.path.isdir(IMAGES_OUT):                       # on repart d'un dossier propre à chaque construction
    shutil.rmtree(IMAGES_OUT)
available = set()
copied = {}   # (type, nom) -> chemin relatif à docs/images/, extension comprise
def copy_image(src, sub, name):
    ext = os.path.splitext(src)[1].lower()
    out_dir = os.path.join(IMAGES_OUT, sub) if sub else IMAGES_OUT
    os.makedirs(out_dir, exist_ok=True)
    shutil.copyfile(src, os.path.join(out_dir, name + ext))
    return (sub + '/' if sub else '') + name + ext
for kind, name in sorted(needed):
    src = (card_found if kind == 'card' else portrait_found).get(name.lower())
    if src:
        copied[(kind, name)] = copy_image(src, '' if kind == 'card' else 'portraits', name)
        available.add((kind, name))
missing = sorted(needed - available)
os.makedirs(os.path.join(ROOT, 'exports'), exist_ok=True)
with open(os.path.join(ROOT, 'exports', 'missing_unit_cards.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\r\n'); w.writerow(['type', 'file', 'game_folder'])
    w.writerows([k, n + '.png', 'ui/units/icons' if k == 'card' else 'ui/portraits/units'] for k, n in missing)

def img(source, card, portrait):
    """chemin relatif à docs/images/ (avec extension) de l'image disponible, sinon None"""
    return copied.get(wanted(source, card, portrait))

# icônes de catégorie et habillage des cartes
icon_found = scan(ICON_ASSETS)
icons = {}
for name in sorted({o['category_icon'] for o in options if o['category_icon']}):
    if name.lower() in icon_found:
        icons[name] = copy_image(icon_found[name.lower()], 'icons', name)
skin_found = scan(SKIN_ASSETS)
skin = {k: copy_image(skin_found[f], 'ui', f) for k, f in SKIN_FILES.items() if f in skin_found}
xp_icons = [copy_image(skin_found[f'experience_{n}'], 'ui', f'experience_{n}') if f'experience_{n}' in skin_found else None
            for n in range(1, 10)]
if any(xp_icons):
    skin['xp'] = [None] + xp_icons   # skin.xp[rang]

# icônes des sorts / capacités / domaines (ability_icons) et des montures (mount_icons)
ability_found, mount_found = scan(ABILITY_ICON_ASSETS), scan(MOUNT_ICON_ASSETS)
ability_icons, mount_icons = {}, {}
def ability_icon(name):
    if not name or name.lower() not in ability_found: return None
    if name not in ability_icons: ability_icons[name] = copy_image(ability_found[name.lower()], 'abilities', name)
    return ability_icons[name]
def mount_icon(name):
    if not name or name.lower() not in mount_found: return None
    if name not in mount_icons: mount_icons[name] = copy_image(mount_found[name.lower()], 'mounts', name)
    return mount_icons[name]

# ---------- personnalisation : sorts, capacités, objets (dictionnaire par race + liste de clés par option) ----------
TYPE = {'spell': 's', 'ability': 'a', 'item': 'i'}
up_dict, up_by_option = {}, {}
for r in rows("""
    select race_key, unit_key, upgrade_type, upgrade_key, upgrade_name, cost, rarity_state, rarity_hex, icon_name
    from marts.pvp_character_upgrades
    order by race_key, unit_key, case upgrade_type when 'spell' then 1 when 'ability' then 2 else 3 end, upgrade_name"""):
    up_dict.setdefault(r['race_key'], {})[r['upgrade_key']] = [r['upgrade_name'], TYPE[r['upgrade_type']], r['cost'],
                                                               r['rarity_state'], r['rarity_hex'], ability_icon(r['icon_name'])]
    up_by_option.setdefault((r['race_key'], r['unit_key']), []).append(r['upgrade_key'])

opts_by_card = {}
for o in options:
    opts_by_card.setdefault(o['card_id'], []).append({
        'u': o['unit_key'], 'n': o['unit_name'], 'c': o['multiplayer_cost'], 'g': o['can_be_general'], 'l': o['is_lord'],
        'role': o['role'], 'fly': o['is_flying'], 'ovc': o['other_variant_category'],
        'ic': icons.get(o['category_icon']), 'rn': o['is_renown'],
        'li': ability_icon(o['lore_icon']), 'lc': o['lore_colour'], 'mi': mount_icon(o['mount_icon']),
        'lore': o['lore'], 'mark': o['mark'], 'spirit': o['forest_spirit'], 'other': o['other_variant'], 'mount': o['mount'],
        'img': img(o['image_source'], o['unit_card'], o['portrait_image']), 'race': o['race_key']})

SPELL_STEP = 0.047   # même formule que l'application et models/validation/unit_price_checks.sql
def upgrades_cost(ups, keys):
    """Coût des éléments cochés : capacités et objets au prix de rareté ; sorts avec la remise dégressive."""
    other = sum((ups[k][2] or 0) for k in keys if ups[k][1] != 's')
    spells = sorted(((ups[k][2] or 0) for k in keys if ups[k][1] == 's'), reverse=True)
    return other + math.floor(sum(c * (1 - SPELL_STEP * i) for i, c in enumerate(spells)))

# options : liste des éléments de personnalisation + coût par défaut (tout coché, comme le prix affiché en jeu)
for opts in opts_by_card.values():
    for o in opts:
        race_key = o.pop('race')
        o['up'] = up_by_option.get((race_key, o['u']), [])
        o['dc'] = o['c']   # par défaut, aucun sort / capacité / objet coché : prix de base
    opts.sort(key=lambda o: (o['dc'], o['u']))

roster = {}
for c in cards:
    roster.setdefault(c['race_key'], []).append({
        'id': c['card_id'], 'n': c['card_name'], 'img': img(c['root_image_source'], c['root_unit_card'], c['root_portrait_image']), 't': c['tab_key'], 'grp': c['ui_group_name'], 'g': c['can_be_general'],
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
            stem, ext = os.path.splitext(name)
            if ext.lower() in EXTS:
                race_found.setdefault(stem.lower(), os.path.join(dirpath, name))
for r in races:
    key = (r['race_image'] or '').lower()   # <faction>_large (race_strip_images) ou <faction> (bannières)
    src = race_found.get(key) or race_found.get(key.removesuffix('_large'))
    r['race_image'] = copy_image(src, 'races', r['race_image']) if src else None

data = {'patch': patch, 'budget': budget, 'maxUnits': max_units, 'tabs': tabs, 'races': races, 'roster': roster, 'caps': caps, 'up': up_dict,
        'tags': tags, 'xp': xp, 'typeCats': type_cats, 'skin': skin}
payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')

html = open(TEMPLATE, encoding='utf-8').read()
marker = '/*__DATA__*/null'
if marker not in html:
    sys.exit("Marqueur /*__DATA__*/null introuvable dans app/template.html")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8').write(html.replace(marker, payload))
print(f"{OUT}\n{len(races)} races, {len(cards)} cartes, {len(options)} options, budget {budget}, {max_units} unités max ({patch})")
print(f"Illustrations de race : {sum(1 for r in races if r['race_image'])} / {len(races)} (dossier assets/race_images/)")
n_cards = sum(1 for k, _ in needed if k == 'card'); n_portraits = len(needed) - n_cards
a_cards = sum(1 for k, _ in available if k == 'card'); a_portraits = len(available) - a_cards
print(f"Images des cartes : {a_cards} / {n_cards} | portraits des personnages : {a_portraits} / {n_portraits} "
      f"| manquantes listées dans exports/missing_unit_cards.csv")
n_icons = len({o['category_icon'] for o in options if o['category_icon']})
print(f"Icônes : sorts / capacités / domaines {len(ability_icons)} | montures {len(mount_icons)} | "
      f"chevrons d'expérience {sum(1 for x in skin.get('xp', []) if x)} / 9")
print(f"Icônes de catégorie : {len(icons)} / {n_icons} | habillage des cartes : {sum(1 for k in skin if k in SKIN_FILES)} / {len(SKIN_FILES)} fichiers")
