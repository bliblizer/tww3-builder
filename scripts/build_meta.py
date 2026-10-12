"""Page « Faction Meta » : un guide PvP par faction (docs/meta.html).

À lancer APRÈS build_app.py, dont il réutilise les données (roster, statistiques, profils, armées d'exemple) :
    python scripts/build_app.py
    python scripts/build_meta.py

Entrées (toutes facultatives : une faction sans fichier a quand même sa page, avec les données du jeu) :
    config/tier_lists/<faction>.csv   tier list : race_key, root_unit_key, unit_name, group, tier, note, ...
    config/meta/<faction>.csv         meta breakdown : section, item, value, text
    history/units_<patch>.csv         instantané des unités d'un patch, comparé au patch courant (« Patch changes »)
<faction> = nom de la faction en minuscules, mots reliés par des tirets (skaven, the-empire, daemons-of-chaos).

Sorties :
    docs/meta.html                    la page
    history/units_<patch courant>.csv instantané du patch courant (à versionner : il sert de base au patch suivant)
    exports/meta_checks.csv           points à vérifier (aussi affichés en fin de build)
"""
import csv, io, json, os, re, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILDER = os.path.join(ROOT, 'docs', 'index.html')
TEMPLATE = os.path.join(ROOT, 'app', 'meta_template.html')
OUT = os.path.join(ROOT, 'docs', 'meta.html')
TIER_DIR = os.path.join(ROOT, 'config', 'tier_lists')
META_DIR = os.path.join(ROOT, 'config', 'meta')
HISTORY_DIR = os.path.join(ROOT, 'history')
CHECKS = os.path.join(ROOT, 'exports', 'meta_checks.csv')

TIERS = ['meta', 'strong', 'viable', 'situational', 'weak']
GROUPS = ['characters', 'infantry', 'range', 'monsters']
SECTIONS = {'race_key', 'reviewed_patch', 'difficulty', 'adaptability', 'summary', 'playstyle', 'strength', 'weakness', 'matchup'}
# statistiques suivies d'un patch à l'autre (libellé affiché) ; une hausse est toujours une amélioration
TRACKED = {'unit_size': 'Unit size', 'health': 'Health', 'speed': 'Speed', 'armour': 'Armour', 'shield_block_chance': 'Shield',
           'leadership': 'Leadership', 'melee_attack': 'Melee attack', 'melee_defence': 'Melee defence',
           'weapon_strength': 'Weapon strength', 'weapon_ap_damage': 'AP damage', 'bonus_v_large': 'Bonus vs large',
           'bonus_v_infantry': 'Bonus vs infantry', 'charge_bonus': 'Charge bonus', 'ammunition': 'Ammunition', 'range': 'Range',
           'missile_strength': 'Missile damage', 'physical_resistance': 'Physical resist.', 'spell_resistance': 'Spell resist.',
           'missile_resistance': 'Missile resist.', 'fire_resistance': 'Fire resist.', 'ward_save': 'Ward save',
           'barrier_health': 'Barrier'}
TAB_COLORS = {'commander': '#5a2a3a', 'heroes_agents': '#4a2f50', 'infantry': '#3e3a2c', 'missile_infantry': '#2f4038',
              'cavalry_chariots': '#4a3424', 'missile_cavalry_chariots': '#3a4026', 'monster_beasts': '#2c3a48',
              'constructs': '#3d3d3d', 'flying_war_machine': '#30404a', 'missile_monster_beasts': '#2a4340',
              'artillery_war_machines': '#45392a', 'campaign_exclusives': '#333'}

checks = []
def check(level, where, msg):
    checks.append((level, where, msg))

# ---------- données du builder ----------
if not os.path.exists(BUILDER):
    sys.exit('docs/index.html introuvable : lance d\'abord python scripts/build_app.py')
html = open(BUILDER, encoding='utf-8').read()
start = html.find('const DATA = ')
if start < 0:
    sys.exit('Données du builder introuvables dans docs/index.html (marqueur « const DATA = »).')
D, _ = json.JSONDecoder().raw_decode(html, start + len('const DATA = '))
PATCH = D['patch']
cols = D['statCols']
def stat(u, c):
    r = D['stats'].get(u)
    return r[cols.index(c)] if r and c in cols else None

slug = lambda name: re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
races = D['races']
by_slug = {slug(r['name']): r for r in races}
by_key = {r['key']: r for r in races}
by_name = {r['name'].lower(): r for r in races}
code_of = {v: k for k, v in D.get('factionCodes', {}).items()}

def read_csv(path):
    """CSV tolérant : virgule ou point-virgule (Excel français), BOM, UTF-8 ou Windows-1252."""
    raw = open(path, 'rb').read()
    try:
        text = raw.decode('utf-8-sig')
    except UnicodeDecodeError:
        text = raw.decode('cp1252')
        check('warning', os.path.relpath(path, ROOT), 'fichier en Windows-1252 : enregistre-le en UTF-8 pour éviter les accents abîmés')
    head = text.split('\n', 1)[0]
    rows = list(csv.DictReader(io.StringIO(text), delimiter=';' if head.count(';') > head.count(',') else ','))
    return [{(k or '').strip().lower(): (v or '').strip() for k, v in r.items()} for r in rows]

def race_of_file(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    r = by_slug.get(stem) or by_key.get(stem)
    if not r:
        check('error', os.path.relpath(path, ROOT), f'nom de fichier inconnu : attendu un des noms {", ".join(sorted(by_slug))}')
    return r

def patch_order(p):
    return tuple(int(x) for x in re.findall(r'\d+', p))

# ---------- regroupement des cartes (règle validée) ----------
def rule_group(card):
    t, o = card['t'], card['opts'][0]
    if t in ('commander', 'heroes_agents'): return 'characters'
    if t == 'infantry': return 'infantry'
    if t in ('missile_infantry', 'missile_cavalry_chariots', 'missile_monster_beasts'): return 'range'
    if t == 'artillery_war_machines': return 'range' if o['role'] == 'artillery' else 'monsters'
    if t == 'flying_war_machine': return 'range' if any(stat(x['u'], 'range') for x in card['opts']) else 'monsters'
    if t in ('cavalry_chariots', 'monster_beasts', 'constructs'): return 'monsters'
    return None   # campaign_exclusives : hors page

# ---------- tier lists ----------
tier_files = {}
if os.path.isdir(TIER_DIR):
    for f in sorted(os.listdir(TIER_DIR)):
        if not f.lower().endswith('.csv') or f.startswith('_'): continue   # _template.csv : modèle, ignoré
        path = os.path.join(TIER_DIR, f); r = race_of_file(path)
        if not r: continue
        rows, seen = {}, set()
        for i, row in enumerate(read_csv(path), start=2):
            k = row.get('root_unit_key', '')
            if not k: continue
            where = f'config/tier_lists/{f}:{i}'
            if row.get('race_key') and row['race_key'] != r['key']:
                check('error', where, f"race_key {row['race_key']} ne correspond pas au fichier ({r['key']})")
            if k in seen: check('warning', where, f'{k} apparaît deux fois, la dernière ligne est gardée')
            seen.add(k)
            t = row.get('tier', '').lower()
            if t and t not in TIERS:
                check('error', where, f"tier « {row['tier']} » invalide pour {row.get('unit_name') or k} (attendu : {', '.join(TIERS)})"); t = ''
            g = row.get('group', '').lower()
            if g and g not in GROUPS:
                check('error', where, f"groupe « {row['group']} » invalide (attendu : {', '.join(GROUPS)})"); g = ''
            rows[k] = {'tier': t, 'note': row.get('note', ''), 'group': g, 'line': where, 'name': row.get('unit_name', '')}
        tier_files[r['key']] = rows

# ---------- meta breakdowns ----------
metas = {}
if os.path.isdir(META_DIR):
    for f in sorted(os.listdir(META_DIR)):
        if not f.lower().endswith('.csv') or f.startswith('_'): continue   # _template.csv : modèle, ignoré
        path = os.path.join(META_DIR, f); r = race_of_file(path)
        if not r: continue
        m = {'reviewed': '', 'difficulty': 0, 'adaptability': 0, 'summary': '', 'playstyle': [], 'strengths': [], 'weaknesses': [], 'matchups': {}}
        for i, row in enumerate(read_csv(path), start=2):
            sec, item, val, text = (row.get(k, '') for k in ('section', 'item', 'value', 'text'))
            sec = sec.lower(); where = f'config/meta/{f}:{i}'
            if not sec: continue
            if sec not in SECTIONS:
                check('error', where, f"section « {sec} » inconnue (attendu : {', '.join(sorted(SECTIONS))})"); continue
            if sec == 'race_key':
                if val and val != r['key']: check('error', where, f"race_key {val} ne correspond pas au fichier ({r['key']})")
            elif sec == 'reviewed_patch':
                m['reviewed'] = val
            elif sec in ('difficulty', 'adaptability'):
                if val:
                    if val.isdigit() and 1 <= int(val) <= 5: m[sec] = int(val)
                    else: check('error', where, f'{sec} doit valoir 1 à 5 (lu : {val})')
            elif sec == 'summary':
                m['summary'] = text
            elif sec == 'playstyle':
                if text: m['playstyle'].append(text)
            elif sec in ('strength', 'weakness'):
                if item or text: m[sec + ('s' if sec == 'strength' else 'es')].append({'title': item, 'text': text})
            elif sec == 'matchup':
                foe = by_name.get(item.lower()) or by_key.get(item) or by_slug.get(slug(item)) or by_key.get(D.get('factionCodes', {}).get(item.upper(), ''))
                if not foe: check('error', where, f'faction « {item} » inconnue dans les matchups'); continue
                if foe['key'] == r['key']: check('warning', where, 'matchup miroir ignoré'); continue
                if not val: continue
                try: v = int(val.replace('+', ''))
                except ValueError: v = 99
                if v not in (-2, -1, 0, 1, 2): check('error', where, f'matchup {item} : {val} hors de -2…+2'); continue
                m['matchups'][foe['key']] = {'v': v, 'note': text}
        if m['reviewed'] and m['reviewed'] != PATCH:
            check('warning', f'config/meta/{f}', f"guide relu au {m['reviewed']}, les données sont au {PATCH}")
        if not m['reviewed']:
            check('warning', f'config/meta/{f}', 'reviewed_patch manquant')
        metas[r['key']] = m

# symétrie des matchups : A contre B = +1 implique B contre A = -1
for a, ma in metas.items():
    for b, x in ma['matchups'].items():
        y = metas.get(b, {}).get('matchups', {}).get(a)
        if y and y['v'] != -x['v'] and a < b:
            check('warning', 'matchups', f"{by_key[a]['name']} vs {by_key[b]['name']} = {x['v']:+d}, mais "
                                         f"{by_key[b]['name']} vs {by_key[a]['name']} = {y['v']:+d} (attendu {-x['v']:+d})")

# ---------- profils de roster (moyenne des races pour comparaison) ----------
P = D['raceProfiles']
avg = {k: round(statistics.mean(p[k] for p in P.values() if k in p), 1) for k in next(iter(P.values()))}

# ---------- armées d'exemple (préparées pour l'affichage et le lien « Open in builder ») ----------
def upgrades_cost(race_key, keys):
    ups = D.get('up', {}).get(race_key, {}); other, spells = 0, []
    for k in keys:
        u = ups.get(k)
        if not u: continue
        if u[1] == 's': spells.append(u[2] or 0)
        else: other += u[2] or 0
    spells.sort(reverse=True)
    return other + int(sum(c * (1 - 0.047 * i) for i, c in enumerate(spells)) // 1)

def can_rank(opt): return not opt.get('rn') and opt['role'] not in ('lord', 'hero')

def prepare_template(t):
    by_unit = {o['u']: (c, o) for c in D['roster'].get(t['race'], []) for o in c['opts']}
    units, missing, link, cost, models = [], 0, [], 0, 0
    for u, rank, items, *_ in t['units']:
        hit = by_unit.get(u)
        if not hit: missing += 1; continue
        card, opt = hit; up = opt.get('up') or []
        sel = [i[1] for i in items if i[1] in up]
        rank = rank if can_rank(opt) else 0
        base = round(opt['c'] * D['xp'][rank][0]) + D['xp'][rank][1] if can_rank(opt) else opt['c']
        cost += base + upgrades_cost(t['race'], sel)
        models += stat(u, 'unit_size') or 0
        mask = sum(1 << up.index(k) for k in sel)
        link.append(f"{u}~{rank}~{mask:x}")
        units.append({'n': card['n'], 'img': opt.get('img') or card.get('img'), 'tab': card['t'], 'lord': bool(opt.get('l'))})
    lord = next((i for i, x in enumerate(units) if x['lord']), 0)
    if lord: units.insert(0, units.pop(lord))
    if missing: check('warning', f"config/army_templates/{t['file']}", f'{missing} unité(s) absente(s) du roster au {PATCH}')
    issues = ([f'{missing} unit(s) no longer available'] if missing else []) + \
             ([f'Over budget ({cost} / {D["budget"]})'] if cost > D['budget'] else []) + \
             ([f'Too many units ({len(units)} / {D["maxUnits"]})'] if len(units) > D['maxUnits'] else [])
    return {'race': t['race'], 'file': t['file'], 'name': t['name'], 'archs': t['archs'], 'diff': t.get('diff'), 'adapt': t.get('adapt'),
            'strong': t.get('strong', []), 'weak': t.get('weak', []), 'desc': t.get('desc', ''), 'units': units,
            'cost': cost, 'models': models, 'issues': issues, 'a': ','.join(link)}

templates = [prepare_template(t) for t in D.get('templates', [])]

# ---------- instantané du patch courant + comparaison avec le patch précédent ----------
os.makedirs(HISTORY_DIR, exist_ok=True)
snap_cols = ['race_key', 'card_id', 'card_name', 'unit_key', 'option_name', 'cost'] + list(TRACKED)
current = {}
for rk, cards in D['roster'].items():
    for c in cards:
        if not rule_group(c): continue
        for o in c['opts']:
            row = {'race_key': rk, 'card_id': c['id'], 'card_name': c['n'], 'unit_key': o['u'], 'option_name': o['n'], 'cost': o['c']}
            row.update({k: stat(o['u'], k) for k in TRACKED})
            current[(rk, o['u'])] = row
with open(os.path.join(HISTORY_DIR, f'units_{PATCH}.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.DictWriter(f, fieldnames=snap_cols, lineterminator='\n'); w.writeheader()
    for k in sorted(current): w.writerow({c: ('' if current[k][c] is None else current[k][c]) for c in snap_cols})

older = sorted((m.group(1) for m in (re.match(r'units_(.+)\.csv$', f) for f in os.listdir(HISTORY_DIR)) if m),
               key=patch_order)
older = [p for p in older if patch_order(p) < patch_order(PATCH)]
PREV = older[-1] if older else None
num = lambda v: None if v in ('', None) else float(v)
changes = {}
if PREV:
    prev = {(r['race_key'], r['unit_key']): r for r in csv.DictReader(open(os.path.join(HISTORY_DIR, f'units_{PREV}.csv'), encoding='utf-8'))}
    prev_cards = {(r['race_key'], r['card_id']) for r in prev.values()}
    cur_cards = {(r['race_key'], r['card_id']) for r in current.values()}
    for rk, cards in D['roster'].items():
        out = {'changed': [], 'added': [], 'removed': []}
        for c in cards:
            g = rule_group(c)
            if not g: continue
            base = {'n': c['n'], 'img': c.get('img') or next((o.get('img') for o in c['opts'] if o.get('img')), None), 'tab': c['t'], 'g': g}
            if (rk, c['id']) not in prev_cards:
                out['added'].append({**base, 'what': 'New card'}); continue
            sigs = []
            for o in c['opts']:
                old = prev.get((rk, o['u']))
                if not old:
                    out['added'].append({**base, 'what': f"New option: {o['n']}"}); continue
                ca, cb = num(old['cost']), o['c']
                st = [[TRACKED[k], num(old[k]), stat(o['u'], k)] for k in TRACKED
                      if num(old[k]) != (None if stat(o['u'], k) is None else float(stat(o['u'], k)))]
                if ca != cb or st:
                    sigs.append((o, ca, cb, st))
            if not sigs: continue
            same = len(sigs) == len(c['opts']) > 1 and len({json.dumps([s[2] - s[1], s[3]]) for s in sigs}) == 1
            if same:
                o, ca, cb, st = sigs[0]
                out['changed'].append({**base, 'opt': 'All options', 'cost': [None, None, cb - ca] if ca != cb else None, 'stats': st})
            else:
                for o, ca, cb, st in sigs:
                    out['changed'].append({**base, 'opt': o['n'] if len(c['opts']) > 1 else '', 'cost': [ca, cb, cb - ca] if ca != cb else None, 'stats': st})
        for (prk, cid) in sorted(prev_cards - cur_cards):
            if prk == rk:
                name = next(r['card_name'] for r in prev.values() if r['race_key'] == prk and r['card_id'] == cid)
                out['removed'].append({'n': name, 'what': 'Removed from the PvP roster'})
        changes[rk] = out

# ---------- données de la page ----------
def cards_of(rk):
    tl = tier_files.get(rk, {}); out = []; known = set()
    for c in D['roster'].get(rk, []):
        g = rule_group(c)
        if not g: continue
        key = c['id'].split('|', 1)[1]; known.add(key)
        row = tl.get(key, {})
        if row.get('group') and row['group'] != g:
            g = row['group']   # exception choisie dans la tier list (ex. Doomwheel)
        o = c['opts'][0]
        out.append({'key': key, 'n': c['n'], 'g': g, 'tab': c['t'], 'grp': c.get('grp'), 'min': c['min'], 'max': c['max'],
                    'nopts': len(c['opts']), 'lord': o['role'] == 'lord', 'char': o['role'] in ('lord', 'hero'), 'rn': bool(o.get('rn')),
                    'utier': stat(o['u'], 'tier'), 'ic': o.get('ic'),
                    'img': c.get('img') or next((x.get('img') for x in c['opts'] if x.get('img')), None),
                    't': row.get('tier') or None, 'note': row.get('note', '')})
    for k, row in tl.items():
        if k not in known: check('error', row['line'], f"unité inconnue au {PATCH} : {row['name'] or k}")
    return out

pages = {}
for r in races:
    rk = r['key']; cards = cards_of(rk)
    pages[rk] = {'cards': cards, 'meta': metas.get(rk), 'changes': changes.get(rk)}
    if rk in tier_files:
        n = sum(1 for c in cards if c['t'])
        if n < len(cards): check('info', f"config/tier_lists/{slug(r['name'])}.csv", f'{n} / {len(cards)} cartes notées')

payload = {
    'patch': PATCH, 'prev': PREV, 'budget': D['budget'],
    'races': [{'key': r['key'], 'name': r['name'], 'slug': slug(r['name']), 'accent': r.get('accent'), 'strip': r.get('race_image'),
               'art': r.get('art'), 'code': code_of.get(r['key']), 'guide': r['key'] in metas, 'tiers': r['key'] in tier_files} for r in races],
    'pages': pages, 'profiles': P, 'avg': avg, 'templates': templates,
    'archetypes': D.get('archetypes', []), 'factionCodes': D.get('factionCodes', {}),
    'skin': D['skin'], 'tabColors': TAB_COLORS, 'statIcons': D.get('statIcons', {}),
}
data = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
tpl = open(TEMPLATE, encoding='utf-8').read()
marker = '/*__DATA__*/null'
if marker not in tpl: sys.exit(f'Marqueur {marker} absent de app/meta_template.html')
open(OUT, 'w', encoding='utf-8').write(tpl.replace(marker, data))

os.makedirs(os.path.dirname(CHECKS), exist_ok=True)
with open(CHECKS, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f); w.writerow(['level', 'where', 'message']); w.writerows(checks)

print(OUT)
print(f"{PATCH} | {len(races)} factions | tier lists : {len(tier_files)} | meta breakdowns : {len(metas)} | "
      f"armées d'exemple : {len(templates)} | patch changes : {'comparé à ' + PREV if PREV else 'aucun patch précédent dans history/'}")
errors = [c for c in checks if c[0] == 'error']; warns = [c for c in checks if c[0] == 'warning']
if checks:
    print(f'{len(errors)} erreur(s), {len(warns)} avertissement(s) (détail : exports/meta_checks.csv)')
    for level, where, msg in checks:
        if level != 'info': print(f'  - [{level}] {where} : {msg}')
