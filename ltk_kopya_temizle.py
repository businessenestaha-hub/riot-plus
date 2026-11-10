# LTK bir paketi yerinde güncellemeyip "<slug>-2" diye ikinci kopya eklerse: ESKİ kopyayı kaldırır, Riot Plus seçimini yeniye çevirir.
# 9 Kas 2026. Riot Plus KAPALIYKEN çalıştır. kullanim: py ltk_kopya_temizle.py
import json, os, shutil, subprocess, time
D = os.path.join(os.environ['APPDATA'], 'dev.leaguetoolkit.manager')
RP = r'C:\Users\Gaming\projects\lol-duzelt\ayarlar.json'


def oku(y):
    return json.load(open(y, encoding='utf-8-sig'))


def yaz(y, o, crlf=False):
    with open(y, 'w', encoding='utf-8', newline='\r\n' if crlf else '\n') as f:
        f.write(json.dumps(o, ensure_ascii=False, indent=2))


subprocess.run(['powershell', '-NoProfile', '-Command', "Get-Process | Where-Object { $_.ProcessName -match '^ltk' } | Stop-Process -Force"], capture_output=True)
time.sleep(2)
zaman = time.strftime('%Y%m%d-%H%M%S')
shutil.copy(f'{D}/library.json', f'{D}/library.json.kopya-{zaman}-yedek')
lib = oku(f'{D}/library.json')
slug = {m['slug']: m for m in lib['mods']}
eski_yeni = {}
for s, m in slug.items():
    if s.endswith('-2') and s[:-2] in slug:
        eski_yeni[slug[s[:-2]]['id']] = (s[:-2], m['id'], s)
sil = set(eski_yeni)
lib['mods'] = [m for m in lib['mods'] if m['id'] not in sil]
for f in lib.get('folders', []):
    f['modIds'] = [x for x in f.get('modIds', []) if x not in sil]
for p in lib.get('profiles', []):
    for k in ('enabledMods', 'modOrder'):
        if k in p:
            p[k] = [x for x in p[k] if x not in sil]
yaz(f'{D}/library.json', lib)
for ad, alan in (('mod-health-verdicts.json', 'verdicts'), ('wad-reports.json', 'reports')):
    y = f'{D}/{ad}'
    if os.path.exists(y):
        o = oku(y)
        for i in sil:
            o.get(alan, {}).pop(i, None)
        yaz(y, o)
for eid, (eslug, yid, yslug) in eski_yeni.items():
    for y in (f'{D}\\mods\\{eslug}', f'{D}\\mods\\{eslug}.fantome'):
        if os.path.exists(y):
            tur = 'DeleteDirectory' if os.path.isdir(y) else 'DeleteFile'
            subprocess.run(['powershell', '-NoProfile', '-Command', f"Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::{tur}('{y}', 'OnlyErrorDialogs', 'SendToRecycleBin')"])
    print('eski kaldirildi:', eslug, '->', yslug)
rp = oku(RP)
cs = rp.get('customSecim', {})
for k, v in list(cs.items()):
    if v in eski_yeni:
        cs[k] = eski_yeni[v][1]
        print('secim:', k, '->', eski_yeni[v][2])
yaz(RP, rp, crlf=True)
print('BITTI', len(lib['mods']), 'mod')
