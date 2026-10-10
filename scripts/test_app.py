"""Test (facultatif) du builder : il doit rendre exactement les mêmes verdicts que la spécification SQL
(models/validation/army_validation.sql) sur les armées de test (seeds/tests/), et les mêmes prix que
models/validation/unit_price_checks.sql sur les prix relevés en jeu (seeds/tests/test_unit_prices.csv, ±1),
et l'aller-retour des fichiers du jeu : import puis export de chaque tests/fixtures/*.army_setup doit redonner le même
contenu (faction, unités, général, rang, éléments), sauf les unités non jouables en PvP, ignorées à l'import.

Prérequis (une seule fois) :  pip install playwright   puis   python -m playwright install chromium
Usage :                        python scripts/build_app.py   puis   python scripts/test_app.py
"""
import os, sys
import asyncio, csv, collections, glob, struct, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
from playwright.async_api import async_playwright
armies=collections.defaultdict(list); race={}
for r in csv.DictReader(open(os.path.join(ROOT, 'seeds', 'tests', 'test_armies.csv'))):
    armies[r['army_id']].append((int(r['slot']), r['unit_key'])); race[r['army_id']]=r['race_key']
exp={r['army_id']:r['expected_errors'] for r in csv.DictReader(open(os.path.join(ROOT, 'seeds', 'tests', 'test_army_expectations.csv')))}
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); ctx=await b.new_context(accept_downloads=True); pg=await ctx.new_page()
        errs=[]; pg.on('pageerror', lambda e: errs.append(str(e)))
        await pg.goto('file:///' + os.path.join(ROOT, 'docs', 'index.html').replace(os.sep, '/')); await pg.wait_for_timeout(300)
        ok=0
        for aid, units in armies.items():
            keys=[u for _,u in sorted(units)]
            got=await pg.evaluate('([r,k]) => window.builderValidate(r,k)', [race[aid], keys])
            match = got==exp[aid]; ok+=match
            print(('OK ' if match else 'ÉCART'), aid, '| attendu:', exp[aid] or '(valide)', '| builder:', got or '(valide)')
        print(f'{ok}/{len(armies)} verdicts identiques | erreurs JS: {errs}')
        cases = collections.defaultdict(lambda: {'keys': []})
        for r in csv.DictReader(open(os.path.join(ROOT, 'seeds', 'tests', 'test_unit_prices.csv'), encoding='utf-8')):
            c = cases[r['case_id']]; c.update(race=r['race_key'], unit=r['unit_key'], expected=int(r['expected_price']))
            if r['upgrade_key']: c['keys'].append(r['upgrade_key'])
        price_ok = 0
        for cid, c in cases.items():
            got = await pg.evaluate('([r,u,k]) => window.builderPrice(r,u,k)', [c['race'], c['unit'], c['keys']])
            good = got is not None and abs(got - c['expected']) <= 1; price_ok += good
            print(('OK ' if good else 'ÉCART'), cid, '| jeu:', c['expected'], '| builder:', got)
        print(f'{price_ok}/{len(cases)} prix conformes (±1)')
        ok = ok if price_ok == len(cases) else -1

        # aller-retour .army_setup (import -> export) sur les fichiers enregistrés en jeu
        def parse(path):
            d = open(path, 'rb').read(); p = 0
            def take(n):
                nonlocal p; b = d[p:p + n]; p += n; return b
            u16 = lambda: struct.unpack('<H', take(2))[0]; u32 = lambda: struct.unpack('<I', take(4))[0]
            st = lambda: take(u16()).decode('utf-8')
            head = (u32(), st(), st(), take(1)[0]); units = []
            for _ in range(u32()):
                key, fac, gen = st().split(':'); block = take(15)
                items = sorted((take(1)[0], st()) for _ in range(u32())); st()
                units.append((key, gen, block[7], tuple(items)))
            return head, units
        await pg.evaluate("localStorage.setItem('tww3-builder:help-seen', '1')")
        pg.on('dialog', lambda dlg: asyncio.ensure_future(dlg.accept()))
        trip_ok = trip_n = 0
        for f in sorted(glob.glob(os.path.join(ROOT, 'tests', 'fixtures', '*.army_setup'))):
            await pg.set_input_files('#importFile', f); await pg.wait_for_timeout(300)
            async with pg.expect_download() as dl:
                await pg.click('#exportBtn')
            out = os.path.join(tempfile.gettempdir(), 'roundtrip.army_setup'); await (await dl.value).save_as(out)
            (h1, u1), (h2, u2) = parse(f), parse(out)
            playable = set(await pg.evaluate("Object.values(DATA.roster).flat().flatMap(c => c.opts.map(o => o.u))"))
            u1 = [x for x in u1 if x[0] in playable]
            good = h1[:3] == h2[:3] and u1 == u2; trip_n += 1; trip_ok += good
            print(('OK ' if good else 'ÉCART'), 'aller-retour', os.path.basename(f))
        print(f'{trip_ok}/{trip_n} fichiers .army_setup identiques après import puis export')
        ok = ok if trip_ok == trip_n else -1
        await b.close()
        return ok == len(armies) and not errs
sys.exit(0 if asyncio.run(main()) else 1)
