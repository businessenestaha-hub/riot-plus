# Bir custom skin modunun "Rose sürümü"nü üretir.
#
# Sorun (11 Kas 2026, Kayn / Twitch modlarında görüldü): modlarımız belirli bir skinin veri dosyasına yazar
# (data/characters/<şampiyon>/skins/skin<N>.bin). Rose, sende olmayan bir skini oyuna klasik skin (skin0) olarak
# yükler: kendi skin0.bin'inde yalnız iki girdi vardır (SkinCharacterDataProperties + ResourceResolver) ve asıl
# skin<N>.bin'i "bağlı dosya" olarak çağırır. Yani modun skin<N>.bin'i yüklenir, ama kaynak adı -> efekt tablosu
# (ResourceResolver) Rose'un kopyasından, yani özgün skinden gelir; modun eklediği / yeniden adlandırdığı efektler
# (karanlık VFX, ulti değişimi, recall imzası) bulunamaz. Dokular aynı yollarda durduğu için yalnız onlar görünür.
#
# Çözüm: moda, Rose'unkiyle aynı biçimde bir skin0.bin eklenir; içindeki iki girdi MODUN skin<N>.bin'inden alınır
# (anahtarları Skin0 / Skin0/Resources yapılır) ve skin<N>.bin bağlı dosya olarak çağrılır. Modun başka hiçbir
# dosyasına dokunulmaz. Rose'da klasik skinin üstünde seçilir; Rose klasik skine yazan modları kendi
# "base skin" düzeltmesinden (ses, mesh, ad) geçirip yükler.
#
# Kullanım:  python rose_surumu.py giris.fantome cikis.fantome
# Çıkış kodu: 0 = üretildi, 3 = gerek yok (mod zaten klasik skine yazıyor), 2 = dönüştürülemedi (sebep stderr'de)
# Gerekenler: zstandard ve xxhash  (pip install zstandard xxhash); Python 3.14+ ise zstandard yerine yerleşik olan kullanılır.
import io, json, struct, sys, zipfile

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


def bin_oku(b):
    """PROP sürüm 3: bağlı dosyalar + girdiler [(tür, anahtar, ham baytlar)]"""
    if b[:4] != b'PROP': raise Olmaz('skin dosyasi PROP degil')
    surum = struct.unpack_from('<I', b, 4)[0]
    if surum < 2: raise Olmaz('eski bin surumu: %d' % surum)
    o = 8
    n = struct.unpack_from('<I', b, o)[0]; o += 4
    bagli = []
    for _ in range(n):
        uz = struct.unpack_from('<H', b, o)[0]; o += 2
        bagli.append(b[o:o + uz].decode('utf-8', 'replace')); o += uz
    adet = struct.unpack_from('<I', b, o)[0]; o += 4
    turler = struct.unpack_from('<%dI' % adet, b, o); o += 4 * adet
    girdiler = []
    for i in range(adet):
        uz = struct.unpack_from('<I', b, o)[0]
        girdiler.append((turler[i], struct.unpack_from('<I', b, o + 4)[0], b[o:o + 4 + uz])); o += 4 + uz
    if o != len(b): raise Olmaz('skin dosyasi beklenen yerde bitmiyor')
    return surum, bagli, girdiler


def bin_yaz(surum, bagli, girdiler):
    c = io.BytesIO()
    c.write(b'PROP' + struct.pack('<II', surum, len(bagli)))
    for ad in bagli:
        a = ad.encode('utf-8'); c.write(struct.pack('<H', len(a)) + a)
    c.write(struct.pack('<I', len(girdiler)))
    for tur, _, _ in girdiler: c.write(struct.pack('<I', tur))
    for _, _, ham in girdiler: c.write(ham)
    return c.getvalue()


def anahtar_degistir(ham, yeni): return ham[:4] + struct.pack('<I', yeni) + ham[8:]


def wad_tablo(wad):
    if wad[:2] != b'RW' or wad[2] != 3: raise Olmaz('WAD surumu desteklenmiyor')
    adet = struct.unpack_from('<I', wad, 268)[0]
    return [wad[BASLIK + i * GIRDI: BASLIK + (i + 1) * GIRDI] for i in range(adet)]


def wad_dosya(wad, satir):
    h, konum, sikisik, acik = struct.unpack_from('<QIII', satir, 0)
    tur = satir[20] & 0x0F
    veri = wad[konum:konum + sikisik]
    if tur == HAM: return veri
    if tur == ZSTD: return zstd_ac(veri, acik)
    raise Olmaz('desteklenmeyen sikistirma turu: %d' % tur)


def wad_ekle(wad, yeni_hash, yeni_veri):
    """WAD'a ham (sıkıştırılmamış) bir dosya ekler; öteki dosyaların baytlarına dokunmaz. Tablo hash sırasında kalır."""
    satirlar = wad_tablo(wad)
    if any(struct.unpack_from('<Q', s, 0)[0] == yeni_hash for s in satirlar): raise Olmaz('dosya zaten var')
    yeni = struct.pack('<QIII', yeni_hash, 0, len(yeni_veri), len(yeni_veri)) + bytes([HAM, 0, 0, 0]) + struct.pack('<Q', xxhash.xxh3_64_intdigest(yeni_veri))
    hepsi = sorted([(struct.unpack_from('<Q', s, 0)[0], s, None) for s in satirlar] + [(yeni_hash, yeni, yeni_veri)], key=lambda x: x[0])
    govde = io.BytesIO(); tablo = io.BytesIO()
    konum = BASLIK + GIRDI * len(hepsi)
    tasinan = {}                      # eski konum -> yeni konum (aynı baytı paylaşan girdiler paylaşmaya devam eder)
    for h, satir, veri in hepsi:
        if veri is None:
            eski, sikisik = struct.unpack_from('<II', satir, 8)
            if (eski, sikisik) not in tasinan:
                tasinan[(eski, sikisik)] = konum
                govde.write(wad[eski:eski + sikisik]); konum += sikisik
            tablo.write(satir[:8] + struct.pack('<I', tasinan[(eski, sikisik)]) + satir[12:])
        else:
            tablo.write(satir[:8] + struct.pack('<I', konum) + satir[12:])
            govde.write(veri); konum += len(veri)
    return wad[:268] + struct.pack('<I', len(hepsi)) + tablo.getvalue() + govde.getvalue()


def donustur(giris, cikis):
    z = zipfile.ZipFile(giris)
    wadlar = [i for i in z.infolist() if i.filename.replace('\\', '/').lower().startswith('wad/') and i.filename.lower().endswith('.wad.client')]
    if len(wadlar) != 1: raise Olmaz('tek bir paketli WAD bekleniyordu, bulunan: %d' % len(wadlar))
    wad_bilgi = wadlar[0]
    govde_ad = wad_bilgi.filename.replace('\\', '/').split('/')[-1][:-len('.wad.client')]
    if '.' in govde_ad: raise Olmaz('dil WAD\'i: ' + govde_ad)
    karakter = ''.join(ch for ch in govde_ad if ch not in "' .").lower()
    wad = z.read(wad_bilgi.filename)
    satirlar = {struct.unpack_from('<Q', s, 0)[0]: s for s in wad_tablo(wad)}
    skin0 = 'data/characters/%s/skins/skin0.bin' % karakter
    if yol_hash(skin0) in satirlar: return None        # zaten klasik skine yazıyor
    numaralar = [n for n in range(1, 200) if yol_hash('data/characters/%s/skins/skin%d.bin' % (karakter, n)) in satirlar]
    if not numaralar: raise Olmaz('modda %s icin skin veri dosyasi yok' % karakter)
    n = numaralar[0]
    surum, bagli, girdiler = bin_oku(wad_dosya(wad, satirlar[yol_hash('data/characters/%s/skins/skin%d.bin' % (karakter, n))]))
    skinler = [g for g in girdiler if g[0] == T_SKIN]; cozuculer = [g for g in girdiler if g[0] == T_COZUCU]
    if len(skinler) != 1: raise Olmaz('skin girdisi sayisi: %d' % len(skinler))
    # Oyundaki yazım (Kayn, MonkeyKing...): modun kendi bağlı dosyalarından alınır
    yazim = govde_ad
    for ad in bagli:
        p = ad.replace('\\', '/').split('/')
        if len(p) >= 3 and p[0].upper() == 'DATA' and p[1].lower() == 'characters' and p[2].lower() == karakter: yazim = p[2]; break
    skin_ham = anahtar_degistir(skinler[0][2], fnv('Characters/%s/Skins/Skin0' % yazim))
    yeni_girdiler = [(T_SKIN, 0, skin_ham)]
    if len(cozuculer) == 1:
        eski = struct.pack('<I', cozuculer[0][1]); yeni_anahtar = fnv('Characters/%s/Skins/Skin0/Resources' % yazim)
        # Skin girdisi çözücüsüne anahtarıyla bağlanır; tam bir kez geçiyorsa ikisi birlikte yeniden adlandırılır.
        # Geçmiyorsa çözücü eski anahtarıyla kalır (bağ bozulmaz).
        if skin_ham.count(eski, 8) == 1:
            i = skin_ham.index(eski, 8)
            skin_ham = skin_ham[:i] + struct.pack('<I', yeni_anahtar) + skin_ham[i + 4:]
            yeni_girdiler = [(T_SKIN, 0, skin_ham), (T_COZUCU, 0, anahtar_degistir(cozuculer[0][2], yeni_anahtar))]
        else:
            yeni_girdiler.append((T_COZUCU, 0, cozuculer[0][2]))
    elif len(cozuculer) > 1: raise Olmaz('birden cok cozucu girdisi')
    yeni_bin = bin_yaz(surum, ['DATA/Characters/%s/Skins/Skin%d.bin' % (yazim, n)], yeni_girdiler)
    bin_oku(yeni_bin)                                   # yazdığımız okunabiliyor mu
    yeni_wad = wad_ekle(wad, yol_hash(skin0), yeni_bin)
    with zipfile.ZipFile(cikis, 'w') as c:
        for i in z.infolist():
            if i.is_dir(): continue
            veri = z.read(i.filename)
            ad = i.filename.replace('\\', '/')
            if i.filename == wad_bilgi.filename: veri = yeni_wad
            elif ad.lower() == 'meta/hashes/game.hashes.txt':
                veri = veri.rstrip(b'\r\n') + b'\n' + ('DATA/Characters/%s/Skins/Skin0.bin' % yazim).encode() + b'\n'
            elif ad.lower() == 'meta/info.json':
                try:
                    b = json.loads(veri.decode('utf-8-sig'))
                    b['Description'] = ((b.get('Description') or '') + ' [Rose surumu: klasik skinin ustunde secilir]').strip()
                    veri = json.dumps(b, ensure_ascii=False, indent=2).encode('utf-8')
                except ValueError: pass
            c.writestr(zipfile.ZipInfo(ad, date_time=i.date_time), veri,
                       compress_type=zipfile.ZIP_STORED if veri is yeni_wad else zipfile.ZIP_DEFLATED)
    return karakter, n


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.stderr.write('kullanim: python rose_surumu.py giris.fantome cikis.fantome\n'); sys.exit(2)
    try:
        sonuc = donustur(sys.argv[1], sys.argv[2])
    except (Olmaz, OSError, zipfile.BadZipFile, struct.error, KeyError) as e:
        sys.stderr.write('donusturulemedi: %s\n' % e); sys.exit(2)
    if sonuc is None:
        print('gerek yok: mod zaten klasik skine yaziyor'); sys.exit(3)
    print('tamam: %s skin%d -> klasik skin' % sonuc)
