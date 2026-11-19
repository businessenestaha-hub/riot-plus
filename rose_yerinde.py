# Bir custom skin modunu Rose'da efektleriyle çalışacak hale getirir ("yerinde" sürüm).
#
# Sorun (19 Kas 2026, Zed / Talon modlarında görüldü): Rose, bir skinin üstüne eklenen modda kostümün efekt tablosunu
# (skin<N>.bin içindeki ResourceResolver: kaynak adı -> efekt girdisi) moddan okumaz, özgün skininkini kullanır. Mod
# efektlerini yeni anahtarlarla ya da kendi eklediği ayrı bir dosyada taşıyorsa (ör. data/talon_vfx_skin0.bin) oyun
# onları hiç aramaz: dokular gelir, yetenek efektleri özgün kalır.
#
# Çözüm: modun efekt girdileri, oyunun zaten okuduğu dosyaların İÇİNE, özgün anahtarlarıyla yazılır:
#   - modun tablosu bir adı başka girdiye bağlıyorsa, o girdinin gövdesi özgün girdinin yerine konur;
#   - modun yalnız kendinde olan dosyalardaki girdiler: anahtarı oyunda varsa oradaki girdinin yerine konur, yoksa
#     modun skin<N>.bin'ine eklenir (o dosya yüklenir).
# Tabloya, klasik skin dosyasına (skin0.bin) dokunulmaz; pakete skin0.bin EKLENMEZ.
#
# Yan etki: özgün girdi birkaç kostümün paylaştığı dosyadaysa (..._Skins_Skin12_Skins_Skin13...bin) o kostümlerde de
# modun efekti görünür. Hangi dosyaların değiştiği çıktıda yazılır.
#
# Oyunun güncel dosyaları gerekir (şampiyonun WAD'ı); oyun yaması gelince yeniden üretilmelidir.
#
# Kullanım:  python rose_yerinde.py giris.fantome "<LoL>\Game\DATA\FINAL\Champions" cikis.fantome
# Çıkış kodu: 0 = üretildi, 3 = gerek yok (mod zaten yerinde çalışıyor), 2 = dönüştürülemedi (sebep stderr'de)
# stdout: tek satır JSON özet (degisen dosyalar, etkilenen kostümler)
# Gerekenler: zstandard ve xxhash  (pip install zstandard xxhash); Python 3.14+ ise zstandard yerine yerleşik olan kullanılır.
import io, json, os, re, struct, sys, zipfile

try:
    import xxhash
except ImportError:
    sys.stderr.write("xxhash modulu yok: pip install xxhash zstandard\n"); sys.exit(2)
try:
    from compression import zstd as _zstd          # Python 3.14+
    def zstd_ac(veri, boyut): return _zstd.decompress(veri)
except ImportError:
    try:
        import zstandard
        def zstd_ac(veri, boyut): return zstandard.ZstdDecompressor().decompress(veri, max_output_size=max(boyut, 1))
    except ImportError:
        sys.stderr.write("zstandard modulu yok: pip install zstandard xxhash\n"); sys.exit(2)

BASLIK = 272          # 'RW' + sürüm(2) + imza(256) + sağlama(8) + dosya sayısı(4)
GIRDI = 32            # yol hash'i(8) konum(4) sıkışık(4) açık(4) tür(1) kopya(1) alt parça(2) sağlama(8)
HAM, ZSTD = 0, 3


class Olmaz(Exception):
    pass


def yol_hash(yol): return xxhash.xxh64_intdigest(yol.lower().encode('utf-8'))


def fnv(metin):
    h = 0x811c9dc5
    for c in metin.lower().encode('utf-8'):
        h = ((h ^ c) * 0x01000193) & 0xffffffff
    return h


T_SKIN = fnv('SkinCharacterDataProperties')
T_COZUCU = fnv('ResourceResolver')
A_TABLO = fnv('resourceMap')


# ---------- BIN ----------
def bin_oku(b):
    """PROP: (sürüm, bağlı dosyalar, girdiler [(tür, anahtar, ham baytlar)])"""
    if b[:4] != b'PROP': raise Olmaz('PROP degil')
    surum = struct.unpack_from('<I', b, 4)[0]
    o = 8; bagli = []
    if surum >= 2:
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        for _ in range(n):
            uz = struct.unpack_from('<H', b, o)[0]; o += 2
            bagli.append(b[o:o + uz].decode('utf-8', 'replace')); o += uz
    adet = struct.unpack_from('<I', b, o)[0]; o += 4
    turler = struct.unpack_from('<%dI' % adet, b, o); o += 4 * adet
    girdiler = []
    for i in range(adet):
        uz = struct.unpack_from('<I', b, o)[0]
        girdiler.append((turler[i], struct.unpack_from('<I', b, o + 4)[0], bytes(b[o:o + 4 + uz]))); o += 4 + uz
    if o != len(b): raise Olmaz('bin beklenen yerde bitmiyor')
    return surum, bagli, girdiler


def bin_yaz(surum, bagli, girdiler):
    c = io.BytesIO()
    c.write(b'PROP' + struct.pack('<I', surum))
    if surum >= 2:
        c.write(struct.pack('<I', len(bagli)))
        for ad in bagli:
            a = ad.encode('utf-8'); c.write(struct.pack('<H', len(a)) + a)
    c.write(struct.pack('<I', len(girdiler)))
    for tur, _, _ in girdiler: c.write(struct.pack('<I', tur))
    for _, _, ham in girdiler: c.write(ham)
    return c.getvalue()


def anahtar_degistir(ham, yeni): return ham[:4] + struct.pack('<I', yeni) + ham[8:]


def tablo_oku(ham):
    """ResourceResolver girdisinden {ad hash'i: efekt anahtarı}. Girdinin ilk alanı resourceMap (map<hash, link>) olmalı."""
    o = 8
    n = struct.unpack_from('<H', ham, o)[0]; o += 2
    for _ in range(n):
        ad, tip = struct.unpack_from('<IB', ham, o); o += 5
        if tip != 0x86: raise Olmaz('efekt tablosu beklenmeyen bicimde (tip %d)' % tip)
        kt, dt, boyut, adet = struct.unpack_from('<BBII', ham, o); o += 10
        if ad != A_TABLO: o += boyut - 4; continue
        if kt not in (7, 17) or dt != 0x84: raise Olmaz('efekt tablosu beklenmeyen bicimde (%d -> %d)' % (kt, dt))
        return dict(struct.unpack_from('<II', ham, o + 8 * i) for i in range(adet))
    return {}


# ---------- WAD ----------
class Wad:
    """Yalnız okur; dosyalar istenince açılır (oyunun WAD'ı büyüktür)."""
    def __init__(self, dosya):
        self.d = dosya
        bas = self._oku(0, BASLIK)
        if bas[:2] != b'RW' or bas[2] != 3: raise Olmaz('WAD surumu desteklenmiyor')
        adet = struct.unpack_from('<I', bas, 268)[0]
        t = self._oku(BASLIK, adet * GIRDI)
        self.satir = {}
        for i in range(adet):
            s = t[i * GIRDI:(i + 1) * GIRDI]
            self.satir[struct.unpack_from('<Q', s, 0)[0]] = s

    def _oku(self, konum, uz):
        self.d.seek(konum); return self.d.read(uz)

    def __contains__(self, h): return h in self.satir

    def ham(self, h):
        konum, sikisik = struct.unpack_from('<II', self.satir[h], 8)
        return self._oku(konum, sikisik)

    def dosya(self, h):
        s = self.satir[h]
        konum, sikisik, acik = struct.unpack_from('<III', s, 8)
        tur = s[20] & 0x0F
        veri = self._oku(konum, sikisik)
        if tur == HAM: return veri
        if tur == ZSTD: return zstd_ac(veri, acik)
        raise Olmaz('desteklenmeyen sikistirma turu: %d' % tur)


def wad_yaz(wad, yeni):
    """Modun WAD'ını, `yeni` {hash: açık veri} dosyaları eklenmiş / değiştirilmiş olarak yeniden yazar. Öteki dosyaların
    baytlarına dokunulmaz; yeni dosyalar ham (sıkıştırılmamış) konur. Tablo hash sırasında kalır."""
    bas = wad._oku(0, 268)
    hepsi = sorted(set(wad.satir) | set(yeni))
    govde = io.BytesIO(); tablo = io.BytesIO()
    konum = BASLIK + GIRDI * len(hepsi)
    tasinan = {}                      # eski konum -> yeni konum (aynı baytı paylaşan girdiler paylaşmaya devam eder)
    for h in hepsi:
        if h in yeni:
            v = yeni[h]
            tablo.write(struct.pack('<QIII', h, konum, len(v), len(v)) + bytes([HAM, 0, 0, 0]) + struct.pack('<Q', xxhash.xxh3_64_intdigest(v)))
            govde.write(v); konum += len(v)
        else:
            s = wad.satir[h]
            eski, sikisik = struct.unpack_from('<II', s, 8)
            if (eski, sikisik) not in tasinan:
                tasinan[(eski, sikisik)] = konum
                govde.write(wad._oku(eski, sikisik)); konum += sikisik
            tablo.write(s[:8] + struct.pack('<I', tasinan[(eski, sikisik)]) + s[12:])
    return bas + struct.pack('<I', len(hepsi)) + tablo.getvalue() + govde.getvalue()


# ---------- dönüşüm ----------
def skinler_bul(ad, wad, en_cok=200):
    return [n for n in range(en_cok) if yol_hash('data/characters/%s/skins/skin%d.bin' % (ad, n)) in wad]


def wad_cevir(sampiyon, mod, oyun):
    """mod, oyun: Wad. Dönüş: ({hash: yeni veri}, özet) ; değişiklik yoksa ({}, özet)"""
    ad = sampiyon.lower()
    # Modun bütün bin dosyaları
    mod_bin = {}
    for h in mod.satir:
        try: v = mod.dosya(h)
        except Olmaz: continue
        if v[:4] == b'PROP':
            try: mod_bin[h] = bin_oku(v)
            except (Olmaz, struct.error): pass
    # Yalnız modda olan dosyalar (oyunda karşılığı yok): Rose'da yüklenmeyebilir, girdileri taşınır
    yalniz_mod = [h for h in mod_bin if h not in oyun]
    havuz = {}                         # anahtar -> (tür, ham) : modun girdileri (yalnız-mod dosyaları önce, üstüne ötekiler)
    for h in yalniz_mod + [h for h in mod_bin if h in oyun]:
        for tur, k, ham in mod_bin[h][2]:
            if tur in (T_SKIN, T_COZUCU): continue
            havuz[k] = (tur, ham)

    cikti = {}                         # hash -> [surum, bagli, girdiler]  (üstünde çalışılan dosyalar)
    dosya_adi = {}
    oyun_onbellek = {}

    def oyun_bin(h):
        if h not in oyun_onbellek:
            try: oyun_onbellek[h] = bin_oku(oyun.dosya(h)) if h in oyun else None
            except (Olmaz, struct.error): oyun_onbellek[h] = None
        return oyun_onbellek[h]

    def calis(h):
        """Üstünde değişiklik yapılacak dosya: modda varsa modunki, yoksa oyununki"""
        if h not in cikti:
            kaynak = mod_bin.get(h) or oyun_bin(h)
            cikti[h] = [kaynak[0], list(kaynak[1]), list(kaynak[2])]
        return cikti[h]

    degisen = {}                       # dosya hash'i -> değişen girdi sayısı
    eklenen = 0; bulunamayan = 0

    def yerine_koy(h, anahtar, tur, ham):
        g = calis(h)[2]
        yeni = anahtar_degistir(ham, anahtar)
        for i, (t, k, eski) in enumerate(g):
            if k == anahtar:
                if eski == yeni and t == tur: return False
                g[i] = (tur, anahtar, yeni); degisen[h] = degisen.get(h, 0) + 1; return True
        g.append((tur, anahtar, yeni)); degisen[h] = degisen.get(h, 0) + 1
        return True

    skinler = skinler_bul(ad, mod)
    if not skinler: return {}, {'skinler': [], 'degisen': []}
    islenen = []
    for n in skinler:
        yol = 'data/characters/%s/skins/skin%d.bin' % (ad, n)
        sh = yol_hash(yol); dosya_adi[sh] = yol
        if sh not in mod_bin: continue
        ob = oyun_bin(sh)
        if ob is None: continue                      # oyunda böyle bir skin yok
        islenen.append(n)
        # Oyunun bu skin için okuduğu dosyalar ve hangi anahtarın nerede durduğu (skin dosyası önce)
        nerede = {}
        for h, b in [(sh, ob)] + [(yol_hash(p), None) for p in ob[1]]:
            if b is None: b = oyun_bin(h)
            if b is None: continue
            for tur, k, _ in b[2]: nerede.setdefault(k, h)
        for p in ob[1]: dosya_adi[yol_hash(p)] = p
        # 1) Tablo: mod bir adı başka bir girdiye bağlıyorsa o girdi özgün anahtarın yerine konur
        mt = {}; ot = {}
        for tur, k, ham in mod_bin[sh][2]:
            if tur == T_COZUCU: mt.update(tablo_oku(ham))
        for tur, k, ham in ob[2]:
            if tur == T_COZUCU: ot.update(tablo_oku(ham))
        yerlesen = set()
        for isim, mk in mt.items():
            ok = ot.get(isim)
            if ok is None or mk == ok: continue
            if mk in havuz: tur, ham = havuz[mk]
            else:
                # Oyundaki başka bir efekte bağlanmış (ödünç): gövdesi oyundan alınır
                kh = nerede.get(mk)
                if kh is None: bulunamayan += 1; continue
                tur, ham = next((t, r) for t, k, r in oyun_bin(kh)[2] if k == mk)
            hedef = nerede.get(ok, sh)
            yerine_koy(hedef, ok, tur, ham); yerlesen.add(ok)
        # 2) Yalnız modda olan dosyaların girdileri: anahtarı oyunda varsa yerine, yoksa modun skin dosyasına
        for h in yalniz_mod:
            for tur, k, ham in mod_bin[h][2]:
                if tur in (T_SKIN, T_COZUCU) or k in yerlesen: continue
                if k in nerede: yerine_koy(nerede[k], k, tur, ham)
                else:
                    if yerine_koy(sh, k, tur, ham): eklenen += 1

    if not degisen:
        return {}, {'skinler': islenen, 'degisen': []}
    yeni = {h: bin_yaz(*cikti[h]) for h in degisen}
    ozet = []
    for h, adet in sorted(degisen.items(), key=lambda x: -x[1]):
        yol = dosya_adi.get(h, '%016x' % h)
        ozet.append({'dosya': os.path.basename(yol.replace('\\', '/')), 'girdi': adet,
                     'kostumler': sorted({int(x) for x in re.findall(r'skin(\d+)', yol.lower())})})
    return yeni, {'skinler': islenen, 'degisen': ozet, 'eklenen': eklenen, 'bulunamayan': bulunamayan}


def oyun_wad_bul(klasor, sampiyon):
    for ad in os.listdir(klasor):
        if ad.lower() == sampiyon.lower() + '.wad.client': return os.path.join(klasor, ad)
    return None


def donustur(giris, oyun_klasoru, cikis):
    with zipfile.ZipFile(giris) as z:
        adlar = z.namelist()
        wadlar = [a for a in adlar if re.match(r'(?i)^WAD/[^/.]+\.wad\.client$', a.replace('\\', '/').lstrip('/'))]
        if not wadlar: raise Olmaz('modda sampiyon WAD dosyasi yok')
        yeni_wad = {}; ozetler = {}; bulunan = 0
        for a in wadlar:
            sampiyon = a.replace('\\', '/').split('/')[-1].split('.')[0]
            oy = oyun_wad_bul(oyun_klasoru, sampiyon)
            if not oy: continue
            bulunan += 1
            mod = Wad(io.BytesIO(z.read(a)))
            with open(oy, 'rb') as d:
                try: yeni, ozet = wad_cevir(sampiyon, mod, Wad(d))
                except Olmaz as e:
                    if len(wadlar) == 1: raise
                    continue
            ozetler[sampiyon] = ozet
            if yeni: yeni_wad[a] = wad_yaz(mod, yeni)
        if not bulunan: raise Olmaz('oyunda bu modun sampiyon dosyasi bulunamadi')
        if not yeni_wad: return None
        with zipfile.ZipFile(cikis, 'w', zipfile.ZIP_STORED) as c:
            for a in adlar:
                if a.endswith('/'): continue
                bilgi = z.getinfo(a)
                c.writestr(bilgi, yeni_wad.get(a) or z.read(a), zipfile.ZIP_STORED if a in yeni_wad else zipfile.ZIP_DEFLATED)
    return ozetler


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.stderr.write('kullanim: python rose_yerinde.py giris.fantome <Champions klasoru> cikis.fantome\n'); sys.exit(2)
    try:
        sonuc = donustur(sys.argv[1], sys.argv[2], sys.argv[3])
    except (Olmaz, OSError, zipfile.BadZipFile, struct.error) as e:
        sys.stderr.write('donusturulemedi: %s\n' % e); sys.exit(2)
    if sonuc is None:
        print('{}'); sys.exit(3)
    print(json.dumps(sonuc, ensure_ascii=True)); sys.exit(0)
