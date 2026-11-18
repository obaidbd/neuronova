#!/usr/bin/env python3
"""Builds the compact Bangladesh map assets used by the Map Puzzle game.

Sources (downloaded, not committed):
  * Boundaries: geoBoundaries gbOpen BGD ADM1/ADM2/ADM3 (simplified), derived
    from Bangladesh Bureau of Statistics / OCHA ROAP, CC BY 3.0 IGO.
  * Bengali names and centre points: nuhil/bangladesh-geocode (MIT).

Writes apps/player/assets/maps/bd/{divisions,districts,upazilas}.json with
simplified rings (integer lon/lat in thousandths of a degree, delta coded),
parent links and Bengali names. Standard library only.

Usage: python3 scripts/build_bd_map.py [cache_dir]
"""
import json, math, os, re, sys, urllib.request

CACHE = sys.argv[1] if len(sys.argv) > 1 else '/tmp/bd_map_cache'
OUT = os.path.join(os.path.dirname(__file__), '..', 'apps', 'player', 'assets', 'maps', 'bd')
GB = 'https://media.githubusercontent.com/media/wmgeolab/geoBoundaries/main/releaseData/gbOpen/BGD/%s/geoBoundaries-BGD-%s_simplified.geojson'
NG = 'https://raw.githubusercontent.com/nuhil/bangladesh-geocode/master/%s/%s.json'
# Douglas-Peucker tolerance in degrees (1 degree ~ 111 km), per level.
TOL = {'ADM1': 0.012, 'ADM2': 0.006, 'ADM3': 0.0025}
MIN_RING_AREA = {'ADM1': 0.0004, 'ADM2': 0.00008, 'ADM3': 0.000012}  # deg^2; tiny islands dropped

DIV_BN = {'Chittagong': 'চট্টগ্রাম', 'Dhaka': 'ঢাকা', 'Mymensingh': 'ময়মনসিংহ',
          'Rajshani': 'রাজশাহী', 'Rangpur': 'রংপুর', 'Sylhet': 'সিলেট',
          'Khulna': 'খুলনা', 'Barisal': 'বরিশাল'}
DIV_EN = {'Rajshani': 'Rajshahi', 'Chittagong': 'Chattogram', 'Barisal': 'Barishal'}


# Bengali names for the metropolitan thanas and a few upazilas whose centre
# point in the name dataset falls in a neighbouring polygon.
EXTRA_BN = {
    'Adabor': 'আদাবর', 'Badda': 'বাড্ডা', 'Bangshal': 'বংশাল', 'Biman Bandar': 'বিমানবন্দর',
    'Cantonment': 'ক্যান্টনমেন্ট', 'Chak Bazar': 'চকবাজার', 'Dakshinkhan': 'দক্ষিণখান',
    'Darus Salam': 'দারুস সালাম', 'Demra': 'ডেমরা', 'Dhanmondi': 'ধানমন্ডি',
    'Gendaria': 'গেণ্ডারিয়া', 'Gulshan': 'গুলশান', 'Hazaribagh': 'হাজারীবাগ',
    'Jatrabari': 'যাত্রাবাড়ী', 'Kadamtali': 'কদমতলী', 'Kafrul': 'কাফরুল',
    'Kalabagan': 'কলাবাগান', 'Kamrangir Char': 'কামরাঙ্গীরচর', 'Khilgaon': 'খিলগাঁও',
    'Khilkhet': 'খিলক্ষেত', 'Lalbagh': 'লালবাগ', 'Mirpur': 'মিরপুর',
    'Mohammadpur': 'মোহাম্মদপুর', 'Motijheel': 'মতিঝিল', 'New Market': 'নিউ মার্কেট',
    'Pallabi': 'পল্লবী', 'Paltan': 'পল্টন', 'Ramna': 'রমনা', 'Rampura': 'রামপুরা',
    'Sabujbagh': 'সবুজবাগ', 'Shah Ali': 'শাহ আলী', 'Shahbagh': 'শাহবাগ',
    'Sher-e-bangla Nagar': 'শেরেবাংলা নগর', 'Shyampur': 'শ্যামপুর', 'Sutrapur': 'সূত্রাপুর',
    'Tejgaon': 'তেজগাঁও', 'Tejgaon Ind. Area': 'তেজগাঁও শিল্প এলাকা', 'Turag': 'তুরাগ',
    'Uttar Khan': 'উত্তরখান', 'Uttara': 'উত্তরা',
    'Bakalia': 'বাকলিয়া', 'Bayejid Bostami': 'বায়েজিদ বোস্তামী', 'Chandgaon': 'চান্দগাঁও',
    'Chittagong Port': 'বন্দর', 'Double Mooring': 'ডবলমুরিং', 'Halishahar': 'হালিশহর',
    'Khulshi': 'খুলশী', 'Pahartali': 'পাহাড়তলী', 'Panchlaish': 'পাঁচলাইশ',
    'Patenga': 'পতেঙ্গা', 'Sitakunda': 'সীতাকুণ্ড',
    'Daulatpur': 'দৌলতপুর', 'Khalishpur': 'খালিশপুর', 'Khan Jahan Ali': 'খানজাহান আলী',
    'Khulna Sadar': 'খুলনা সদর', 'Sonadanga': 'সোনাডাঙ্গা',
    'Boalia': 'বোয়ালিয়া', 'Matihar': 'মতিহার', 'Rajpara': 'রাজপাড়া', 'Shah Makhdum': 'শাহ মখদুম',
    'Daulatkhan': 'দৌলতখান', 'Manpura': 'মনপুরা', 'Tazumuddin': 'তজুমদ্দিন',
    'Gazipur Sadar': 'গাজীপুর সদর', 'Ramgati': 'রামগতি', 'Sarankhola': 'শরণখোলা',
}
KOTWALI = 'কোতোয়ালী'
# Display spellings for districts (the boundary data uses older ones).
DISTRICT_EN = {
    'Barisal': 'Barishal', 'Bogra': 'Bogura', 'Brahamanbaria': 'Brahmanbaria',
    'Chittagong': 'Chattogram', 'Comilla': 'Cumilla', 'Jessore': 'Jashore',
    'Jhalokati': 'Jhalakathi', 'Khagrachhari': 'Khagrachari', 'Maulvibazar': 'Moulvibazar',
    'Nawabganj': 'Chapai Nawabganj', 'Netrakona': 'Netrokona',
}


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        with urllib.request.urlopen(url, timeout=120) as r, open(path, 'wb') as f:
            f.write(r.read())
    return json.load(open(path, encoding='utf-8'))


def ng_table(folder, table):
    data = fetch(NG % (folder, folder), table + '.json')
    for item in data:
        if item.get('type') == 'table':
            return item['data']
    raise SystemExit('bad table ' + table)


def rings_of(geom):
    polys = geom['coordinates'] if geom['type'] == 'MultiPolygon' else [geom['coordinates']]
    return [p[0] for p in polys]  # outer rings only


def area(r):
    return abs(sum(r[i][0] * r[(i + 1) % len(r)][1] - r[(i + 1) % len(r)][0] * r[i][1]
                   for i in range(len(r)))) / 2


def dp(points, tol):
    if len(points) < 4:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        ax, ay = points[a]
        bx, by = points[b]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy) or 1e-12
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            d = abs((points[i][0] - ax) * dy - (points[i][1] - ay) * dx) / norm
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    return [p for p, k in zip(points, keep) if k]


def pip(pt, ring):
    x, y = pt
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def inside_unit(pt, rings):
    return any(pip(pt, r) for r in rings)


def seg_dist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = 0 if dx == dy == 0 else max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def label_point(rings):
    """A point well inside the biggest ring (grid search for the deepest one)."""
    big = max(rings, key=area)
    xs = [p[0] for p in big]
    ys = [p[1] for p in big]
    best, bp = -1, (sum(xs) / len(xs), sum(ys) / len(ys))
    n = 18
    for i in range(1, n):
        for j in range(1, n):
            q = (min(xs) + (max(xs) - min(xs)) * i / n, min(ys) + (max(ys) - min(ys)) * j / n)
            if not pip(q, big):
                continue
            d = min(seg_dist(q, big[k], big[(k + 1) % len(big)]) for k in range(len(big)))
            if d > best:
                best, bp = d, q
    return bp


def load_level(lvl):
    d = fetch(GB % (lvl, lvl), 'BGD_%s.geojson' % lvl)
    units = []
    for f in d['features']:
        rings = [r for r in rings_of(f['geometry'])]
        rings.sort(key=area, reverse=True)
        kept = [r for r in rings if area(r) >= MIN_RING_AREA[lvl]] or rings[:1]
        simp = []
        for r in kept:
            s = dp(r[:-1], TOL[lvl])
            if len(s) >= 3:
                simp.append(s)
        units.append({'en': f['properties']['shapeName'], 'rings': simp,
                      'label': label_point(simp), 'raw': rings})
    return units


def main():
    adm1, adm2, adm3 = load_level('ADM1'), load_level('ADM2'), load_level('ADM3')
    # ids
    for i, u in enumerate(adm1):
        u['id'] = 'd%d' % (i + 1)
    for i, u in enumerate(adm2):
        u['id'] = 'z%02d' % (i + 1)
    for i, u in enumerate(adm3):
        u['id'] = 'u%03d' % (i + 1)
    # parents by label point
    for u in adm2:
        u['parent'] = next((v['id'] for v in adm1 if inside_unit(u['label'], v['raw'])), '')
    for u in adm3:
        pz = next((v for v in adm2 if inside_unit(u['label'], v['raw'])), None)
        u['parent'] = pz['id'] if pz else ''
    # Bengali names
    ng_dist = ng_table('districts', 'districts')
    ng_upz = ng_table('upazilas', 'upazilas')
    for u in adm1:
        u['bn'] = DIV_BN.get(u['en'], '')
        u['en'] = DIV_EN.get(u['en'], u['en'])
    for u in adm2:
        u['bn'] = ''
    for row in ng_dist:
        pt = (float(row['lon']), float(row['lat']))
        hit = [u for u in adm2 if inside_unit(pt, u['raw'])]
        if len(hit) == 1 and not hit[0]['bn']:
            hit[0]['bn'] = row['bn_name']
    # fall back to nearest centre for unresolved districts
    for u in adm2:
        if not u['bn']:
            best = min(ng_dist, key=lambda r: math.hypot(float(r['lon']) - u['label'][0], float(r['lat']) - u['label'][1]))
            if all(v['bn'] != best['bn_name'] for v in adm2):
                u['bn'] = best['bn_name']
    for u in adm3:
        u['bn'] = ''
    taken = set()
    for row in ng_upz:
        pt = (float(row['lon']), float(row['lat']))
        hit = [u for u in adm3 if inside_unit(pt, u['raw']) and u['id'] not in taken]
        if len(hit) == 1:
            hit[0]['bn'] = row['bn_name']
            taken.add(hit[0]['id'])
    dist_by_id = {u['id']: u for u in adm2}
    for u in adm3:
        if not u['bn']:
            u['bn'] = KOTWALI if u['en'] == 'Kotwali' else EXTRA_BN.get(u['en'], '')
    for u in adm2:
        u['en'] = DISTRICT_EN.get(u['en'], u['en'])
    miss = lambda us: [u['en'] for u in us if not u['bn']]
    print('divisions', len(adm1), 'missing bn', miss(adm1))
    print('districts', len(adm2), 'missing bn', miss(adm2))
    print('upazilas', len(adm3), 'missing bn', len(miss(adm3)))
    os.makedirs(OUT, exist_ok=True)
    for name, units in (('divisions', adm1), ('districts', adm2), ('upazilas', adm3)):
        out = []
        for u in units:
            rings = []
            for r in u['rings']:
                pts = [(round(x * 1000), round(y * 1000)) for x, y in r]
                flat, px, py = [], 0, 0
                for x, y in pts:
                    flat += [x - px, y - py]
                    px, py = x, y
                rings.append(flat)
            out.append({'i': u['id'], 'n': u['en'], 'b': u['bn'], 'p': u.get('parent', ''),
                        'l': [round(u['label'][0] * 1000), round(u['label'][1] * 1000)], 'r': rings})
        path = os.path.join(OUT, name + '.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump({'units': out}, f, ensure_ascii=False, separators=(',', ':'))
        print(name, os.path.getsize(path), 'bytes')


if __name__ == '__main__':
    main()
