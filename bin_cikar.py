# Bir şampiyonun oyundaki veri (.bin) dosyalarını tek zip'e çıkarır; custom skin hazırlarken özgün dosyalar gerektiğinde
# Obsidian'la uğraşmamak için. Oyunun dosyalarına dokunmaz, yalnız okur.
#
# Kullanım:  python bin_cikar.py Talon            -> Masaüstü\Talon-bin.zip
#            python bin_cikar.py Talon "D:\Riot Games\League of Legends"    (oyun başka yerdeyse)
# Gerekenler: zstandard ve xxhash (rose_yerinde.py ile aynı)
import os, string, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rose_yerinde import Wad, Olmaz, oyun_wad_bul


def champions_bul(verilen):
    adaylar = []
    if verilen: adaylar.append(verilen)
    for harf in string.ascii_uppercase[2:]:
        adaylar.append('%s:\\Riot Games\\League of Legends' % harf)
        adaylar.append('%s:\\Program Files\\Riot Games\\League of Legends' % harf)
    for a in adaylar:
        for ek in ('', os.path.join('Game', 'DATA', 'FINAL', 'Champions')):
            y = os.path.join(a, ek)
            if os.path.isdir(y) and any(x.lower().endswith('.wad.client') for x in os.listdir(y)): return y
    return None


def main():
    if len(sys.argv) < 2:
        print('kullanim: python bin_cikar.py <Sampiyon> [LoL klasoru]'); return 2
    sampiyon = sys.argv[1]
    klasor = champions_bul(sys.argv[2] if len(sys.argv) > 2 else None)
    if not klasor: print('Oyun klasorunu bulamadim; LoL klasorunu ikinci deger olarak yaz.'); return 2
    wad_yol = oyun_wad_bul(klasor, sampiyon)
    if not wad_yol: print('%s icin dosya yok: %s' % (sampiyon, klasor)); return 2
    masaustu = os.path.join(os.path.expanduser('~'), 'Desktop')
    if not os.path.isdir(masaustu): masaustu = os.getcwd()
    cikti = os.path.join(masaustu, '%s-bin.zip' % sampiyon)
    adet = 0
    with open(wad_yol, 'rb') as d, zipfile.ZipFile(cikti, 'w', zipfile.ZIP_DEFLATED) as z:
        wad = Wad(d)
        for h in sorted(wad.satir):
            try: v = wad.dosya(h)
            except Olmaz: continue
            if v[:4] == b'PROP':
                z.writestr('%016x.bin' % h, v); adet += 1
    print('%d dosya -> %s' % (adet, cikti))
    return 0


if __name__ == '__main__':
    sys.exit(main())
