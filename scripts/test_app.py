"""Test (facultatif) du builder : il doit rendre exactement les mêmes verdicts que la spécification SQL
(models/validation/army_validation.sql) sur les armées de test (seeds/tests/), et les mêmes prix que
models/validation/unit_price_checks.sql sur les prix relevés en jeu (seeds/tests/test_unit_prices.csv, ±1).

Prérequis (une seule fois) :  pip install playwright   puis   python -m playwright install chromium
Usage :                        python scripts/build_app.py   puis   python scripts/test_app.py
"""
import os, sys
import asyncio, csv, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
from playwright.async_api import async_playwright
armies=collections.defaultdict(list); race={}
for r in csv.DictReader(open(os.path.join(ROOT, 'seeds', 'tests', 'test_armies.csv'))):
    armies[r['army_id']].append((int(r['slot']), r['unit_key'])); race[r['army_id']]=r['race_key']
exp={r['army_id']:r['expected_errors'] for r in csv.DictReader(open(os.path.join(ROOT, 'seeds', 'tests', 'test_army_expectations.csv')))}
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); pg=await b.new_page()
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
        await b.close()
        return ok == len(armies) and not errs
sys.exit(0 if asyncio.run(main()) else 1)
