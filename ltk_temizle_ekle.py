# LTK kütüphanesi bakımı (9 Kas 2026; Enes: "ltk managerda bize ait olmayan customları kaldıralım"):
#   --temizle            : slug'ı "rehabilite-" ile başlamayan modları kaldırır (library.json mods/folders/profiles,
#                          mod-health-verdicts.json, wad-reports.json; mod dosyaları Geri Dönüşüm Kutusu'na)
#   --ekle a.fantome ... : LTK'ya içe alır (ltk-manager.exe <dosyalar>), library.json'da görünmesini bekler, LTK'yı durdurur
#   --sec 157=slug ...   : Riot Plus ayarlar.json customSecim (şampiyon id -> mod) ; silinmiş moda bakan seçimler her zaman temizlenir
# Riot Plus KAPALIYKEN ve maç açık DEĞİLKEN çalıştır (Riot Plus açıkken ayarlar.json'u kendi yazar).
# JSON'lar Python ile düzenlenir: wad-reports.json'daki 64 bit parmak izi PowerShell'de yuvarlanıp bozulur.
import argparse, json, os, shutil, subprocess, sys, time

D = os.path.join(os.environ['APPDATA'], 'dev.leaguetoolkit.manager')
LTK = r'C:\Program Files\LTK Manager\ltk-manager.exe'
RP = r'C:\Users\Gaming\projects\lol-duzelt\ayarlar.json'


def oku(y):
    return json.load(open(y, encoding='utf-8-sig'))


def yaz(y, o, crlf=False):
    m = json.dumps(o, ensure_ascii=False, indent=2)
    with open(y, 'w', encoding='utf-8', newline='\r\n' if crlf else '\n') as f:
        f.write(m)


def surecler():
    c = subprocess.run(['tasklist', '/fo', 'csv', '/nh'], capture_output=True, text=True, errors='replace').stdout
    return [l.split('","')[0].strip('"') for l in c.splitlines() if l]


def riot_plus_acik():
    c = subprocess.run(['powershell', '-NoProfile', '-Command',
                        "(Get-Process | Where-Object { $_.MainWindowTitle -eq 'Riot Plus' }).Count"], capture_output=True, text=True)
    return c.stdout.strip() not in ('', '0')


def ltk_durdur():
    if any(p.lower().startswith('ltk') for p in surecler()):
        subprocess.run(['taskkill', '/im', 'ltk-manager.exe'], capture_output=True)
        time.sleep(3)
        subprocess.run(['powershell', '-NoProfile', '-Command',
                        "Get-Process | Where-Object { $_.ProcessName -match '^ltk' } | Stop-Process -Force"], capture_output=True)
        time.sleep(1)


def geri_donusum(y):
    tur = 'DeleteDirectory' if os.path.isdir(y) else 'DeleteFile'
    subprocess.run(['powershell', '-NoProfile', '-Command',
                    f"Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::{tur}('{y}', 'OnlyErrorDialogs', 'SendToRecycleBin')"],
                   check=True)


a = argparse.ArgumentParser()
a.add_argument('--temizle', action='store_true')
a.add_argument('--ekle', nargs='*', default=[])
a.add_argument('--sec', nargs='*', default=[])
a = a.parse_args()
if riot_plus_acik():
    sys.exit('Riot Plus acik: once kapat')
if 'League of Legends.exe' in surecler():
    sys.exit('Mac acik: LTK ye dokunma')
zaman = time.strftime('%Y%m%d-%H%M')
shutil.copy(f'{D}/library.json', f'{D}/library.json.temizlik-{zaman}-yedek')
os.makedirs(r'C:\Users\Gaming\projects\lol-duzelt\yedek', exist_ok=True)
shutil.copy(RP, rf'C:\Users\Gaming\projects\lol-duzelt\yedek\ayarlar-{zaman}.json')

if a.temizle:
    ltk_durdur()
    lib = oku(f'{D}/library.json')
    sil = [m for m in lib['mods'] if not m['slug'].startswith('rehabilite-')]
    sid = {m['id'] for m in sil}
    lib['mods'] = [m for m in lib['mods'] if m['id'] not in sid]
    for f in lib.get('folders', []):
        f['modIds'] = [x for x in f.get('modIds', []) if x not in sid]
    for p in lib.get('profiles', []):
        for k in ('enabledMods', 'modOrder'):
            if k in p:
                p[k] = [x for x in p[k] if x not in sid]
    yaz(f'{D}/library.json', lib)
    for ad, alan in (('mod-health-verdicts.json', 'verdicts'), ('wad-reports.json', 'reports')):
        y = f'{D}/{ad}'
        if os.path.exists(y):
            shutil.copy(y, f'{y}.temizlik-{zaman}-yedek')
            o = oku(y)
            for i in sid:
                o.get(alan, {}).pop(i, None)
            yaz(y, o)
    for m in sil:
        for y in (f"{D}\\mods\\{m['slug']}", f"{D}\\mods\\{m['slug']}.fantome"):
            if os.path.exists(y):
                geri_donusum(y)
        print('kaldirildi:', m['slug'])
    print(f'toplam kaldirilan {len(sil)}, kalan {len(lib["mods"])}')

if a.ekle:
    once = {m['slug']: m['sourceSha256'] for m in oku(f'{D}/library.json')['mods']}
    # 9 Kas: LTK'da birebir aynısı olan dosyayı atla (yoksa "değişen mod" sayısı hiç tutmaz, zaman aşımına kadar bekler)
    import hashlib
    var_sha = set(once.values())
    yeni_liste = []
    for f in a.ekle:
        h = hashlib.sha256(open(f, 'rb').read()).hexdigest()
        if h in var_sha:
            print('ayni, atlandi:', os.path.basename(f))
        else:
            yeni_liste.append(f)
    a.ekle = yeni_liste
if a.ekle:
    subprocess.Popen([LTK] + a.ekle)
    bas = time.time()
    while True:
        time.sleep(3)
        try:
            simdi = oku(f'{D}/library.json')['mods']
        except Exception:
            continue
        yeni = [m for m in simdi if once.get(m['slug']) != m['sourceSha256']]
        if len(yeni) >= len(a.ekle) or time.time() - bas > 120 + 40 * len(a.ekle):
            break
    for m in yeni:
        print('eklendi:', m['slug'], m['id'])
    if len(yeni) < len(a.ekle):
        print(f'UYARI: {len(a.ekle)} dosyadan {len(yeni)} tanesi gorundu')
    time.sleep(5)
    ltk_durdur()

rp = oku(RP)
lib = oku(f'{D}/library.json')
var = {m['id'] for m in lib['mods']}
slug = {m['slug']: m['id'] for m in lib['mods']}
cs = rp.setdefault('customSecim', {})
for k in list(cs):
    if cs[k] not in var:
        print('secim kaldirildi: sampiyon', k)
        del cs[k]
for s in a.sec:
    k, v = s.split('=', 1)
    if v in slug:
        cs[k] = slug[v]
        print('secim:', k, '->', v)
    else:
        print('UYARI secim yok:', v)
yaz(RP, rp, crlf=True)
print('BITTI')
