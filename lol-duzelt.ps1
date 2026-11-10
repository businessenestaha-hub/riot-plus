# Riot Plus (eski adı LoL Düzelt) v6. Kısayol (Ctrl+Alt+L) bu pencereyi açar.
# v6: Custom skinler. Modları oyuna LTK Manager (League Toolkit) yükler; Riot Plus hangi şampiyonda hangi modun
#     açık olacağını seçer, LTK'yı tepside motor olarak çalıştırır, LTK'nın yeni sürümünü açılışta ve açık kaldıkça
#     3 saatte bir sorar; yeni sürüm varsa kahraman görselinin üstünde yeşil "Güncelle" şeridi kalır (5 Kas).
#     LTK'nın skinhack kontrolüne takılan modlar listelenmez (sahip olunmayan ücretli skin içeriği).
# Tasarım: üstte şampiyonunun gerçek görseli (lobide rolündeki ilk tercihin, seçimde kilitlediğin, sırada süre sayacı),
# tek ana düğme (Sıraya gir / Sıradan çık / LoL'e geç), tek cümlelik durum, portreli şampiyon seçimi, sade "Sorun mu var?" listesi.
# Görseller Riot'un herkese açık Data Dragon'ından bir kez iner, gorsel\ klasöründe saklanır.
# v6.4 (7 Kas 2026) Apple HIG uyarlaması: cam başlık kapsülü, bölümlü sekme kontrolü, gruplu bölüm kartları,
#   kapsül düğmeler + basma durumu, kayan anahtar. Önceki görünüm: yedek\lol-duzelt-v6.3-apple-oncesi-2026-11-07.ps1
# v6.6 (10 Kas 2026) Custom'ın iki kaynağı: Custom skinler sayfasının üstündeki seçici (ayarlar.json "customKaynak").
#   LTK Manager: eskisi gibi; kendi eklediğin modlar, seçimi Riot Plus LTK'ya yazar.
#   Rose: Rose'u Riot Plus başlatır / durdurur; Rose LTK'yı kendisi sürdüğü için bu kipte Riot Plus LTK'ya dokunmaz.
#   İkisi aynı anda çalışmaz: Rose yalnız kendi açtığı LTK'yı kullanabilir ve her maçta LTK'daki açık modları kapatır.
#   "LoL'ü aç" (LoL kapalıyken) sorar: LTK Manager ile / Rose ile / düz. Düz ve LTK açılışında Rose kapatılır, client'taki
#   eklenti kancası kaldırılır; kalkmazsa LoL açılmaz. Riot Plus açılırken Rose kendiliğinden başlatılmaz.
#   Custom skinler > "Rose'a aktar": LTK'daki .fantome modları Rose'un custom skin klasörüne kopyalar.
# Arayüz Türkçe / İngilizce: başlıktaki TR / EN (ayarlar.json "dil").
#  Sorun mu var?  1 Ekrana gelmiyor   : yalnız client arayüzünü yeniden başlatır (giriş ve parti korunur)
#                 2 Yüklemede kaldı   : maç başladı mı bakar; oyun penceresini tazeler ya da yeniden bağlar
#                 3 LoL'ü aç          : açıksa öne getirir; kapalıysa Riot Client'ta Oyna'ya basar
#                 4 Hepsini kapat     : ilk basışta kırmızı onay; 4 sn içinde ikinci basış LoL + Riot Client'ı kapatır (Vanguard'a dokunmaz)
#  5 / ana düğme: Sıraya gir (lobi + roller + sıra), sıradayken Sıradan çık, seçimde/maçta LoL'e geç
#  Şampiyon seçimi: maçı kabul et, ban at, rolüne göre pick at (rol listeleri "düzenle" görünümünde)
#  Maç açıkken 1-5 ve Esc kısayolları kapalı. Esc pencereyi küçültür. Son mesajlar altta; ayrıntı gunluk.txt'de.
# Parametreler: -Islem sira  açılınca ana düğmeye basar (araç zaten açıksa açık olana söyler)
#               -Sessiz      yalnız deneme: pencere gösterilmez, odak çalınmaz, mesajlar konsola da yazılır
#               -Kare x.png  -Sessiz ile: pencereyi göstermeden durumların resmini kaydeder
# Önceki sürümler: yedek\
param(
    [string]$DenemeKlasoru,        # yalnız deneme için: sahte client klasörü (lockfile + ayarlar.json orada)
    [string]$Islem,                # 'sira': açılınca ana düğmeye bas
    [switch]$Sessiz,               # yalnız deneme: pencere yok
    [string]$Kare,                 # yalnız -Sessiz ile: ekran resimlerini <ad>-*.png olarak kaydedip çıkar
    [string]$Sekme                 # eski kısayollarla uyum için; kullanılmıyor
)

# ---- Ayarlar ----
$LolKlasoru      = 'D:\Riot Games\League of Legends'
$RiotClient      = 'D:\Riot Games\Riot Client\RiotClientServices.exe'
$BeklemeSn       = 30    # arayüz yeniden başlatıldıktan sonra pencere için en fazla bekleme
$AcilisSn        = 90    # "LoL'ü aç" sonrası client penceresi için en fazla bekleme
$YenidenBaglanSn = 45    # oyun kapatıldıktan sonra client'ın "yeniden bağlan" durumuna geçmesi için bekleme
$HazirlikSn      = 60    # "Sıraya gir": LoL açıldıktan sonra client'ın yerel API'si için en fazla bekleme
$KapatOnaySn     = 4     # "Hepsini kapat" onayının açık kaldığı süre
$OyunApiPort     = 2999  # oyunun kendi yerel API'si (Live Client Data)
$InternetHedef   = '1.1.1.1'  # maç dışında ölçülen internet pingi (LoL TR sunucusu ping'e cevap vermiyor)
$PingUyari       = 60    # bu ms ve üstü turuncu
$PingKotu        = 120   # bu ms ve üstü kırmızı
$KapatSurecleri  = @(    # "hepsini kapat" listesi; Vanguard (vgc, vgtray) bilerek yok
    'League of Legends', 'LeagueClient', 'LeagueClientUx', 'LeagueClientUxRender', 'LeagueCrashHandler64',
    'RiotClientServices', 'Riot Client', 'RiotClientUx', 'RiotClientUxRender', 'RiotClientCrashHandler')
# "Sıraya gir" listesi (LCU queueId); 3 Kas 2026'da client'ın sıra listesinden doğrulandı
$SiraListesi = @(
    @{ Id = 420; Tr = 'Dereceli tek/çift';     En = 'Ranked solo/duo' }
    @{ Id = 440; Tr = 'Dereceli esnek';        En = 'Ranked flex' }
    @{ Id = 400; Tr = 'Normal (sıralı seçim)'; En = 'Normal draft' }
    @{ Id = 480; Tr = 'Tam Gaz';               En = 'Swiftplay' }
    @{ Id = 450; Tr = 'ARAM';                  En = 'ARAM' }
)
# Custom skinler: LTK Manager arka planda (tepside) çalışır, Riot Plus yalnız seçimi yazar
$LtkExe         = 'C:\Program Files\LTK Manager\ltk-manager.exe'
$LtkVeri        = Join-Path $env:APPDATA 'dev.leaguetoolkit.manager'
$LtkSurumUrl    = 'https://api.github.com/repos/LeagueToolkit/ltk-manager/releases/latest'
$LtkImzaci      = 'CN=Natoken LLC'   # LTK kurulum dosyasının imzacısı (4 Kas 2026'da doğrulandı)
$PatcherBekleSn = 150                # LTK açıldıktan sonra patcher için en fazla bekleme (ilk derleme ~70 sn sürdü)
# Custom'ın ikinci kaynağı: Rose (github.com/Alban1911/Rose). Rose LTK Manager'ı kendisi açıp kapatır ve yalnız kendi
# başlattığı LTK'ya köprü yükleyebilir; bu yüzden Rose kipinde Riot Plus LTK'yı ne açar ne kapatır ne de kütüphanesine yazar.
$RoseExe        = 'C:\Program Files\Rose\Rose.exe'
$RoseVeri       = Join-Path $env:LOCALAPPDATA 'Rose'
$RoseIndirUrl   = 'https://github.com/Alban1911/Rose/releases/latest'
$RoseAcilisSn   = 25                 # Rose başlatıldıktan sonra sürecinin görünmesi için en fazla bekleme
# -----------------

$GameLogs = Join-Path $LolKlasoru 'Logs\GameLogs'
$Deneme = [bool]$DenemeKlasoru
if ($Deneme) { $LolKlasoru = $DenemeKlasoru }
$VeriKlasoru     = if ($Deneme) { $DenemeKlasoru } else { $PSScriptRoot }
$AyarDosyasi     = Join-Path $VeriKlasoru 'ayarlar.json'
$GunlukDosyasi   = Join-Path $VeriKlasoru 'gunluk.txt'
$SampiyonDosyasi = Join-Path $PSScriptRoot 'sampiyonlar.json'
$GorselKlasoru   = Join-Path $PSScriptRoot 'gorsel'
$CustomGorselKlasoru = Join-Path $GorselKlasoru 'custom'                 # modların görselleri + elle seçilenler
$SkinAdDosyasi   = Join-Path $PSScriptRoot 'sampiyon-skinleri.json'      # Data Dragon skin adları (num -> ad)
$ModSkinDosyasi  = Join-Path $CustomGorselKlasoru 'mod-skinleri.json'    # mod sha|şampiyon -> yazdığı skin numaraları
$IkonYolu        = Join-Path $PSScriptRoot 'riot-plus.ico'   # Riot logosunun yeşil hali
$LogoYolu        = Join-Path $PSScriptRoot 'riot-plus.png'
$RcLockfile      = Join-Path $env:LOCALAPPDATA 'Riot Games\Riot Client\Config\lockfile'
$Roller   = [ordered]@{ top = 'Üst'; jungle = 'Orman'; middle = 'Orta'; bottom = 'Alt'; utility = 'Destek'; genel = 'Rolsüz' }
$RollerEn = @{ top = 'Top'; jungle = 'Jungle'; middle = 'Mid'; bottom = 'Bot'; utility = 'Support'; genel = 'Any role' }
$SiraIdleri = @($SiraListesi | ForEach-Object { $_.Id })
# Sıra lobisindeki rol tercihleri (LCU kodları)
$RolKodlari = [ordered]@{ TOP = @('Üst', 'Top'); JUNGLE = @('Orman', 'Jungle'); MIDDLE = @('Orta', 'Mid'); BOTTOM = @('Alt', 'Bot'); UTILITY = @('Destek', 'Support'); FILL = @('Fark etmez', 'Fill') }
$Rol1Kodlar = @('') + @($RolKodlari.Keys)   # '' = client'taki tercihe dokunma
$Rol2Kodlar = @($RolKodlari.Keys)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing, System.Web.Extensions, System.IO.Compression, System.IO.Compression.FileSystem
Add-Type @'
using System; using System.IO; using System.Net; using System.Net.Security; using System.Text;
using System.Runtime.InteropServices; using System.Security.Cryptography.X509Certificates;
public static class LolPencere {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int pid);
}
public static class LcuHttp {
  static LcuHttp() {
    ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
    ServicePointManager.ServerCertificateValidationCallback = Dogrula;
  }
  // Client'ın yerel sertifikası Riot'un kendi kökünden; doğrulama yalnız 127.0.0.1 için atlanır
  static bool Dogrula(object s, X509Certificate c, X509Chain ch, SslPolicyErrors e) {
    if (e == SslPolicyErrors.None) return true;
    HttpWebRequest r = s as HttpWebRequest;
    return r != null && r.RequestUri.IsLoopback;
  }
  // { HTTP kodu, gövde }; bağlanamazsa kod "000"
  public static string[] Istek(string yontem, string url, string sifre, string govde, int sureMs) {
    try {
      HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
      r.Method = yontem; r.Timeout = sureMs; r.ReadWriteTimeout = sureMs;
      r.Accept = "application/json";
      r.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
      if (r.RequestUri.IsLoopback) r.Proxy = null;
      if (!string.IsNullOrEmpty(sifre))
        r.Headers[HttpRequestHeader.Authorization] = "Basic " + Convert.ToBase64String(Encoding.ASCII.GetBytes("riot:" + sifre));
      if (!string.IsNullOrEmpty(govde)) {
        byte[] b = Encoding.UTF8.GetBytes(govde);
        r.ContentType = "application/json"; r.ContentLength = b.Length;
        using (Stream st = r.GetRequestStream()) st.Write(b, 0, b.Length);
      } else if (yontem != "GET") r.ContentLength = 0;
      HttpWebResponse y;
      try { y = (HttpWebResponse)r.GetResponse(); }
      catch (WebException ex) { y = ex.Response as HttpWebResponse; if (y == null) return new string[] { "000", "" }; }
      using (y) using (StreamReader sr = new StreamReader(y.GetResponseStream(), Encoding.UTF8))
        return new string[] { ((int)y.StatusCode).ToString(), sr.ReadToEnd() };
    } catch { return new string[] { "000", "" }; }
  }
}
'@
# Custom modların hangi skine yazdığı (WAD içindekiler tablosu, xxh64 yol hash'i) ve modun kendi görseli
Add-Type -ReferencedAssemblies ([IO.Compression.ZipArchive].Assembly.Location), ([IO.Compression.ZipFile].Assembly.Location) -TypeDefinition @'
using System; using System.Collections.Generic; using System.IO; using System.IO.Compression; using System.Text;
public static class ModWad {
  const ulong P1 = 11400714785074694791UL, P2 = 14029467366897019727UL, P3 = 1609587929392839161UL, P4 = 9650029242287828579UL, P5 = 2870177450012600261UL;
  static ulong Rotl(ulong x, int r) { return (x << r) | (x >> (64 - r)); }
  static ulong Tur(ulong acc, ulong v) { unchecked { acc += v * P2; acc = Rotl(acc, 31); return acc * P1; } }
  static ulong Birlestir(ulong acc, ulong v) { unchecked { acc ^= Tur(0, v); return acc * P1 + P4; } }
  public static ulong Xxh64(byte[] b) {
    unchecked {
      int i = 0, n = b.Length; ulong h;
      if (n >= 32) {
        ulong v1 = P1 + P2, v2 = P2, v3 = 0, v4 = 0 - P1;
        while (i <= n - 32) { v1 = Tur(v1, BitConverter.ToUInt64(b, i)); v2 = Tur(v2, BitConverter.ToUInt64(b, i + 8)); v3 = Tur(v3, BitConverter.ToUInt64(b, i + 16)); v4 = Tur(v4, BitConverter.ToUInt64(b, i + 24)); i += 32; }
        h = Rotl(v1, 1) + Rotl(v2, 7) + Rotl(v3, 12) + Rotl(v4, 18);
        h = Birlestir(h, v1); h = Birlestir(h, v2); h = Birlestir(h, v3); h = Birlestir(h, v4);
      } else h = P5;
      h += (ulong)n;
      while (i + 8 <= n) { h ^= Tur(0, BitConverter.ToUInt64(b, i)); h = Rotl(h, 27) * P1 + P4; i += 8; }
      if (i + 4 <= n) { h ^= (ulong)BitConverter.ToUInt32(b, i) * P1; h = Rotl(h, 23) * P2 + P3; i += 4; }
      while (i < n) { h ^= b[i] * P5; h = Rotl(h, 11) * P1; i++; }
      h ^= h >> 33; h *= P2; h ^= h >> 29; h *= P3; h ^= h >> 32;
      return h;
    }
  }
  static byte[] Oku(Stream s, int n) { var b = new byte[n]; int t = 0; while (t < n) { int r = s.Read(b, t, n - t); if (r <= 0) return null; t += r; } return b; }
  // WAD v3: 4 bayt başlık + 256 imza + 8 sağlama + 4 sayı, sonra 32 baytlık girdiler (ilk 8 bayt yol hash'i)
  static List<ulong> Toc(Stream s) {
    var l = new List<ulong>();
    byte[] bas = Oku(s, 4); if (bas == null || bas[0] != (byte)'R' || bas[1] != (byte)'W' || bas[2] < 3) return l;
    if (Oku(s, 264) == null) return l;
    byte[] sayi = Oku(s, 4); if (sayi == null) return l;
    int say = BitConverter.ToInt32(sayi, 0); if (say < 0 || say > 2000000) return l;
    for (int i = 0; i < say; i++) { byte[] g = Oku(s, 32); if (g == null) break; l.Add(BitConverter.ToUInt64(g, 0)); }
    return l;
  }
  static Dictionary<ulong, int> SkinHashleri(string kod) {
    var hedef = new Dictionary<ulong, int>();
    string k = kod.ToLowerInvariant();
    for (int n = 0; n < 100; n++) hedef[Xxh64(Encoding.ASCII.GetBytes("data/characters/" + k + "/skins/skin" + n + ".bin"))] = n;
    return hedef;
  }
  // .modpkg (LTK'nın kendi biçimi): dosyada skin yollarının 8 baytlık hash'leri aranır (içindekiler tablosu sıkıştırılmamış)
  public static int[] SkinNumaralariHam(string yol, string kod) {
    var hedef = SkinHashleri(kod);
    var bulunan = new SortedSet<int>();
    byte[] b = File.ReadAllBytes(yol); int num;
    for (int i = 0; i + 8 <= b.Length; i++) if (hedef.TryGetValue(BitConverter.ToUInt64(b, i), out num)) bulunan.Add(num);
    var r = new int[bulunan.Count]; bulunan.CopyTo(r); return r;
  }
  // Fantome arşivinde şampiyonun hangi skin bin'lerine (skin0 = klasik) yazıldığı
  public static int[] SkinNumaralari(string arsiv, string kod) {
    var hedef = SkinHashleri(kod);
    var bulunan = new SortedSet<int>();
    using (var z = ZipFile.OpenRead(arsiv)) {
      foreach (var e in z.Entries) {
        string ad = e.FullName.Replace('\\', '/');
        if (!ad.StartsWith("WAD/", StringComparison.OrdinalIgnoreCase)) continue;
        int i = ad.IndexOf(".wad.client", StringComparison.OrdinalIgnoreCase); if (i < 0) continue;
        string kalan = ad.Substring(i + 11); int num;
        if (kalan.Length == 0) { using (var s = e.Open()) foreach (ulong h in Toc(s)) if (hedef.TryGetValue(h, out num)) bulunan.Add(num); }
        else if (kalan.StartsWith("/")) {
          string yol = kalan.Substring(1).ToLowerInvariant();
          if (hedef.TryGetValue(Xxh64(Encoding.ASCII.GetBytes(yol)), out num)) bulunan.Add(num);
          ulong hh; string dosya = Path.GetFileNameWithoutExtension(yol);
          if (dosya.Length == 16 && ulong.TryParse(dosya, System.Globalization.NumberStyles.HexNumber, null, out hh) && hedef.TryGetValue(hh, out num)) bulunan.Add(num);
        }
      }
    }
    var r = new int[bulunan.Count]; bulunan.CopyTo(r); return r;
  }
  // Fantome'un kendi görseli (META/image.png); yoksa false
  public static bool GorselCikar(string arsiv, string hedef) {
    using (var z = ZipFile.OpenRead(arsiv)) {
      foreach (var e in z.Entries) {
        string ad = e.FullName.Replace('\\', '/');
        if (ad.Equals("META/image.png", StringComparison.OrdinalIgnoreCase) || ad.Equals("META/image.jpg", StringComparison.OrdinalIgnoreCase)) {
          Directory.CreateDirectory(Path.GetDirectoryName(hedef)); e.ExtractToFile(hedef, true); return true;
        }
      }
    }
    return false;
  }
}
'@

# ---- Dil ----
$script:Dil = 'tr'
function T([string]$tr, [string]$en) { if ($script:Dil -eq 'en') { return $en }; return $tr }
function Baslik-Metni { if ($Deneme) { T 'Riot Plus (deneme)' 'Riot Plus (test)' } else { 'Riot Plus' } }
function Rol-Adi($r) { if ($script:Dil -eq 'en') { $RollerEn[$r] } else { $Roller[$r] } }
function Rol-Kod-Adi($kod) {
    if (-not $kod) { return (T "Client'taki roller" "Client's roles") }
    $r = $RolKodlari[$kod]
    if ($r) { T $r[0] $r[1] } else { "$kod" }
}
function Sira-Adi($id) {
    $s = $SiraListesi | Where-Object { $_.Id -eq [int]$id } | Select-Object -First 1
    if ($s) { T $s.Tr $s.En } else { "#$id" }
}
$Baslik = 'Riot Plus'

function One-Getir($h) {
    if (-not $h -or $h -eq [IntPtr]::Zero) { return }
    # Alt'a basıp bırakmak, Windows'un başka pencereyi öne almasına izin vermesini sağlar
    [LolPencere]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [LolPencere]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void][LolPencere]::ShowWindow($h, 9)   # SW_RESTORE
    [void][LolPencere]::SetForegroundWindow($h)
}

# Tek pencere: kısayola ikinci kez basılırsa açık olana (küçültülmüş olsa da) "görün" ya da "sıraya gir" sinyali gider
$Ek = if ($Deneme) { 'Deneme' } else { '' }
$Kilit = New-Object Threading.Mutex($false, "Local\LolDuzeltArayuz$Ek")
$GosterSinyali = New-Object Threading.EventWaitHandle($false, 'AutoReset', "Local\LolDuzeltGoster$Ek")
$SiraSinyali   = New-Object Threading.EventWaitHandle($false, 'AutoReset', "Local\LolDuzeltSira$Ek")
try { $sahip = $Kilit.WaitOne(0) } catch [Threading.AbandonedMutexException] { $sahip = $true }
if (-not $sahip) {
    if ($Islem -eq 'sira') { [void]$SiraSinyali.Set() }
    else { [void][LolPencere]::AllowSetForegroundWindow(-1); [void]$GosterSinyali.Set() }
    exit
}
if ($Deneme) { try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false) } catch {} }

# Günlük dosyası 1 MB'ı geçince son 3000 satır kalır
try {
    if ((Test-Path $GunlukDosyasi) -and (Get-Item $GunlukDosyasi).Length -gt 1MB) {
        $satirlar = [IO.File]::ReadAllLines($GunlukDosyasi)
        [IO.File]::WriteAllLines($GunlukDosyasi, $satirlar[([Math]::Max(0, $satirlar.Count - 3000))..($satirlar.Count - 1)], (New-Object Text.UTF8Encoding($false)))
    }
} catch {}

# ---- Renkler ----
$RenkYesil   = '#1FBF62'   # tek eylem rengi (logo yeşili)
$RenkTuruncu = '#E8A23A'
$RenkKirmizi = '#E5484D'
$RenkSoluk   = '#8C95A1'
$RenkAltin   = '#8C95A1'   # bilgi mesajları sakin kalır
$RenkYazi    = '#ECE5D8'
$FircaCevirici = New-Object Windows.Media.BrushConverter
function Firca([string]$renk) { $FircaCevirici.ConvertFromString($renk) }

# ---- Yardımcılar ----
$script:Mesgul  = $false
$script:Kapandi = $false
$script:Calisan = $null   # şu an çalışan seçenek
$script:Sirada  = $null   # çalışırken seçilen yeni seçenek
$script:BekleyenIslem = $null   # zamanlayıcının ilk fırsatta çalıştıracağı seçenek (-Islem ya da sinyal)
$script:MesajGecmis = New-Object 'Collections.Generic.List[string]'

# Alttaki mesaj satırına yazar (üzerine gelince son 10), günlük dosyasına ekler
function Yaz($metin, $renk = $RenkYazi) {
    $simdi = Get-Date
    if ($Deneme) { try { [Console]::Out.WriteLine($metin) } catch {} }
    try { [IO.File]::AppendAllText($GunlukDosyasi, "$($simdi.ToString('yyyy-MM-dd HH:mm:ss'))  $metin`r`n", (New-Object Text.UTF8Encoding($false))) } catch {}
    if ($script:Kapandi -or -not $MesajYazi) { return }
    $script:MesajGecmis.Add("$($simdi.ToString('HH:mm'))  $metin")
    while ($script:MesajGecmis.Count -gt 10) { $script:MesajGecmis.RemoveAt(0) }
    $MesajYazi.Text = $metin
    $MesajYazi.Foreground = Firca $(if ($renk -eq $RenkKirmizi -or $renk -eq $RenkTuruncu) { $renk } else { '#CFC8BC' })
    $MesajSaat.Text = $simdi.ToString('HH:mm')
    $MesajKutu.ToolTip = ($script:MesajGecmis -join "`n")
}

# Pencere küçültülmüşken tepsi ikonundan balon bildirimi
function Bildir($metin) {
    if (-not $Sessiz -and $Pencere.WindowState -eq 'Minimized') { $Tepsi.ShowBalloonTip(4000, $Baslik, $metin, 'Info') }
}

# Arayüzün birikmiş işlerini çalıştırır (WinForms'taki DoEvents karşılığı)
function Olay-Isle {
    $cerceve = New-Object Windows.Threading.DispatcherFrame
    $bitir = [Action]({ $cerceve.Continue = $false }.GetNewClosure())
    [void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, $bitir)
    [Windows.Threading.Dispatcher]::PushFrame($cerceve)
}

# Arayüzü dondurmadan bekler; pencere kapatılırsa ya da başka seçenek seçilirse işlemi keser
function Bekle($sn) {
    $son = [DateTime]::Now.AddSeconds($sn)
    while ([DateTime]::Now -lt $son) {
        Olay-Isle
        if ($script:Kapandi) { throw 'kapandi' }
        if ($script:Sirada) { throw 'iptal' }
        Start-Sleep -Milliseconds 40
    }
}

# Seçenekli soru penceresi; seçilen sırayı döner (kapatılırsa -1)
$SorXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" SizeToContent="Height" Width="440"
        ShowInTaskbar="False" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="#ECE5D8" UseLayoutRounding="True">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#ECE5D8"/><Setter Property="FontSize" Value="13"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="#1C232D"/><Setter Property="BorderBrush" Value="#2A333F"/><Setter Property="Margin" Value="0,0,0,6"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="6" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" Padding="12,9">
          <ContentPresenter HorizontalAlignment="Left"/></Border>
        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="BorderBrush" Value="#8C95A1"/></Trigger></ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="16">
    <Border CornerRadius="10" Background="#141A22" BorderBrush="#2A333F" BorderThickness="1">
      <Border.Effect><DropShadowEffect Color="Black" BlurRadius="24" ShadowDepth="4" Opacity="0.5"/></Border.Effect></Border>
    <StackPanel Margin="18,16,18,12">
      <TextBlock x:Name="SorYazi" TextWrapping="Wrap" FontSize="14" LineHeight="20" Margin="0,0,0,14"/>
      <StackPanel x:Name="SorDugmeler"/>
    </StackPanel>
  </Grid>
</Window>
'@
function Sor($metin, [string[]]$secenekler) {
    $d = [Windows.Markup.XamlReader]::Parse($SorXaml)
    $d.FindName('SorYazi').Text = $metin
    $panel = $d.FindName('SorDugmeler')
    for ($i = 0; $i -lt $secenekler.Count; $i++) {
        $b = New-Object Windows.Controls.Button
        $b.Content = "$($i + 1)   $($secenekler[$i])"
        $b.Tag = $i
        if ($i -eq 0) { $b.BorderBrush = Firca $RenkYesil }
        $b.Add_Click({ $w = [Windows.Window]::GetWindow($this); $w.Tag = $this.Tag; $w.Close() })
        [void]$panel.Children.Add($b)
    }
    $d.Tag = -1
    $d.Add_KeyDown({
        if ($_.Key -eq 'Escape') { $this.Close(); return }
        $n = -1
        $k = [int]$_.Key
        if ($k -ge 35 -and $k -le 43) { $n = $k - 35 }        # D1-D9
        elseif ($k -ge 75 -and $k -le 83) { $n = $k - 75 }    # NumPad1-9
        if ($n -ge 0 -and $n -lt $this.FindName('SorDugmeler').Children.Count) { $this.Tag = $n; $this.Close() }
    })
    $d.Add_MouseLeftButtonDown({ try { $this.DragMove() } catch {} })
    if ($Pencere -and $Pencere.IsVisible -and $Pencere.WindowState -ne 'Minimized') { $d.Owner = $Pencere; $d.WindowStartupLocation = 'CenterOwner' }
    [void]$d.ShowDialog()
    $secim = [int]$d.Tag
    if ($script:Kapandi) { throw 'kapandi' }
    return $secim
}

function Surec($ad) { Get-Process -Name $ad -ErrorAction SilentlyContinue | Select-Object -First 1 }

# Görünen client penceresi; $haric verilirse o süreçlerinkini saymaz (yeniden başlatma sonrası eskisini görmemek için)
function Pencere-Bul($haric = @()) {
    $ux = Get-Process LeagueClientUx -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $haric -notcontains $_.Id } | Select-Object -First 1
    if ($ux) { return $ux.MainWindowHandle }
    return [IntPtr]::Zero
}

function Lol-Baslat {
    Start-Process -FilePath $RiotClient -ArgumentList '--launch-product=league_of_legends', '--launch-patchline=live'
}

# lockfile'dan yerel API bilgisi: ad:pid:port:şifre:protokol
function Kilit-Oku($yol) {
    try {
        $fs = [IO.File]::Open($yol, 'Open', 'Read', 'ReadWrite')
        $parca = (New-Object IO.StreamReader($fs)).ReadToEnd().Trim().Split(':')
        $fs.Close()
        $protokol = if ($parca.Count -gt 4 -and $parca[4]) { $parca[4] } else { 'https' }
        return @{ Port = $parca[2]; Sifre = $parca[3]; Protokol = $protokol }
    } catch { return $null }
}
function Lcu-Bilgi { Kilit-Oku (Join-Path $LolKlasoru 'lockfile') }
function Rc-Bilgi { if ($Deneme) { return $null }; Kilit-Oku $RcLockfile }

# HTTP isteği; @{ Kod; Govde } döner (bağlanamazsa Kod = 000)
function Istek($yontem, $url, $sifre, $govde = $null, $sure = 5000) {
    $r = [LcuHttp]::Istek($yontem, $url, $sifre, $govde, $sure)
    return @{ Kod = $r[0]; Govde = $r[1] }
}

function Lcu($yontem, $yol, $lcu, $govde = $null, $sure = 5000) {
    Istek $yontem "$($lcu.Protokol)://127.0.0.1:$($lcu.Port)$yol" $lcu.Sifre $govde $sure
}

# Client hata cevabının okunur hali: "HTTP 400: mesaj"
function Lcu-Hata($r) {
    $m = ''
    try { $m = "$(($r.Govde | ConvertFrom-Json).message)" } catch {}
    if ($m) { "HTTP $($r.Kod): $m" } else { "HTTP $($r.Kod)" }
}

function Faz-Oku($lcu, $sure = 2000) {
    $f = Lcu 'GET' '/lol-gameflow/v1/gameflow-phase' $lcu $null $sure
    if ($f.Kod -eq '200') { return $f.Govde.Trim().Trim('"') }
    return $null
}

# Riot Client girişli mi; "Oyna" düğmesinin karşılığı. Yeni Riot Client --launch-product ile oyunu kendiliğinden
# başlatmıyor, yalnız LoL sayfasını açıyor (3 Kas 2026 görüldü); bu uç 200 + oturum kimliği döner, ~12 sn'de client gelir
function Rc-Girisli($rc) { $rc -and (Lcu 'GET' '/rso-auth/v1/authorization' $rc $null 2000).Kod -eq '200' }
function Lol-Oyna($rc) {
    $r = Lcu 'POST' '/product-launcher/v1/products/league_of_legends/patchlines/live' $rc $null 5000
    return ($r.Kod -like '2*')
}

# ---- Düzeltmeler ----

# Yalnız client arayüzünü yeniden başlatır; pencere gelirse $true
function Arayuz-Yenile {
    $lcu = Lcu-Bilgi
    if (-not $lcu) { Yaz (T "LoL'ün yerel bağlantısına ulaşamadım; client kapalı olabilir." "Couldn't reach LoL's local connection; the client may be closed.") $RenkKirmizi; return $false }
    $eski = @(Get-Process LeagueClientUx -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    Yaz (T 'Client arayüzünü yeniden başlatıyorum; giriş ve parti yerinde kalıyor.' 'Restarting the client UI; login and party stay put.')
    $r = Lcu 'POST' '/riotclient/kill-and-restart-ux' $lcu
    if ($r.Kod -ne '204') { Yaz (T "Client beklenmedik bir cevap verdi (HTTP $($r.Kod))." "The client answered unexpectedly (HTTP $($r.Kod)).") $RenkTuruncu; return $false }
    for ($i = 1; $i -le $BeklemeSn; $i++) {
        Bekle 1
        $h = Pencere-Bul $eski
        if ($h -ne [IntPtr]::Zero) {
            Bekle 1
            One-Getir $h
            Yaz (T "LoL ekrana geldi, $i saniye sürdü." "LoL is back on screen, took ${i}s.") $RenkYesil
            return $true
        }
    }
    Yaz (T "$BeklemeSn saniye bekledim, pencere gelmedi." "Waited ${BeklemeSn}s, the window didn't show up.") $RenkTuruncu
    return $false
}

function Hepsini-Kapat {
    $p = @(Get-Process -Name $KapatSurecleri -ErrorAction SilentlyContinue)
    if (-not $p.Count) { Yaz (T 'Kapatacak bir şey yok; LoL ve Riot Client zaten kapalı.' 'Nothing to close; LoL and Riot Client are already shut.') $RenkSoluk; return }
    Yaz (T 'LoL ve Riot Client kapatılıyor...' 'Closing LoL and Riot Client...')
    $p | Stop-Process -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 20; $i++) {
        Bekle 0.5
        $kalan = @(Get-Process -Name $KapatSurecleri -ErrorAction SilentlyContinue)
        if (-not $kalan.Count) { Yaz (T 'Hepsi kapandı.' 'All closed.') $RenkYesil; return }
    }
    Yaz ((T 'Şunlar kapanmadı: ' "These didn't close: ") + (($kalan | ForEach-Object { $_.Name }) -join ', ')) $RenkKirmizi
}

function Lol-Ac {
    $mac = Surec 'League of Legends'
    if ($mac) { One-Getir $mac.MainWindowHandle; Yaz (T 'Maçtasın, oyunu öne getirdim.' "You're in a game, brought it to the front.") $RenkYesil; return }
    $h = Pencere-Bul
    if ($h -ne [IntPtr]::Zero) { One-Getir $h; Yaz (T 'LoL zaten açıktı, öne getirdim.' 'LoL was already open, brought it up.') $RenkYesil; return }
    if (Surec 'LeagueClientUx') {
        Yaz (T 'LoL arkada açık ama penceresi gizli, düzeltiyorum.' 'LoL is running but hidden, fixing it.')
        if (-not (Arayuz-Yenile)) { Kurtarma-Sor }
        return
    }
    Yaz (T "LoL'ü açıyorum..." 'Starting LoL...')
    # Riot Client açık ve giriş yapılmışsa doğrudan "Oyna"ya basılır; değilse Riot Client başlatılır
    $oynaBasildi = $false
    $rc = Rc-Bilgi
    if (Rc-Girisli $rc) { $oynaBasildi = Lol-Oyna $rc }
    if (-not $oynaBasildi) { Lol-Baslat }
    $riotGosterildi = $false
    for ($i = 1; $i -le $AcilisSn; $i++) {
        Bekle 1
        $h = Pencere-Bul
        if ($h -ne [IntPtr]::Zero) {
            Bekle 1
            One-Getir $h
            Yaz (T 'LoL açıldı abi, iyi eğlenceler.' 'LoL is up, have fun.') $RenkYesil
            return
        }
        # Riot Client açıldı ve giriş yapıldıysa (ya da sen şimdi giriş yaptıysan) "Oyna"ya biz basarız
        if (-not $oynaBasildi -and $i % 2 -eq 0 -and -not (Surec 'LeagueClient')) {
            $rc = Rc-Bilgi
            if (Rc-Girisli $rc) {
                $oynaBasildi = Lol-Oyna $rc
                if ($oynaBasildi) { Yaz (T "Riot Client'ta Oyna'ya bastım, LoL açılıyor..." 'Hit Play in Riot Client, LoL is starting...') }
            }
        }
        # Giriş yoksa Riot Client penceresi başka pencerelerin arkasında kalabiliyor; öne getirilir
        if (-not $riotGosterildi -and -not $oynaBasildi -and $i -ge 8 -and -not (Surec 'LeagueClient')) {
            $rc = Get-Process 'Riot Client' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
            if ($rc) {
                One-Getir $rc.MainWindowHandle
                $one = [LolPencere]::GetForegroundWindow() -eq $rc.MainWindowHandle
                $nerede = if ($one) { T 'öne getirdim' 'brought it up' } else { T 'görev çubuğunda' 'on the taskbar' }
                Yaz (T "Riot Client'ta giriş yapman lazım ($nerede). Giriş yapınca Oyna'ya ben basarım." "Log in to Riot Client ($nerede); I'll hit Play once you do.") $RenkTuruncu
                $riotGosterildi = $true
            }
        }
    }
    if (Surec 'LeagueClientUx') { Yaz (T "Client açıldı ama penceresi $AcilisSn saniyede gelmedi; 1'e bas." "The client started but its window didn't show in ${AcilisSn}s; press 1.") $RenkTuruncu }
    elseif ($riotGosterildi) { Yaz (T "Beklemeyi bıraktım; giriş yaptıktan sonra 3'e tekrar bas." 'Stopped waiting; press 3 again after you log in.') $RenkSoluk }
    else { Yaz (T 'Client açılmadı; Riot Client giriş ya da güncelleme ekranında olabilir.' "The client didn't open; Riot Client may be on the login or update screen.") $RenkTuruncu }
}

function Kapat-Ac {
    Hepsini-Kapat
    Bekle 3
    Lol-Ac
}

function Kurtarma-Sor {
    $c = Sor (T "Pencere gelmedi. LoL'ü tamamen kapatıp yeniden açayım mı? Giriş tekrar istenebilir, parti dağılır." "The window didn't show up. Fully close and reopen LoL? You may need to log in again; the party will break up.") @((T 'Kapat ve yeniden aç' 'Close and reopen'), (T 'Vazgeç' 'Cancel'))
    if ($c -eq 0) { Kapat-Ac }
}

function Ekran-Duzelt {
    $mac = Surec 'League of Legends'
    if ($mac) {
        $c = Sor (T 'Maçtasın. Bu seçenek client penceresi için; ne yapayım?' "You're in a game. This option is for the client window; what should I do?") @((T 'Oyunu öne getir' 'Bring the game to front'), (T 'Yine de client arayüzünü yeniden başlat' 'Restart the client UI anyway'), (T 'Vazgeç' 'Cancel'))
        if ($c -eq 0) { One-Getir $mac.MainWindowHandle; return }
        if ($c -ne 1) { return }
    }
    if (-not (Surec 'LeagueClientUx')) {
        if (Surec 'LeagueClient') {
            $c = Sor (T "LoL'ün ana süreci açık ama arayüzü hiç başlamamış. Tamamen kapatıp yeniden açayım mı?" "LoL's main process is running but its UI never started. Fully close and reopen it?") @((T 'Kapat ve yeniden aç' 'Close and reopen'), (T 'Vazgeç' 'Cancel'))
            if ($c -eq 0) { Kapat-Ac }
            return
        }
        Yaz (T 'LoL kapalıydı, açıyorum.' 'LoL was closed, starting it.')
        Lol-Ac
        return
    }
    $h = Pencere-Bul
    if ($h -ne [IntPtr]::Zero -and -not $mac) {
        One-Getir $h
        $c = Sor (T 'LoL penceresi zaten görünüyordu, öne getirdim. Donmuş ya da beyaz ekransa arayüzü yeniden başlatayım mı?' "The LoL window was already visible; brought it to front. If it's frozen or white, restart the UI?") @((T 'Arayüzü yeniden başlat' 'Restart the UI'), (T 'Gerek yok' 'No need'))
        if ($c -ne 0) { return }
    }
    if (-not (Arayuz-Yenile)) { Kurtarma-Sor }
}

# Client "yeniden bağlan" durumundayken bağlanır, oyunun açılmasını bekler
function Baglan-Iste($lcu) {
    [void](Lcu 'POST' '/lol-gameflow/v1/reconnect' $lcu)
    Yaz (T 'Maça yeniden bağlıyorum...' 'Reconnecting you to the match...')
    for ($i = 0; $i -lt 30; $i++) {
        Bekle 1
        if (Surec 'League of Legends') { Yaz (T 'Oyun açılıyor, birazdan maçtasın.' "The game's reopening, you'll be back in a moment.") $RenkYesil; return }
    }
    Yaz (T "Oyun 30 saniyede açılmadı; client'taki Yeniden Bağlan'a bas." "The game didn't open in 30s; hit Reconnect in the client.") $RenkTuruncu
}

function Yeniden-Baglan {
    $lcu = Lcu-Bilgi
    $faz = if ($lcu) { Lcu 'GET' '/lol-gameflow/v1/gameflow-phase' $lcu } else { @{ Kod = '000' } }
    if ($faz.Kod -ne '200') { Yaz (T "Client'a ulaşamadım, o yüzden oyuna dokunmadım." "Couldn't reach the client, so I left the game alone.") $RenkKirmizi; return }

    Yaz (T 'Oyunu kapatıp yeniden bağlayacağım...' "Closing the game, then I'll reconnect you...")
    Get-Process 'League of Legends' -ErrorAction SilentlyContinue | Stop-Process -Force
    for ($i = 0; $i -lt $YenidenBaglanSn; $i++) {
        Bekle 1
        $faz = Lcu 'GET' '/lol-gameflow/v1/gameflow-phase' $lcu
        if ($faz.Govde -match 'Reconnect') { Baglan-Iste $lcu; return }
    }
    Yaz (T "Client yeniden bağlanma ekranına geçmedi; Yeniden Bağlan'a sen bas." "The client didn't go to the reconnect screen; hit Reconnect yourself.") $RenkTuruncu
}

function Pencere-Tazele($mac) {
    $h = $mac.MainWindowHandle
    if ($h -eq [IntPtr]::Zero) { Yaz (T "Oyun penceresini bulamadım; olmazsa 2'ye tekrar basıp yeniden bağlan." "Couldn't find the game window; if needed, press 2 again and reconnect.") $RenkTuruncu; return }
    [void][LolPencere]::ShowWindow($h, 6)   # SW_MINIMIZE
    Bekle 0.7
    One-Getir $h
    Yaz (T "Oyun penceresini tazeledim; hâlâ yükleme ekranındaysan 2'ye tekrar bas." "Refreshed the game window; if it's still loading, press 2 again.") $RenkYesil
}

function Yukleme-Duzelt {
    $mac = Surec 'League of Legends'
    if (-not $mac) {
        # Oyun kapanmış ama maç sürüyorsa client yeniden bağlanmayı bekler
        $lcu = Lcu-Bilgi
        if ($lcu -and (Lcu 'GET' '/lol-gameflow/v1/gameflow-phase' $lcu).Govde -match 'Reconnect') {
            $c = Sor (T 'Maç sürüyor ama oyun kapalı. Yeniden bağlanayım mı?' 'The match is on but the game is closed. Reconnect?') @((T 'Yeniden bağlan' 'Reconnect'), (T 'Vazgeç' 'Cancel'))
            if ($c -eq 0) { Baglan-Iste $lcu }
            return
        }
        Yaz (T 'Açık bir maç yok; bu seçenek maç yüklenirken işe yarar.' "There's no game running; this one helps while a match is loading.") $RenkTuruncu
        return
    }

    # Maç başlayınca oyunun kendi API'si oyun süresini verir; yükleme ekranındayken vermez
    $r = Istek 'GET' "https://127.0.0.1:$OyunApiPort/liveclientdata/gamestats" $null
    $sure = 0
    if ($r.Kod -eq '200') { try { $sure = [double](($r.Govde | ConvertFrom-Json).gameTime) } catch {} }

    if ($sure -le 0) {
        $c = Sor (T 'Maç daha başlamamış; büyük ihtimalle başka bir oyuncu hâlâ yükleniyor. Sunucu yavaş yükleyenleri birkaç dakika bekler, sonra maçı onlarsız başlatır.' "The match hasn't started yet; most likely another player is still loading. The server waits a few minutes for slow loaders, then starts without them.") @((T 'Bekle (önerilen)' 'Wait (recommended)'), (T 'Yine de oyunu kapatıp yeniden bağlan' 'Close the game and reconnect anyway'))
        if ($c -eq 1) { Yeniden-Baglan } else { Yaz (T 'Tamam, bekliyoruz; birkaç dakikada açılmazsa tekrar bas.' "Okay, we wait; if it doesn't start in a few minutes, press again.") $RenkSoluk }
        return
    }
    $metin = (T 'Maç başlamış ({0}:{1:00}). Ekran yükleme ekranında kaldıysa:' 'The match has started ({0}:{1:00}). If your screen is stuck on loading:') -f [int][Math]::Floor($sure / 60), [int][Math]::Floor($sure % 60)
    $c = Sor $metin @((T 'Oyun penceresini tazele (2 sn, önce bunu dene)' 'Refresh the game window (2s, try this first)'), (T 'Oyunu kapatıp hemen yeniden bağlan (~30 sn)' 'Close the game and reconnect now (~30s)'), (T 'Vazgeç' 'Cancel'))
    if ($c -eq 0) { Pencere-Tazele $mac }
    elseif ($c -eq 1) { Yeniden-Baglan }
}

function Lol-Kapat {
    if (Surec 'League of Legends') {
        $c = Sor (T 'Şu an maçtasın. Kapatırsan maçtan düşersin; dönmezsen ceza alabilirsin.' "You're in a game. Closing drops you from the match; you may be penalized if you don't return.") @((T 'Vazgeç' 'Cancel'), (T 'Yine de hepsini kapat' 'Close everything anyway'))
        if ($c -ne 1) { return }
    }
    Hepsini-Kapat
}

# ---- Sıraya gir ----
function Lobi-Oku($lcu) {
    $r = Lcu 'GET' '/lol-lobby/v2/lobby' $lcu $null 3000
    if ($r.Kod -eq '200') { try { return ($r.Govde | ConvertFrom-Json) } catch {} }
    return $null
}

function Sure-Metin($sn) {
    $sn = [int][Math]::Ceiling([double]$sn)
    $dk = [int][Math]::Floor($sn / 60); $s = $sn % 60
    if ($dk -gt 0) { T "$dk dk $s sn" "$dk min $s s" } else { T "$s sn" "$s s" }
}
function Sure-Kisa($sn) {
    $sn = [Math]::Max(0, [int][Math]::Floor([double]$sn))
    '{0}:{1:00}' -f [int][Math]::Floor($sn / 60), ($sn % 60)
}

# Seçili sıranın lobisini açar (yoksa ya da başka sıradaysa), rolleri ayarlar, sırayı başlatır; sıradaysan sıradan çıkar
function Sira-Gir {
    $id = [int]$Ayar.sira
    $ad = Sira-Adi $id
    if (-not $Deneme -and (Surec 'League of Legends')) { Yaz (T 'Maçtasın, şu an sıraya giremem.' "You're in a game, I can't queue right now.") $RenkTuruncu; return }

    $lcu = Lcu-Bilgi
    $faz = if ($lcu) { Faz-Oku $lcu } else { $null }
    if (-not $faz) {
        if ($Deneme) { Yaz (T 'Sahte client yanıt vermiyor.' 'Test client not responding.') $RenkKirmizi; return }
        if (-not (Surec 'LeagueClientUx')) {
            Yaz (T 'LoL kapalıydı, önce onu açıyorum.' 'LoL was closed, opening it first.')
            Lol-Ac
        }
        for ($i = 0; $i -lt $HazirlikSn -and -not $faz; $i++) {
            Bekle 1
            $lcu = Lcu-Bilgi
            if ($lcu) { $faz = Faz-Oku $lcu }
        }
        if (-not $faz) { Yaz (T 'Client daha hazır değil; giriş yaptıysan birazdan tekrar bas.' "The client isn't ready yet; if you've logged in, try again in a moment.") $RenkTuruncu; return }
    }

    # Sıradaysan ana düğme "Sıradan çık"tır: sırayı iptal eder
    if ($faz -eq 'Matchmaking') {
        $r = Lcu 'DELETE' '/lol-lobby/v2/lobby/matchmaking/search' $lcu $null 5000
        if ($r.Kod -like '2*') { Yaz (T 'Sıradan çıktın.' 'Left the queue.') $RenkYesil }
        else { Yaz (T "Sıradan çıkamadım ($(Lcu-Hata $r))." "Couldn't leave the queue ($(Lcu-Hata $r)).") $RenkKirmizi }
        Faz-Takip
        return
    }
    if ($faz -eq 'ReadyCheck') { Yaz (T 'Maç zaten bulunmuş.' 'A match was already found.') $RenkYesil; return }
    if (@('ChampSelect', 'GameStart', 'InProgress', 'Reconnect') -contains $faz) {
        Yaz (T "Şu an $(Faz-Adi $faz) olduğun için sıraya giremem." "You're $(Faz-Adi $faz) right now, so I can't queue.") $RenkTuruncu; return
    }

    # Lobi: yoksa ya da başka sıradaysa seçili sıranın lobisi açılır (parti korunur)
    $lobi = Lobi-Oku $lcu
    if (-not ($lobi -and [int]$lobi.gameConfig.queueId -eq $id)) {
        if ($lobi -and -not $lobi.localMember.isLeader) {
            Yaz (T 'Başkasının lobisindesin; sırayı parti lideri değiştirebilir.' "You're in someone else's lobby; only the party leader can change the queue.") $RenkTuruncu; return
        }
        Yaz (T "$ad lobisi açılıyor..." "Opening a $ad lobby...")
        $r = $null
        for ($i = 0; $i -lt 8; $i++) {   # client yeni açıldıysa lobi servisi birkaç saniye hazır olmayabilir
            $r = Lcu 'POST' '/lol-lobby/v2/lobby' $lcu "{`"queueId`":$id}" 5000
            if ($r.Kod -like '2*') { break }
            Bekle 1.5
        }
        if ($r.Kod -notlike '2*') { Yaz (T "Lobiyi açamadım ($(Lcu-Hata $r))." "Couldn't create the lobby ($(Lcu-Hata $r)).") $RenkKirmizi; return }
        Bekle 1
        $lobi = Lobi-Oku $lcu
        if (-not $lobi) { Yaz (T "Lobi açıldı ama okuyamadım; client'a bak." "The lobby opened but I couldn't read it; check the client.") $RenkTuruncu; return }
    }
    if (-not $lobi.localMember.isLeader) { Yaz (T 'Sırayı parti lideri başlatabilir; onun basmasını bekle.' 'Only the party leader can start the queue; wait for them.') $RenkTuruncu; return }

    # Roller (rol seçilen sıralarda)
    $rolMetni = ''
    if ($lobi.gameConfig.showPositionSelector) {
        $r1 = "$($Ayar.rol1)"; $r2 = "$($Ayar.rol2)"
        if ($r1) {
            if ($r1 -eq 'FILL') { $r2 = 'UNSELECTED' } elseif (-not $r2 -or $r2 -eq $r1) { $r2 = 'FILL' }
            $p = Lcu 'PUT' '/lol-lobby/v2/lobby/members/localMember/position-preferences' $lcu "{`"firstPreference`":`"$r1`",`"secondPreference`":`"$r2`"}" 5000
            if ($p.Kod -notlike '2*') { Yaz (T "Rolleri seçemedim ($(Lcu-Hata $p))." "Couldn't set roles ($(Lcu-Hata $p)).") $RenkKirmizi; return }
            Bekle 0.5
        } else {
            $r1 = "$($lobi.localMember.firstPositionPreference)"; $r2 = "$($lobi.localMember.secondPositionPreference)"
            if (-not $r1 -or $r1 -eq 'UNSELECTED' -or ($r1 -ne 'FILL' -and (-not $r2 -or $r2 -eq 'UNSELECTED'))) {
                Yaz (T "Rolün seçili değil; düğmenin yanındaki rol yazısından ya da client'tan seç." 'No role selected: pick one next to the button or in the client.') $RenkTuruncu; return
            }
        }
        $rolMetni = if ($r1 -eq 'FILL') { Rol-Kod-Adi 'FILL' } else { "$(Rol-Kod-Adi $r1) / $(Rol-Kod-Adi $r2)" }
    }

    # Sıra
    $s = Lcu 'POST' '/lol-lobby/v2/lobby/matchmaking/search' $lcu $null 5000
    if ($s.Kod -notlike '2*') { Yaz (T "Sıraya giremedim ($(Lcu-Hata $s))." "Couldn't start the queue ($(Lcu-Hata $s)).") $RenkKirmizi; return }
    $ek = if ($rolMetni) { " ($rolMetni)" } else { '' }
    for ($i = 0; $i -lt 10; $i++) {
        Bekle 1
        $d = Lcu 'GET' '/lol-lobby/v2/lobby/matchmaking/search-state' $lcu $null 2000
        $j = $null
        if ($d.Kod -eq '200') { try { $j = $d.Govde | ConvertFrom-Json } catch {} }
        $hatalar = @($j.errors | Where-Object { $_ })
        if ($hatalar.Count) {
            $h = $hatalar[0]
            $metin = if ([double]$h.penaltyTimeRemaining -gt 0) { T "sıra cezası var, $(Sure-Metin $h.penaltyTimeRemaining) kaldı" "queue penalty, $(Sure-Metin $h.penaltyTimeRemaining) left" } else { "$($h.errorType) $($h.message)".Trim() }
            Yaz (T "Sıraya giremedim: $metin." "Couldn't queue: $metin.") $RenkKirmizi
            return
        }
        $simdi = Faz-Oku $lcu
        if ($j.searchState -eq 'Searching' -or $j.searchState -eq 'Found' -or $simdi -eq 'Matchmaking' -or $simdi -eq 'ReadyCheck') {
            $dusuk = [double]$j.lowPriorityData.penaltyTimeRemaining
            $tamam = T "Sıradasın: $ad$ek." "You're in queue: $ad$ek."
            if ($dusuk -gt 0) { $tamam += T " Önce $(Sure-Metin $dusuk) düşük öncelik beklemen var." " First you'll wait $(Sure-Metin $dusuk) in low priority." }
            elseif (-not $Ayar.kabul) { $tamam += T ' Kabul otomatik değil; maç bulununca client''a bak.' " Auto-accept is off; watch the client." }
            Yaz $tamam $(if ($dusuk -gt 0) { $RenkTuruncu } else { $RenkYesil })
            Bildir (T "Sıradasın: $ad$ek" "In queue: $ad$ek")
            Faz-Takip
            return
        }
    }
    Yaz (T "Sıra isteğini gönderdim ama sırada göremedim; client'a bak." "Sent the queue request but couldn't see you in queue; check the client.") $RenkTuruncu
}

function Calistir($islem) {
    # Meşgulken başka seçenek seçilirse süren bekleme kesilir, yeni seçenek ardından çalışır
    if ($script:Mesgul) { if ($islem -ne $script:Calisan) { $script:Sirada = $islem }; return }
    $script:Mesgul = $true
    while ($islem) {
        $script:Sirada = $null
        $script:Calisan = $islem
        Satir-Isaretle
        try {
            switch ($islem) {
                'ekran'   { Ekran-Duzelt }
                'yukleme' { Yukleme-Duzelt }
                'ac'      { Lol-Ac }
                'kapat'   { Lol-Kapat }
                'sira'    { Sira-Gir }
                'custom'      { Custom-Uygula }
                'customhazir' { Custom-Uygula -Hazirlik }
                'customkapat' { Custom-Durdur }
                'kaynak'      { Kaynak-Degistir }
                'ackip'       { Lol-Kipli-Ac }
                'roseaktar'   { Rose-Aktar }
                'modekle'     { Mod-Ekle }
                'ltkkur'      { Ltk-Kur }
                'cokme'       { Cokme-Isle }
            }
        } catch {
            $m = "$($_.Exception.Message)"
            if ($m -eq 'iptal') { Yaz (T 'Onu bıraktım.' 'Dropped that.') $RenkSoluk }
            elseif ($m -ne 'kapandi') { Yaz ((T 'Bir şey ters gitti: ' 'Something went wrong: ') + $m) $RenkKirmizi }
        }
        if ($script:Kapandi) { return }
        $islem = $script:Sirada
    }
    $script:Mesgul = $false
    $script:Calisan = $null
    Satir-Isaretle
    Durum-Guncelle
}

# ---- Ayarlar dosyası ----
function Liste3($x) {
    $l = @($x | ForEach-Object { [int]$_ })
    while ($l.Count -lt 3) { $l += 0 }
    $sonuc = [int[]]$l[0..2]
    return ,$sonuc
}

function Ayar-Yukle {
    $a = [ordered]@{ dil = 'tr'; kabul = $false; ban = $false; banListe = [int[]](0, 0, 0); pick = $false; kilitle = $true; bekleSn = 0
                     sira = 420; rol1 = ''; rol2 = 'FILL'; pickListe = [ordered]@{}; custom = $false; customGorsel = @{}; customAd = @{}
                     # customRakip: custom'lar rakiplerde de görünsün mü (kapalı = maçta yalnız oynadığın şampiyonunki açık)
                     # customSecim: şampiyon kimliği -> seçtiğin mod ('' = klasik). LTK'ya bunun maça uyan kısmı yazılır.
                     # ltkKapat: Riot Plus kapanınca LTK Manager da kapansın mı (maç sürüyorsa dokunulmaz)
                     # customKaynak: custom'ı kim uygular: 'ltk' (Riot Plus + LTK Manager, kendi modların) ya da 'rose' (Rose)
                     customRakip = $false; customSecim = $null; ltkKapat = $true; customKaynak = 'ltk' }
    foreach ($r in $Roller.Keys) { $a.pickListe[$r] = [int[]](0, 0, 0) }
    try {
        $j = [IO.File]::ReadAllText($AyarDosyasi) | ConvertFrom-Json
        if ("$($j.dil)" -eq 'en') { $a.dil = 'en' }
        if ("$($j.customKaynak)" -eq 'rose') { $a.customKaynak = 'rose' }
        foreach ($ad in 'kabul', 'ban', 'pick', 'kilitle', 'custom', 'customRakip', 'ltkKapat') { if ($null -ne $j.$ad) { $a[$ad] = [bool]$j.$ad } }
        if ($null -ne $j.customSecim) { $a.customSecim = @{}; foreach ($p in $j.customSecim.PSObject.Properties) { $a.customSecim[$p.Name] = "$($p.Value)" } }
        if ($null -ne $j.bekleSn) { $a.bekleSn = [Math]::Max(0, [Math]::Min(25, [int]$j.bekleSn)) }
        if ($j.banListe) { $a.banListe = Liste3 $j.banListe }
        foreach ($r in $Roller.Keys) { if ($j.pickListe.$r) { $a.pickListe[$r] = Liste3 $j.pickListe.$r } }
        if ($null -ne $j.sira -and $SiraIdleri -contains [int]$j.sira) { $a.sira = [int]$j.sira }
        $r1 = "$($j.rol1)".ToUpperInvariant(); if ($Rol1Kodlar -contains $r1) { $a.rol1 = $r1 }
        $r2 = "$($j.rol2)".ToUpperInvariant(); if ($Rol2Kodlar -contains $r2) { $a.rol2 = $r2 }
        # modId -> elle seçilen görsel dosyası / gösterilecek ad
        foreach ($ad in 'customGorsel', 'customAd') { if ($j.$ad) { foreach ($p in $j.$ad.PSObject.Properties) { if ("$($p.Value)") { $a[$ad][$p.Name] = "$($p.Value)" } } } }
    } catch {}
    return $a
}

function Ayar-Kaydet {
    if ($script:Yukleniyor) { return }
    try { [IO.File]::WriteAllText($AyarDosyasi, ($Ayar | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false))) }
    catch { Yaz ((T 'Ayarı kaydedemedim: ' "Couldn't save settings: ") + $_.Exception.Message) $RenkKirmizi }
}

# ---- Şampiyon listesi (Riot'un herkese açık Data Dragon verisi: Türkçe + İngilizce ad + görsel kodu; 14 günde bir tazelenir) ----
function Ad-Normal($s) {
    return ("$s".Replace('İ', 'i').Replace('I', 'i').Replace('ı', 'i').ToLowerInvariant() -replace '[^a-z0-9çğöşü]', '')
}

# Bir dildeki şampiyonlar: @{ Ad = @{ id = ad }; Kod = @{ id = görsel kodu } }; olmazsa $null
function Ddragon-Adlar($surum, $yerel) {
    $c = Istek 'GET' "https://ddragon.leagueoflegends.com/cdn/$surum/data/$yerel/champion.json" $null $null 10000
    if ($c.Kod -ne '200') { return $null }
    $ad = @{}; $kod = @{}
    foreach ($p in ($c.Govde | ConvertFrom-Json).data.PSObject.Properties) { $ad[[int]$p.Value.key] = $p.Value.name; $kod[[int]$p.Value.key] = $p.Value.id }
    return @{ Ad = $ad; Kod = $kod }
}

function Sampiyon-Yukle {
    $liste = $null; $eski = $null; $surum = $null
    try {
        $j = [IO.File]::ReadAllText($SampiyonDosyasi) | ConvertFrom-Json
        $eski = $j.liste; $surum = $j.surum
        $tamVeri = @($eski | Where-Object { $_.en -and $_.kod }).Count -gt 0
        if ($tamVeri -and ((Get-Date) - [datetime]$j.tarih).TotalDays -lt 14) { $liste = $eski }
    } catch {}
    if (-not $liste) {
        $v = Istek 'GET' 'https://ddragon.leagueoflegends.com/api/versions.json' $null $null 8000
        if ($v.Kod -eq '200') {
            $yeniSurum = ($v.Govde | ConvertFrom-Json)[0]
            $tr = Ddragon-Adlar $yeniSurum 'tr_TR'
            $en = Ddragon-Adlar $yeniSurum 'en_US'
            if ($tr) {
                $surum = $yeniSurum
                $liste = @($tr.Ad.Keys | ForEach-Object { [pscustomobject]@{ id = [int]$_; ad = $tr.Ad[$_]; en = $(if ($en -and $en.Ad[$_]) { $en.Ad[$_] } else { $tr.Ad[$_] }); kod = $tr.Kod[$_] } })
                $kayit = @{ tarih = (Get-Date).ToString('o'); surum = $surum; liste = $liste } | ConvertTo-Json -Depth 3
                try { [IO.File]::WriteAllText($SampiyonDosyasi, $kayit, (New-Object Text.UTF8Encoding($false))) } catch {}
            }
        }
        if (-not $liste) { $liste = $eski }
    }
    $script:DdSurum = $surum
    $script:SampiyonTr = @{}; $script:SampiyonEn = @{}; $script:SampiyonAd = @{}; $script:SampiyonKod = @{}
    foreach ($s in @($liste)) {
        if (-not $s) { continue }
        $id = [int]$s.id
        $script:SampiyonTr[$id] = $s.ad
        $script:SampiyonEn[$id] = if ($s.en) { $s.en } else { $s.ad }
        if ($s.kod) { $script:SampiyonKod[$id] = $s.kod }
        # Yazılan ad iki dilde de tanınır
        $script:SampiyonAd[(Ad-Normal $s.ad)] = $id
        $script:SampiyonAd[(Ad-Normal $script:SampiyonEn[$id])] = $id
    }
}

function Sampiyon-Listesi {
    $kaynak = if ($script:Dil -eq 'en') { $script:SampiyonEn } else { $script:SampiyonTr }
    return [string[]]@($kaynak.Values | Sort-Object)
}

function Sampiyon-Adi($id) {
    $ad = if ($script:Dil -eq 'en') { $script:SampiyonEn[[int]$id] } else { $script:SampiyonTr[[int]$id] }
    if ($ad) { return $ad } else { return "#$id" }
}

# ---- Görseller: Data Dragon'dan bir kez iner, gorsel\<tür>\<kod> olarak saklanır ----
$script:Indirmeler = @{}     # yerel yol -> indirme görevi
$script:GorselBellek = @{}   # tür|kod -> BitmapImage
# 'skin' türünde kod "Talon_12" gibidir (o skinin splash'ı)
function Gorsel-Yol($tur, $kod) { Join-Path $GorselKlasoru "$tur\$kod.$(if ($tur -eq 'ikon') { 'png' } else { 'jpg' })" }
function Gorsel-Url($tur, $kod) {
    if ($tur -eq 'splash') { "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/${kod}_0.jpg" }
    elseif ($tur -eq 'skin') { "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/$kod.jpg" }
    else { "https://ddragon.leagueoflegends.com/cdn/$($script:DdSurum)/img/champion/$kod.png" }
}
# Yerelde varsa dosyadan, yoksa internetten (WPF kendisi arka planda indirir) ve aynı anda önbelleğe indirilir
function Gorsel($tur, $kod) {
    if (-not $kod) { return $null }
    $anahtar = "$tur|$kod"
    if ($script:GorselBellek[$anahtar]) { return $script:GorselBellek[$anahtar] }
    $yol = Gorsel-Yol $tur $kod
    $bi = New-Object Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    if (Test-Path $yol) { $bi.UriSource = New-Object Uri($yol); $bi.CacheOption = 'OnLoad' }
    else {
        $bi.UriSource = New-Object Uri((Gorsel-Url $tur $kod))
        if (-not $script:Indirmeler[$yol] -and -not $Sessiz) {
            try {
                [void](New-Item -ItemType Directory -Force (Split-Path $yol))
                $script:Indirmeler[$yol] = (New-Object Net.WebClient).DownloadFileTaskAsync((Gorsel-Url $tur $kod), "$yol.iniyor")
            } catch {}
        }
    }
    $bi.DecodePixelWidth = if ($tur -eq 'ikon') { 80 } else { 880 }
    $bi.EndInit()
    if (Test-Path $yol) { $script:GorselBellek[$anahtar] = $bi }
    return $bi
}
# Biten indirmeleri yerine koyar (zamanlayıcıdan)
function Indirme-Tick {
    foreach ($yol in @($script:Indirmeler.Keys)) {
        $g = $script:Indirmeler[$yol]
        if (-not $g.IsCompleted) { continue }
        $script:Indirmeler.Remove($yol)
        try { if (-not $g.IsFaulted -and (Get-Item "$yol.iniyor").Length -gt 0) { Move-Item "$yol.iniyor" $yol -Force } else { Remove-Item "$yol.iniyor" -ErrorAction SilentlyContinue } } catch {}
    }
}
# Yalnız -Kare: görseli eşzamanlı indirir (resim alınırken hazır olsun)
function Gorsel-Hazirla($tur, $kod) {
    $yol = Gorsel-Yol $tur $kod
    if ($kod -and -not (Test-Path $yol)) { [void](New-Item -ItemType Directory -Force (Split-Path $yol)); (New-Object Net.WebClient).DownloadFile((Gorsel-Url $tur $kod), $yol) }
}

# ---- Otomatik kabul / ban / pick ----
$script:Secim   = $null   # şampiyon seçimi durumu; her yeni seçimde sıfırlanır
$script:OtoHata = ''
function Oto-Durum($metin) { $script:OtoDurumMetni = $metin }

function Faz-Adi($faz) {
    switch ($faz) {
        'None'            { T 'ana ekranda' 'on the home screen' }
        'Lobby'           { T 'lobide' 'in lobby' }
        'Matchmaking'     { T 'sırada' 'in queue' }
        'ReadyCheck'      { T 'maç bulundu' 'match found' }
        'ChampSelect'     { T 'şampiyon seçiminde' 'in champ select' }
        'GameStart'       { T 'maç başlarken' 'game starting' }
        'InProgress'      { T 'maçta' 'in game' }
        'Reconnect'       { T 'yeniden bağlanma beklerken' 'waiting to reconnect' }
        'WaitingForStats' { T 'maç sonunda' 'post-game' }
        'PreEndOfGame'    { T 'maç sonunda' 'post-game' }
        'EndOfGame'       { T 'maç sonunda' 'post-game' }
        default           { "$faz" }
    }
}

function Rol-Anahtar($p) {
    $p = "$p"
    if ($p -and $p -ne 'genel' -and $Roller.Contains($p)) { return $p }
    return 'genel'
}

function Oto-Tick {
    if (-not ($Ayar.kabul -or $Ayar.ban -or $Ayar.pick)) { $script:Secim = $null; return }
    if (-not $Deneme -and -not (Surec 'LeagueClientUx')) { $script:Secim = $null; return }
    $lcu = Lcu-Bilgi
    if (-not $lcu) { return }
    $f = Lcu 'GET' '/lol-gameflow/v1/gameflow-phase' $lcu $null 2000
    if ($f.Kod -ne '200') { return }
    $faz = $f.Govde.Trim().Trim('"')
    if ($faz -eq 'ReadyCheck') {
        if ($Ayar.kabul) { Oto-Kabul $lcu }
    } elseif ($faz -eq 'ChampSelect') {
        if ($Ayar.ban -or $Ayar.pick) { Oto-Secim $lcu }
    } else {
        $script:Secim = $null
    }
}

function Oto-Kabul($lcu) {
    $r = Lcu 'GET' '/lol-matchmaking/v1/ready-check' $lcu $null 2000
    if ($r.Kod -ne '200') { return }
    $rc = $r.Govde | ConvertFrom-Json
    if ($rc.state -ne 'InProgress' -or $rc.playerResponse -ne 'None') { return }   # sen reddettiysen dokunmaz
    $a = Lcu 'POST' '/lol-matchmaking/v1/ready-check/accept' $lcu $null 2000
    if ($a.Kod -like '2*') {
        Yaz (T 'Maç bulundu, kabul ettim.' 'Match found, accepted.') $RenkYesil
        Bildir (T 'Maç bulundu, kabul ettim.' 'Match found, accepted.')
    } else { Yaz (T "Maçı kabul edemedim (HTTP $($a.Kod)); hemen client'tan kabul et." "Couldn't accept the match (HTTP $($a.Kod)); accept it in the client now.") $RenkTuruncu }
}

# Listedeki ilk uygun şampiyon: alınmamış, banlanmamış, hariç değil, seçilebilir; yoksa 0
function Aday-Sec($liste, $alinan, $haric, $izinli) {
    foreach ($id in $liste) {
        $id = [int]$id
        if ($id -le 0 -or $alinan[$id] -or $haric[$id] -or $script:Secim.Olmaz[$id]) { continue }
        if ($izinli -and $izinli -notcontains $id) { continue }
        return $id
    }
    return 0
}

function Oto-Secim($lcu) {
    $r = Lcu 'GET' '/lol-champ-select/v1/session' $lcu $null 2000
    if ($r.Kod -ne '200') { return }
    $s = $r.Govde | ConvertFrom-Json
    $ben = [int]$s.localPlayerCellId
    $benim = @($s.myTeam) | Where-Object { $_ -and [int]$_.cellId -eq $ben } | Select-Object -First 1
    $rol = Rol-Anahtar $benim.assignedPosition

    if (-not $script:Secim) {
        $script:Secim = @{ Yapilan = @{}; Ilk = @{}; Hover = 0; Olmaz = @{}; NiyetOlmaz = @{}; Secilebilir = $null; Onay = @{}; Deneme = @{}; SecDeneme = @{}; Secildi = @{} }
        # Seçilebilir (sahip olunan) şampiyonlar. "bannable-champion-ids" KULLANILMAZ: ban aşaması dışında [-1] döner
        # (3 Kas 2026 gerçek maçta görüldü) ve bütün ban listesini geçersiz saydırıyordu. Geçersiz ban client'tan hata
        # döner, Olmaz'a yazılır, listedeki sıradakine geçilir.
        $x = Lcu 'GET' '/lol-champ-select/v1/pickable-champion-ids' $lcu $null 2000
        if ($x.Kod -eq '200') {
            $j = $x.Govde | ConvertFrom-Json   # önce değişkene: PS 5.1 diziyi boru hattına tek nesne verir
            $ids = @($j | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 0 })
            if ($ids.Count) { $script:Secim.Secilebilir = $ids }
        }
        $ek = if ($rol -ne 'genel') { T ", rolün $(Rol-Adi $rol)" ", your role: $(Rol-Adi $rol)" } else { '' }
        Yaz (T "Şampiyon seçimi başladı$ek." "Champ select started$ek.") $RenkSoluk
    }

    # Alınmış sayılanlar: seçilmiş/kilitlenmiş şampiyonlar (benimki hariç) ve banlar
    $alinan = @{}
    foreach ($o in @($s.myTeam) + @($s.theirTeam)) {
        if ($o -and [int]$o.championId -gt 0 -and [int]$o.cellId -ne $ben) { $alinan[[int]$o.championId] = $true }
    }
    foreach ($id in @($s.bans.myTeamBans) + @($s.bans.theirTeamBans)) { if ([int]$id -gt 0) { $alinan[[int]$id] = $true } }
    $bekleyen = @()
    $tumu = @{}
    foreach ($grup in @($s.actions)) {
        foreach ($a in @($grup)) {
            if (-not $a) { continue }
            $tumu[[int]$a.id] = $a
            if ($a.completed -and [int]$a.championId -gt 0) { $alinan[[int]$a.championId] = $true }
            if ([int]$a.actorCellId -eq $ben -and -not $a.completed) { $bekleyen += $a }
        }
    }
    # Takım arkadaşlarının oynamak istediği şampiyonlar banlanmaz
    $niyet = @{}
    foreach ($o in @($s.myTeam)) {
        if ($o -and [int]$o.cellId -ne $ben -and [int]$o.championPickIntent -gt 0) { $niyet[[int]$o.championPickIntent] = $true }
    }
    Onay-Kontrol $tumu
    $pickListe = @($Ayar.pickListe[$rol])
    if ($rol -ne 'genel') { $pickListe += @($Ayar.pickListe['genel']) }
    $b = @{ S = $s; Alinan = $alinan; Niyet = $niyet; Pick = $pickListe }

    # Planlama (niyet) aşamasında ban aksiyonu "isInProgress" görünür ama client seçimi de kilidi de yok sayar
    # (5 Kas 2026 gerçek maç logu: 12 sn'lik PLANNING'de 4 deneme boşa gitti). Bu aşamada yalnız pick niyeti gösterilir.
    $planlama = "$($s.timer.phase)" -eq 'PLANNING'
    $ban = if ($planlama) { $null } else { $bekleyen | Where-Object { $_.type -eq 'ban' -and $_.isInProgress } | Select-Object -First 1 }
    if ($ban -and $Ayar.ban) { Oto-Aksiyon $lcu $ban 'ban' $b }
    $pick = $bekleyen | Where-Object { $_.type -eq 'pick' } | Select-Object -First 1
    if ($pick -and $Ayar.pick) {
        if ($pick.isInProgress -and -not $planlama) { Oto-Aksiyon $lcu $pick 'pick' $b }
        elseif (-not $ban -or -not $Ayar.ban) { Oto-Niyet $lcu $pick $b }
    }
}

# Yalnız gunluk.txt'ye (arayüzde gösterilmez): otomatik seçimin teşhis satırları
function Iz($metin) {
    try { [IO.File]::AppendAllText($GunlukDosyasi, "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  [oto] $metin`r`n", (New-Object Text.UTF8Encoding($false))) } catch {}
}

# Kilit isteği gönderilen aksiyonlar: client oturumunda gerçekten tamamlandıysa başarı yazılır,
# 2,5 sn'de tamamlanmadıysa bekleme kaldırılır ve sonraki turda yeniden denenir
function Onay-Kontrol($tumu) {
    $sec = $script:Secim
    foreach ($id in @($sec.Onay.Keys)) {
        $o = $sec.Onay[$id]
        $a = $tumu[[int]$id]
        if ($a -and $a.completed) {
            $sec.Onay.Remove($id)
            $sec.Yapilan[$id] = $true
            $ad = Sampiyon-Adi ([int]$a.championId)
            Iz "$($o.Tur) #$id tamamlandı: $([int]$a.championId) (yöntem $($o.Yontem), deneme $($sec.Deneme[$id]))"
            if ($o.Tur -eq 'ban') { Yaz (T "$ad banlandı." "Banned $ad.") $RenkYesil }
            else {
                Yaz (T "$ad kilitlendi. İyi oyunlar abi." "Locked in $ad. Have a good game.") $RenkYesil
                Bildir (T "$ad kilitlendi" "Locked in $ad")
            }
        } elseif (([DateTime]::Now - $o.Zaman).TotalSeconds -gt 2.5) {
            $sec.Onay.Remove($id)
            Iz "$($o.Tur) #$id 2,5 sn'de tamamlanmadı (yöntem $($o.Yontem), oturumdaki şampiyon $(if ($a) { [int]$a.championId } else { '?' }))"
        }
    }
}

# Sıra sana geldiğinde ban/pick atar. Seçim (PATCH championId) ve kilit (POST .../complete) ayrı istektir:
# client PATCH'teki "completed" alanını artık yok sayıyor ama 2xx dönüyor (3 Kas 2026 gerçek maçta görüldü)
function Oto-Aksiyon($lcu, $a, $tur, $b) {
    $id = [int]$a.id
    $sec = $script:Secim
    if ($sec.Yapilan[$id] -or $sec.Onay.ContainsKey($id)) { return }
    if (-not $sec.Ilk[$id]) { $sec.Ilk[$id] = [DateTime]::Now }
    $kalanMs = [double]$b.S.timer.adjustedTimeLeftInPhase
    if (([DateTime]::Now - $sec.Ilk[$id]).TotalSeconds -lt $Ayar.bekleSn -and ($kalanMs -le 0 -or $kalanMs -gt 5000)) { return }

    if ($tur -eq 'ban') { $liste = $Ayar.banListe; $haric = $b.Niyet; $izinli = $null }
    else { $liste = $b.Pick; $haric = @{}; $izinli = $sec.Secilebilir }
    # Sen kendin bir şampiyonun üzerine geldiysen (benim gösterdiğim değilse) onu kullanır
    $simdiki = [int]$a.championId
    if ($simdiki -gt 0 -and $simdiki -ne $sec.Hover -and -not $b.Alinan[$simdiki] -and -not $sec.Olmaz[$simdiki]) { $secilen = $simdiki }
    else { $secilen = Aday-Sec $liste $b.Alinan $haric $izinli }

    if (-not $secilen) {
        $metin = if ($tur -eq 'ban') { T 'Ban listendekilerin hepsi alınmış; banı sen at.' 'Everyone on your ban list is taken; ban one yourself.' } else { T 'Listendekiler alınmış ya da sende yok; seçimi sen yap.' 'Your list is taken or not owned; pick yourself.' }
        Yaz $metin $RenkTuruncu
        $sec.Yapilan[$id] = $true
        return
    }
    $ad = Sampiyon-Adi $secilen
    $kilitle = ($tur -eq 'ban') -or $Ayar.kilitle

    # 1) SEÇ. Kilit AYNI turda gönderilmez: 5 Kas 2026 client logu ("updateActionV1 requesting to select championId: 246"
    #    ardından 60 ms sonra "requesting to lockIn championId: 0") → PATCH'ten hemen sonraki /complete şampiyonu 0 sanıp
    #    boş kilitliyor, hiçbir deneme tutmuyordu. Elle basılan kilitte önünde PATCH yok ve doğru şampiyonla gidiyor.
    if ($simdiki -ne $secilen) {
        $sd = [int]$sec.SecDeneme[$id] + 1; $sec.SecDeneme[$id] = $sd
        if ($sd -gt 3) {   # client seçimi 3 kez göstermedi → bu şampiyon olmuyor, sıradakine
            $sec.Olmaz[$secilen] = $true; $sec.SecDeneme[$id] = 0
            Iz "$tur #$id $secilen seçimi oturuma yansımadı, sıradaki"
            return
        }
        $y = Lcu 'PATCH' "/lol-champ-select/v1/session/actions/$id" $lcu "{`"championId`":$secilen}" 2000
        if ($y.Kod -notlike '2*') {
            $sec.Olmaz[$secilen] = $true   # sonraki turda listedeki sıradakini dener
            Yaz (T "$ad olmadı ($(Lcu-Hata $y)), sıradakini deniyorum." "$ad didn't work ($(Lcu-Hata $y)), trying the next one.") $RenkTuruncu
            return
        }
        $sec.Secildi[$id] = [DateTime]::Now
        Iz "$tur #$id seçildi: $secilen (PATCH $($y.Kod))"
        if (-not $kilitle) {
            $sec.Yapilan[$id] = $true
            $sec.Hover = $secilen
            Yaz (T "$ad seçili; kilitlemek sende." "$ad hovered; locking in is up to you.") $RenkYesil
        }
        return
    }
    if (-not $kilitle) {   # niyetten zaten üzerinde
        $sec.Yapilan[$id] = $true
        $sec.Hover = $secilen
        Yaz (T "$ad seçili; kilitlemek sende." "$ad hovered; locking in is up to you.") $RenkYesil
        return
    }

    # 2) KİLİTLE: seçim oturumda görünüyor ve son PATCH'in üstünden en az 0,8 sn geçti
    if ($sec.Secildi[$id] -and ([DateTime]::Now - $sec.Secildi[$id]).TotalSeconds -lt 0.8) { return }
    $deneme = [int]$sec.Deneme[$id] + 1
    $sec.Deneme[$id] = $deneme
    if ($deneme -gt 6) {
        $sec.Yapilan[$id] = $true
        Iz "$tur #$id 6 kilit denemesi tutmadı ($secilen)"
        $metin = if ($tur -eq 'ban') { T 'Banı kilitleyemedim; sen at.' "Couldn't lock the ban; do it yourself." } else { T 'Seçimi kilitleyemedim; sen kilitle.' "Couldn't lock the pick; lock in yourself." }
        Yaz $metin $RenkKirmizi
        return
    }
    # Asıl yol POST .../complete; 3 deneme tutmazsa yedek yol PATCH {championId, completed:true} ile dönüşümlü denenir
    if ($deneme -le 3 -or $deneme % 2 -eq 1) {
        $yontem = 'complete'
        $c = Lcu 'POST' "/lol-champ-select/v1/session/actions/$id/complete" $lcu $null 2000
    } else {
        $yontem = 'patch-completed'
        $c = Lcu 'PATCH' "/lol-champ-select/v1/session/actions/$id" $lcu "{`"championId`":$secilen,`"completed`":true}" 2000
    }
    Iz "$tur #$id kilit denemesi $deneme ($yontem): HTTP $($c.Kod), oturumdaki şampiyon $simdiki"
    if ($c.Kod -like '2*') { $sec.Onay[$id] = @{ Tur = $tur; Zaman = [DateTime]::Now; Yontem = $yontem } }
    else {
        $sec.Olmaz[$secilen] = $true
        Yaz (T "$ad kilitlenmedi ($(Lcu-Hata $c)), sıradakini deniyorum." "$ad wouldn't lock ($(Lcu-Hata $c)), trying the next one.") $RenkTuruncu
    }
}

# Sıran gelmeden önce pick niyetini gösterir; sen değiştirirsen dokunmaz, seçtiğin banlanırsa sıradakine geçer
function Oto-Niyet($lcu, $a, $b) {
    $id = [int]$a.id
    $sec = $script:Secim
    if ($sec.NiyetOlmaz[$id]) { return }
    $simdiki = [int]$a.championId
    if ($simdiki -gt 0 -and $simdiki -ne $sec.Hover) { return }
    $hedef = Aday-Sec $b.Pick $b.Alinan @{} $sec.Secilebilir
    if (-not $hedef -or $hedef -eq $simdiki) { return }
    $y = Lcu 'PATCH' "/lol-champ-select/v1/session/actions/$id" $lcu "{`"championId`":$hedef}" 2000
    if ($y.Kod -like '2*') {
        $sec.Hover = $hedef
        $ad = Sampiyon-Adi $hedef
        $sonra = if ($Ayar.kilitle) { T 'sıran gelince kilitlerim' "I'll lock it in on your turn" } else { T 'sıran gelince üzerine gelirim' "I'll hover it on your turn" }
        Yaz (T "Niyet olarak $ad gösterildi; $sonra." "Showing $ad as your intent; $sonra.") $RenkSoluk
    } else { $sec.NiyetOlmaz[$id] = $true }   # bu aşamada niyet kabul edilmiyor; sırayı bekler
}

# ---- Ping ----
$script:PingGecmis = New-Object 'Collections.Generic.List[int]'   # son 120 sn, -1 = kayıp
$script:PingGorev  = $null
$script:ModemGorev = $null
$script:ModemMs    = $null
$script:OyunPing   = $null
$script:Netlog     = $null
$script:Modem      = $null   # açık ağ bağdaştırıcısının IPv4 ağ geçidi
try {
    $script:Modem = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.OperationalStatus -eq 'Up' } |
        ForEach-Object { $_.GetIPProperties().GatewayAddresses } | ForEach-Object { $_.Address } |
        Where-Object { $_.AddressFamily -eq 'InterNetwork' -and "$_" -ne '0.0.0.0' } |
        Select-Object -First 1 | ForEach-Object { "$_" }
} catch {}
$Ping1 = New-Object Net.NetworkInformation.Ping
$Ping2 = New-Object Net.NetworkInformation.Ping

function Ping-Sonuc($gorev) {
    try { $r = $gorev.Result; if ($r.Status -eq 'Success') { return [int]$r.RoundtripTime } } catch {}
    return -1
}

function Ping-Renk($ms) {
    if ($ms -lt 0) { $RenkKirmizi } elseif ($ms -lt $PingUyari) { $RenkYazi } elseif ($ms -lt $PingKotu) { $RenkTuruncu } else { $RenkKirmizi }
}

# Maçtayken oyunun kendi ölçtüğü ping: GameLogs\<maç>\..._netlog.txt, 10 sn'de bir satır
function Oyun-Ping-Oku {
    $oyun = Surec 'League of Legends'
    if (-not $oyun) { $script:OyunPing = $null; $script:Netlog = $null; return }
    if (-not $script:Netlog) {
        $d = Get-ChildItem $GameLogs -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $d) { return }
        $f = Get-ChildItem $d.FullName -Filter '*_netlog.txt' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $f -or $f.CreationTime -lt $oyun.StartTime.AddMinutes(-2)) { return }
        $script:Netlog = @{ Yol = $f.FullName; Boy = -1; Zaman = [DateTime]::Now }
    }
    $n = $script:Netlog
    try {
        $fs = [IO.File]::Open($n.Yol, 'Open', 'Read', 'ReadWrite')
        $boy = $fs.Length
        $oku = [int][Math]::Min(4096, $boy)
        [void]$fs.Seek(-$oku, 'End')
        $buf = New-Object byte[] $oku
        [void]$fs.Read($buf, 0, $oku)
        $fs.Close()
    } catch { return }
    if ($boy -ne $n.Boy) { $n.Boy = $boy; $n.Zaman = [DateTime]::Now }
    if (([DateTime]::Now - $n.Zaman).TotalSeconds -gt 30) { $script:OyunPing = $null; return }   # yazılmıyorsa eski veri gösterme
    $satir = [Text.Encoding]::ASCII.GetString($buf) -split "`n" | Where-Object { $_ -match '^\d+,' } | Select-Object -Last 1
    if (-not $satir) { return }
    $p = $satir.Trim().Split(',')
    if ($p.Count -lt 17) { return }
    $script:OyunPing = @{ Ms = [int]$p[8]; Kayip = [double]$p[15] }
}

function Ping-Tick {
    if ($script:PingGorev -and $script:PingGorev.IsCompleted) {
        $script:PingGecmis.Add((Ping-Sonuc $script:PingGorev))
        if ($script:PingGecmis.Count -gt 120) { $script:PingGecmis.RemoveAt(0) }
        $script:PingGorev = $null
    }
    if (-not $script:PingGorev) { try { $script:PingGorev = $Ping1.SendPingAsync($InternetHedef, 1000) } catch {} }
    if ($script:Modem) {
        if ($script:ModemGorev -and $script:ModemGorev.IsCompleted) { $script:ModemMs = Ping-Sonuc $script:ModemGorev; $script:ModemGorev = $null }
        if (-not $script:ModemGorev) { try { $script:ModemGorev = $Ping2.SendPingAsync($script:Modem, 1000) } catch {} }
    }
    if ($script:Tik % 5 -eq 0) { Oyun-Ping-Oku }
}

# Durum cümlesinin ping kısmı: @(öncesi, değer, renk, sonrası)
function Ping-Ozet {
    if ($script:OyunPing) {
        $o = $script:OyunPing
        $k = [Math]::Round($o.Kayip, 1)
        return @((T 'Oyun pingi ' 'Game ping '), "$($o.Ms) ms", (Ping-Renk $o.Ms), $(if ($k -gt 0) { T ", kayıp %$k." ", $k% loss." } else { '.' }))
    }
    $g = $script:PingGecmis
    if (-not $g.Count) { return $null }
    $son = $g[$g.Count - 1]
    if ($son -lt 0) {
        $modem = if ($null -ne $script:ModemMs -and $script:ModemMs -lt 0) { T ' Modeme de ulaşılamıyor.' " The router isn't answering either." } else { '' }
        return @((T 'İnternet ' 'Internet '), (T 'kopuk' 'down'), $RenkKirmizi, ".$modem")
    }
    $pencere = @($g | Select-Object -Last 60)
    $kayip = [Math]::Round(100 * @($pencere | Where-Object { $_ -lt 0 }).Count / $pencere.Count)
    $deger = if ($son -lt 1) { '<1 ms' } else { "$son ms" }
    return @('Ping ', $deger, (Ping-Renk $son), $(if ($kayip -gt 0) { T ", son dakikada kayıp %$kayip." ", $kayip% loss in the last minute." } else { T ', kayıp yok.' ', no loss.' }))
}

# ---- Custom skinler (LTK Manager) ----
# Modları oyuna LTK Manager'ın patcher'ı yükler; Riot Plus kendisi oyuna hiçbir şey enjekte etmez.
# Seçim değişince: LTK durdurulur, etkin profilin enabledMods listesi library.json'a yazılır (ilk yazımda yedek alınır),
# LTK tepside yeniden açılır ve kendi "patcher'ı her açılışta başlat" ayarıyla oyuna hazır bekler.
# LTK'nın skinhack kontrolüne takılan modlar (sahip olunmayan ücretli skin içeriği) listelenmez; LTK da açılışta kapatır.
$script:Json = New-Object Web.Script.Serialization.JavaScriptSerializer
$script:Json.MaxJsonLength = [int]::MaxValue
$script:LtkKutuphane = $null       # @{ Profil; Modlar }  (Ltk-Oku)
$script:LtkDamga = ''              # library.json + sağlık dosyasının yazılma zamanı; değişince yeniden okunur
$script:LtkYenilendi = $false      # son Ltk-Oku yeniden okudu mu
$script:LtkSampiyonBellek = @{}    # mod kimliği|sha -> şampiyon kimlikleri
$script:LtkYedeklendi = $false
$script:LtkSon = $null             # GitHub'daki son sürüm: @{ Surum; Url; Sha }
$script:LtkSurumGorevi = $null
$script:LtkDurum = @{ Acik = $false; Patcher = $false }
$script:LtkOtoZaman = [DateTime]::MinValue
$script:CustomIstek = $null        # @{ '<şampiyon kimliği>' = modId ('' = klasik); 'diger:<modId>' = $true/$false }
$script:EklenecekDosyalar = @()
$script:KodId = $null
$script:AcIstek = $null              # Lol-Kipli-Ac'ın açacağı kip ('ltk' | 'rose' | 'duz')
$script:KaynakIstek = $null          # Kaynak-Degistir'in geçeceği kaynak ('ltk' | 'rose')
$script:RoseDurum = @{ Kurulu = $false; Acik = $false }   # Rose-Durum-Oku doldurur

# ---- Rose (custom'ın ikinci kaynağı) ----
# Rose yönetici olarak çalışır; Riot Plus yönetici değildir. Bu yüzden başlatma ya Rose'un kendi zamanlanmış görevinden
# (Rose ayarlarındaki "Windows ile başlat" açıksa var; izin sormaz) ya da yönetici izniyle olur. Dışarıdan nazik kapatma yolu
# yok (tepsi menüsündeki Quit dışında); Rose-Durdur süreci yönetici izniyle sonlandırır ve Pengu kancasını kaldırır.
function Rose-Kipi { "$($Ayar.customKaynak)" -eq 'rose' }
function Rose-Kurulu { Test-Path -LiteralPath $RoseExe }
function Rose-Acik { [bool](Surec 'Rose') }
function Rose-Surum { try { "$((Get-Item -LiteralPath $RoseExe).VersionInfo.ProductVersion)".Trim() } catch { '' } }
function Rose-Gorev-Var {
    try { return ((Start-Process -FilePath 'schtasks.exe' -ArgumentList '/Query', '/TN', 'Rose' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop).ExitCode -eq 0) } catch { return $false }
}
# Seçim ya da maç sürerken Rose'a dokunulmaz: oyunu patcher için bekletiyor olabilir, LTK'sı açıktır
function Rose-Mesgul-Faz { (Oyun-Acik) -or (@('ChampSelect', 'GameStart', 'InProgress', 'Reconnect') -contains $script:SonFaz) }
function Rose-Bekle {
    $son = [DateTime]::Now.AddSeconds($RoseAcilisSn)
    while ([DateTime]::Now -lt $son) { if (Rose-Acik) { return $true }; Bekle 0.5 }
    return (Rose-Acik)
}
function Rose-Baslat {
    if ($Deneme) { Yaz 'deneme: Rose başlatılmadı' $RenkSoluk; return $false }
    $acildi = $false
    if (Rose-Gorev-Var) {
        try { [void](Start-Process -FilePath 'schtasks.exe' -ArgumentList '/Run', '/TN', 'Rose' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop) } catch {}
        $son = [DateTime]::Now.AddSeconds(6)
        while ([DateTime]::Now -lt $son -and -not (Rose-Acik)) { Bekle 0.5 }
        $acildi = Rose-Acik
    }
    if (-not $acildi) {
        Yaz (T 'Rose yönetici olarak çalışır; Windows izin soracak.' 'Rose runs as administrator; Windows will ask for permission.') $RenkSoluk
        try { Start-Process -FilePath $RoseExe -WorkingDirectory (Split-Path -Parent $RoseExe) -Verb RunAs -ErrorAction Stop }
        catch { Yaz (T 'Yönetici izni verilmedi; Rose başlatılmadı.' 'No admin rights given; Rose was not started.') $RenkTuruncu; return $false }
        $acildi = Rose-Bekle
    }
    if ($acildi) { Yaz (T "Rose çalışıyor. LoL açıksa eklentileri yüklemek için client'ı bir kez yeniden başlatır; skinini şampiyon seçiminde LoL'ün içinden seç." "Rose is running. If LoL is open it restarts the client once to load its plugins; pick your skin in champ select, inside LoL.") $RenkYesil }
    else { Yaz (T 'Rose açılmadı; kendi penceresinde ya da günlüğünde sebebi yazar.' "Rose didn't start; its own window or log says why.") $RenkTuruncu }
    return $acildi
}
# Rose, client'a eklentilerini Pengu Loader ile yükler: LeagueClientUx.exe için kayıt defterinde bir "Debugger" kancası.
# Rose düzgün kapanınca kaldırır; sonlandırılır ya da çökerse kalır ve sonraki client açılışında eklentiler yine yüklenir.
$PenguAnahtar = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LeagueClientUx.exe'
function Pengu-Kancasi {
    try {
        $kok = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $kok.OpenSubKey($PenguAnahtar)
            if (-not $k) { return $false }
            try { return ("$($k.GetValue('Debugger'))" -match 'rundll32.*core\.dll') } finally { $k.Dispose() }
        } finally { $kok.Dispose() }
    } catch { return $false }
}
# Rose'u kapatır ve client'ta izini bırakmaz: süreç + Rose'un açtığı LTK sonlandırılır, Pengu kancası kaldırılır.
# Rose kapalı ve kanca da yoksa bir şey yapmaz. $true = Rose kapalı ve kanca yok.
function Rose-Durdur {
    if ($Deneme) { return $true }
    $acik = Rose-Acik; $kanca = Pengu-Kancasi
    if (-not $acik -and -not $kanca) { return $true }
    if (Rose-Mesgul-Faz) { Yaz (T 'Seçimde ya da maçtayken Rose durdurulmaz; maç bitince dene.' "Rose can't be stopped during champ select or a game; try after.") $RenkTuruncu; return $false }
    # Tek yönetici izniyle (Rose da açtığı LTK da yönetici olarak çalışır; kanca HKLM'de)
    $komut = 'taskkill /F /IM Rose.exe & taskkill /F /IM ltk-manager.exe & taskkill /F /IM ltk_patcher_host.exe'
    $pengu = Join-Path (Split-Path -Parent $RoseExe) '_internal\Pengu Loader\Pengu Loader.exe'
    if (Test-Path -LiteralPath $pengu) { $komut += " & `"$pengu`" --uninstall --silent" }
    if ($kanca) { $komut += " & reg delete `"HKLM\$PenguAnahtar`" /v Debugger /f /reg:64" }
    Yaz $(if ($acik) { T 'Rose yönetici olarak çalışıyor; kapatmak için Windows izin soracak.' 'Rose runs as administrator; Windows will ask for permission to close it.' }
          else { T "Rose kapalı ama client'taki eklenti kancası kalmış; kaldırmak için Windows izin soracak." "Rose is closed but its plugin hook is still on the client; Windows will ask for permission to remove it." }) $RenkSoluk
    try { $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/s /c `"$komut`"" -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop }
    catch { Yaz (T "Yönetici izni verilmedi; Rose'a dokunamadım. Tepsideki Rose simgesinden Quit de diyebilirsin." "No admin rights given; Rose was left as it is. You can also Quit from Rose's tray icon.") $RenkTuruncu; return $false }
    $son = [DateTime]::Now.AddSeconds(25)
    while ([DateTime]::Now -lt $son -and -not $p.HasExited) { Bekle 0.3 }
    $son = [DateTime]::Now.AddSeconds(5)
    while ([DateTime]::Now -lt $son -and (Rose-Acik)) { Bekle 0.3 }
    if (Rose-Acik) { Yaz (T 'Rose kapanmadı; tepsideki Rose simgesinden Quit de.' "Rose didn't close; use Quit on Rose's tray icon.") $RenkTuruncu; return $false }
    if (Pengu-Kancasi) { Yaz (T "Rose kapandı ama client'taki eklenti kancası kalkmadı; Rose'u bir kez açıp tepsiden Quit ile kapat." "Rose closed but its plugin hook is still on the client; open Rose once and Quit it from the tray.") $RenkTuruncu; return $false }
    # Açık bir client eklentileri çoktan yüklemiştir; kanca kalksa da client yeniden başlayana dek içinde kalırlar
    if (Surec 'LeagueClientUx') { Yaz (T "LoL açık: Rose'un eklentileri client kapanana kadar içinde kalır. Hesap değiştireceksen 'Hepsini kapat'la kapatıp yeniden aç." "LoL is open: Rose's plugins stay in the client until it closes. If you're switching accounts, use 'Close everything' and reopen.") $RenkTuruncu }
    return $true
}
# Rose'un LTK kütüphanesine kendi koyduğu girdiler (oyun için kurduğu ve sonraki maça sakladığı skinler). LTK kipinde
# listede gösterilmez: bunlar Rose'un işi, senin eklediğin modlar değil.
function Rose-Girdileri {
    $k = @{}
    try {
        $j = Json-Oku (Join-Path $RoseVeri 'injection\ltf_installed.json')
        foreach ($ad in 'installed', 'kept') { if ($j[$ad]) { foreach ($id in @($j[$ad].Keys)) { $k["$id"] = $true } } }
    } catch {}
    return $k
}
# Rose kipinde custom'ı açar: Riot Plus'ın açtığı LTK kapatılır (Rose açık LTK görürse o maçta skin yüklemeyi atlar), Rose başlatılır
function Rose-Uygula([switch]$Hazirlik) {
    $script:CustomIstek = $null
    if (-not (Rose-Kurulu)) { Yaz (T 'Rose kurulu değil; Custom skinler sayfasından indirebilirsin.' 'Rose is not installed; get it from the Custom skins page.') $RenkTuruncu; Custom-Yenile; return }
    if (-not (Ltk-Kurulu)) { Yaz (T "Rose skinleri LTK Manager üzerinden uygular; önce LTK kurulmalı (kaynağı LTK'ya alıp kurabilirsin)." 'Rose applies skins through LTK Manager; install LTK first (switch the source to LTK to install it).') $RenkTuruncu; Custom-Yenile; return }
    if (Rose-Acik) { if (-not $Hazirlik) { Yaz (T 'Rose zaten çalışıyor.' 'Rose is already running.') $RenkSoluk }; Custom-Yenile; return }
    # Riot Plus açılırken Rose kendiliğinden başlatılmaz: hangi hesapla gireceğin belli değil. Rose yalnız sen isteyince açılır.
    if ($Hazirlik) { Yaz (T "Kaynak Rose ama Rose çalışmıyor. Açmak için: LoL'ü aç > Rose ile aç." "Source is Rose but Rose isn't running. To start: Open LoL > Open with Rose.") $RenkSoluk; Custom-Yenile; return }
    if (Rose-Mesgul-Faz) { Yaz (T 'Seçimde ya da maçtayken Rose başlatılmaz; maç bitince dene.' "Rose isn't started during champ select or a game; try after.") $RenkTuruncu; Custom-Yenile; return }
    if (Ltk-Acik) {
        Ltk-Durdur
        if (Ltk-Acik) { Yaz (T "LTK Manager kapanmadı; açık kalırsa Rose skin yüklemez. Tepsiden LTK'yı kapat." "LTK Manager didn't close; Rose won't load skins while it's open. Close LTK from the tray.") $RenkTuruncu }
    }
    [void](Rose-Baslat)
    Custom-Yenile
}
# Kaynağı değiştirir. İki kaynak aynı LTK'yı kullandığı için biri kapanmadan öteki açılmaz.
function Kaynak-Degistir {
    $yeni = "$($script:KaynakIstek)"; $script:KaynakIstek = $null
    if ($yeni -ne 'rose') { $yeni = 'ltk' }
    if ($yeni -eq "$($Ayar.customKaynak)") { Custom-Yenile; return }
    if (Rose-Mesgul-Faz) { Yaz (T 'Seçimde ya da maçtayken kaynak değişmez; maç bitince değiştir.' "Can't switch the source during champ select or a game.") $RenkTuruncu; Custom-Yenile; return }
    if ($yeni -eq 'ltk') {
        if (-not (Rose-Durdur)) { Custom-Yenile; return }
        $Ayar.customKaynak = 'ltk'; Ayar-Kaydet
        $script:LtkBilinenAcik = $null; $script:CustomMacSon = 0
        Yaz (T "Kaynak: LTK Manager. Custom'ları yine Riot Plus yönetiyor." 'Source: LTK Manager. Riot Plus manages your customs again.') $RenkSoluk
        if ($Ayar.custom -and (Ltk-Kurulu)) { $script:CustomIstek = $null; Custom-Uygula } else { Custom-Yenile }
    } else {
        $Ayar.customKaynak = 'rose'; Ayar-Kaydet
        $script:PatcherBekle = $null
        Yaz (T "Kaynak: Rose. Bu kipte Riot Plus LTK'ya dokunmaz; skinler Rose'dan gelir." "Source: Rose. Riot Plus leaves LTK alone in this mode; skins come from Rose.") $RenkSoluk
        if ($Ayar.custom) { Rose-Uygula }
        else { if (Ltk-Acik) { Ltk-Durdur }; Custom-Yenile }
    }
}

# "LoL'ü aç" seçenekleri (LoL kapalıyken): 'ltk' = kendi modlarınla, 'rose' = Rose ile, 'duz' = hiçbir şey yüklenmeden.
# Her biri önce ötekini kapatır, sonra LoL'ü açar. Düz ve LTK açılışında Rose kapalı ve eklenti kancası kalkmış olmalı;
# olmazsa LoL açılmaz (ana hesapta yanlışlıkla Rose'la girmeyesin diye).
function Ac-Kipi { if (-not $Ayar.custom) { 'duz' } elseif (Rose-Kipi) { 'rose' } else { 'ltk' } }
function Lol-Kapali { (-not $Deneme) -and -not @(Get-Process -Name 'LeagueClient', 'LeagueClientUx', 'League of Legends' -ErrorAction SilentlyContinue).Count }
function Lol-Kipli-Ac {
    $kip = "$($script:AcIstek)"; $script:AcIstek = $null
    if (-not (Lol-Kapali)) { Lol-Ac; return }
    switch ($kip) {
        'rose' {
            if (-not (Rose-Kurulu)) { Yaz (T 'Rose kurulu değil; Custom skinler sayfasından indirebilirsin.' 'Rose is not installed; get it from the Custom skins page.') $RenkTuruncu; return }
            if (-not (Ltk-Kurulu)) { Yaz (T 'Rose skinleri LTK Manager üzerinden uygular; önce LTK kurulmalı.' 'Rose applies skins through LTK Manager; install LTK first.') $RenkTuruncu; return }
            $Ayar.customKaynak = 'rose'; $Ayar.custom = $true; Ayar-Kaydet
            $script:PatcherBekle = $null
            Rose-Uygula
            if (-not (Rose-Acik)) { Yaz (T "Rose açılmadı; LoL'ü açmadım." "Rose didn't start; LoL was not opened.") $RenkTuruncu; return }
        }
        'ltk' {
            if (-not (Ltk-Kurulu)) { Yaz (T 'LTK Manager kurulu değil; Custom skinler sayfasından kurabilirsin.' 'LTK Manager is not installed; install it from Custom skins.') $RenkTuruncu; return }
            if (-not (Rose-Durdur)) { Yaz (T "Rose tam kapanmadan LoL'ü açmıyorum." "Not opening LoL until Rose is fully closed.") $RenkTuruncu; Custom-Yenile; return }
            $Ayar.customKaynak = 'ltk'; $Ayar.custom = $true; Ayar-Kaydet
            $script:LtkBilinenAcik = $null; $script:CustomMacSon = 0; $script:CustomIstek = $null
            Custom-Uygula
        }
        default {
            if (-not (Rose-Durdur)) { Yaz (T "Rose tam kapanmadan LoL'ü açmıyorum." "Not opening LoL until Rose is fully closed.") $RenkTuruncu; Custom-Yenile; return }
            if ($Ayar.custom) { $Ayar.custom = $false; Ayar-Kaydet }
            Ltk-Durdur
            if ((Ltk-Acik) -or (Ltk-Patcher)) { Yaz (T "LTK Manager kapanmadı; LoL'ü açmadım. Tepsiden LTK'yı kapatıp yeniden dene." "LTK Manager didn't close; LoL was not opened. Close LTK from the tray and try again.") $RenkTuruncu; Custom-Yenile; return }
            Yaz (T 'Düz açıyorum: Rose ve LTK kapalı, oyuna hiçbir şey yüklenmiyor.' 'Opening plain: Rose and LTK are closed; nothing is loaded into the game.') $RenkSoluk
        }
    }
    Custom-Yenile
    Lol-Ac
}

# LTK'daki modları Rose'un custom skin klasörüne kopyalar; Rose'da o şampiyonun ilgili skininin üstünde seçilebilir olurlar.
# Rose'un düzeni: %LOCALAPPDATA%\Rose\mods\skins\<şampiyon kimliği>000\<ad>.fantome + rose_mod_targets.json
# (mods.<ad> = { name, targets = skin kimlikleri, ... }). Daha önce aktarılan (riotPlusLtkId) yeniden kopyalanmaz.
function Rose-Dosya-Adi([string]$ad) {
    $t = ($ad -replace '[\\/:*?"<>|\x00-\x1f]', ' ' -replace '\s+', ' ').Trim().Trim('.').Trim()
    if (-not $t) { $t = 'mod' }
    if ($t.Length -gt 80) { $t = $t.Substring(0, 80).Trim() }
    return $t
}
function Rose-Aktar {
    if (-not (Rose-Kurulu)) { Yaz (T 'Rose kurulu değil.' 'Rose is not installed.') $RenkTuruncu; return }
    if (Rose-Mesgul-Faz) { Yaz (T 'Seçimde ya da maçtayken aktarılmaz; maç bitince dene.' 'Not during champ select or a game; try after.') $RenkTuruncu; return }
    try { Ltk-Oku -Zorla } catch {}
    if (-not $script:LtkKutuphane -or -not $script:LtkKutuphane.Modlar.Count) { Yaz (T "LTK'da aktarılacak mod yok." 'No mods in LTK to copy.') $RenkSoluk; return }
    if ($Deneme) { Yaz "deneme: $($script:LtkKutuphane.Modlar.Count) mod Rose'a aktarılmadı" $RenkSoluk; return }
    $kok = Join-Path $RoseVeri 'mods\skins'; $ltkMod = Join-Path $LtkVeri 'mods'
    $eklendi = @(); $vardi = 0; $paket = @(); $sampiyonsuz = 0; $hata = @()
    foreach ($m in @($script:LtkKutuphane.Modlar)) {
        if ($m.Engelli) { continue }
        if (-not $m.Ana) { $sampiyonsuz++; continue }
        if ($m.Bicim -ne 'fantome') { $paket += $m.Ad; continue }
        $kaynak = Join-Path $ltkMod "$($m.Slug).fantome"
        $gecici = $null
        try {
            if (-not (Test-Path -LiteralPath $kaynak)) { throw 'dosya yok' }
            $klasor = Join-Path $kok "$([int]$m.Ana * 1000)"
            [void](New-Item -ItemType Directory -Force $klasor)
            $manYol = Join-Path $klasor 'rose_mod_targets.json'
            # Okunamayan manifestin üstüne yazılmaz (Rose'un oradaki modları kaybolurdu); hata sayılır
            $man = if (Test-Path -LiteralPath $manYol) { Json-Oku $manYol } else { $null }
            if (-not ($man -is [Collections.IDictionary])) { $man = New-Object 'Collections.Generic.Dictionary[string,object]' }
            $modlar = $man['mods']
            if (-not ($modlar -is [Collections.IDictionary])) { $modlar = New-Object 'Collections.Generic.Dictionary[string,object]'; $man['mods'] = $modlar }
            $var = $false
            foreach ($k in @($modlar.Keys)) {
                $g = $modlar[$k]
                if (($g -is [Collections.IDictionary]) -and "$($g['riotPlusLtkId'])" -eq $m.Id) {
                    $gAd = if ("$($g['name'])") { "$($g['name'])" } else { "$k" }
                    if (Test-Path -LiteralPath (Join-Path $klasor "$gAd.fantome")) { $var = $true } else { [void]$modlar.Remove($k) }
                }
            }
            if ($var) { $vardi++; continue }
            $taban = Rose-Dosya-Adi $m.Ad; $ad = $taban; $n = 2
            while ($modlar.ContainsKey($ad) -or (Test-Path -LiteralPath (Join-Path $klasor "$ad.fantome"))) { $ad = "$taban ($n)"; $n++ }
            $hedef = Join-Path $klasor "$ad.fantome"
            $gecici = Join-Path $klasor ".riotplus-$([Guid]::NewGuid().ToString('N')).tmp"   # noktayla başlayanı Rose mod saymaz
            Copy-Item -LiteralPath $kaynak -Destination $gecici -Force
            # Rose, META/info.json'ı olan arşivi olduğu gibi alır; yoksa eklenir
            $z = [IO.Compression.ZipFile]::Open($gecici, [IO.Compression.ZipArchiveMode]::Update)
            try {
                if (-not @($z.Entries | Where-Object { $_.FullName.Replace('\', '/').TrimStart('/') -ieq 'META/info.json' }).Count) {
                    $e = $z.CreateEntry('META/info.json')
                    $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding($false)))
                    try { $w.Write($script:Json.Serialize(@{ Name = $m.Ad; Author = 'Unknown'; Version = '1.0.0'; Description = '' })) } finally { $w.Dispose() }
                }
            } finally { $z.Dispose() }
            $ozet = (Get-FileHash -LiteralPath $gecici -Algorithm SHA256).Hash.ToLowerInvariant()
            Move-Item -LiteralPath $gecici -Destination $hedef -Force; $gecici = $null
            # Hedef skinler: modun yazdığı skin numaraları (okunamadıysa klasik); skin kimliği = şampiyon * 1000 + numara
            $numaralar = @($m.Skinler | Where-Object { $null -ne $_ }); if (-not $numaralar.Count) { $numaralar = @(0) }
            $girdi = New-Object 'Collections.Generic.Dictionary[string,object]'
            $girdi['name'] = $ad
            $girdi['displayName'] = $m.Ad
            $girdi['targets'] = [object[]]@($numaralar | ForEach-Object { [int]$m.Ana * 1000 + [int]$_ })
            $girdi['updatedAt'] = [Math]::Round(([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds, 3)
            $girdi['sourceHash'] = $ozet
            $girdi['riotPlusLtkId'] = $m.Id
            $modlar[$ad] = $girdi
            $man['version'] = 1
            if (-not $man.ContainsKey('championId')) { $man['championId'] = [int]$m.Ana }
            if (-not $man.ContainsKey('targets')) { $man['targets'] = [object[]]@() }
            Json-Yaz $manYol $man
            try { [void][ModWad]::GorselCikar($kaynak, (Join-Path $klasor "$ad.png")) } catch {}   # Rose'un menüsündeki önizleme
            $eklendi += "$($m.Ad) ($(Sampiyon-Adi $m.Ana))"
        } catch {
            $hata += "$($m.Ad): $($_.Exception.Message)"
            if ($gecici) { Remove-Item -LiteralPath $gecici -Force -ErrorAction SilentlyContinue }
        }
    }
    if ($eklendi.Count) { Yaz ((T "Rose'a aktarıldı ($($eklendi.Count)): " "Copied to Rose ($($eklendi.Count)): ") + ($eklendi -join ', ')) $RenkYesil }
    elseif (-not $hata.Count) { Yaz (T "Rose'a aktarılacak yeni mod yok." 'Nothing new to copy to Rose.') $RenkSoluk }
    $notlar = @()
    if ($vardi) { $notlar += T "$vardi mod zaten aktarılmıştı" "$vardi already copied" }
    if ($paket.Count) { $notlar += T "$($paket.Count) mod .modpkg biçiminde, onu Rose'un kendi menüsünden ekle ($($paket -join ', '))" "$($paket.Count) are .modpkg, add those from Rose's own menu ($($paket -join ', '))" }
    if ($sampiyonsuz) { $notlar += T "$sampiyonsuz mod şampiyona bağlı değil, atlandı" "$sampiyonsuz aren't tied to a champion, skipped" }
    if ($notlar.Count) { Yaz (($notlar -join '; ') + '.') $RenkSoluk }
    if ($hata.Count) { Yaz ((T 'Aktarılamadı: ' "Couldn't copy: ") + ($hata -join '; ')) $RenkTuruncu }
    if ($eklendi.Count) { Yaz (T "Rose'da: şampiyon seçiminde modun yazdığı skinin üstüne gel, custom menüsünden seç." "In Rose: hover the skin the mod targets in champ select and pick it from the custom menu.") $RenkSoluk }
}

function Rose-Durum-Oku { $script:RoseDurum = @{ Kurulu = (Rose-Kurulu); Acik = (Rose-Acik) } }

function Ltk-Kurulu { Test-Path $LtkExe }
function Ltk-Surum { try { [version]((Get-Item $LtkExe).VersionInfo.FileVersion) } catch { $null } }
function Ltk-Acik { [bool](Surec 'ltk-manager') }
function Ltk-Patcher { [bool](Surec 'ltk_patcher_host') }
function Oyun-Acik { (-not $Deneme) -and [bool](Surec 'League of Legends') }
function Json-Oku($yol) { $script:Json.DeserializeObject([IO.File]::ReadAllText($yol)) }
function Json-Yaz($yol, $nesne) {
    $gecici = "$yol.riotplus-gecici"
    [IO.File]::WriteAllText($gecici, $script:Json.Serialize($nesne), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $gecici -Destination $yol -Force
}

# LTK'daki şampiyon adı (Data Dragon kodu: Talon, Kaisa, yone) -> şampiyon kimliği; büyük/küçük harf fark etmez
function Kod-Id($kod) {
    if (-not $script:KodId) { $script:KodId = @{}; foreach ($id in $script:SampiyonKod.Keys) { $script:KodId["$($script:SampiyonKod[$id])"] = [int]$id } }
    return [int]$script:KodId["$kod"]
}

# Modun şampiyonları: mod.config.json'daki "champions", yoksa arşivdeki WAD adları (WAD/Shen.wad.client, WAD/Thresh.tr_TR.wad.client)
function Mod-Sampiyonlari($m, $klasor) {
    $anahtar = "$($m.Id)|$($m.Sha)"
    if ($script:LtkSampiyonBellek.ContainsKey($anahtar)) { return ,$script:LtkSampiyonBellek[$anahtar] }
    $ids = New-Object 'Collections.Generic.List[int]'
    foreach ($c in @($m.Ayar.champions)) { if ($c) { $id = Kod-Id $c; if ($id -and -not $ids.Contains($id)) { $ids.Add($id) } } }
    if (-not $ids.Count -and $m.Bicim -eq 'fantome') {
        try {
            $z = [IO.Compression.ZipFile]::OpenRead((Join-Path $klasor "$($m.Slug).fantome"))
            try {
                foreach ($e in $z.Entries) {
                    if ($e.FullName -match '^WAD/([^./]+)[^/]*\.wad\.client(/|$)') { $id = Kod-Id $Matches[1]; if ($id -and -not $ids.Contains($id)) { $ids.Add($id) } }
                }
            } finally { $z.Dispose() }
        } catch {}
    }
    $sonuc = [int[]]$ids.ToArray()
    $script:LtkSampiyonBellek[$anahtar] = $sonuc
    return ,$sonuc
}

# LTK kütüphanesini okur (dosyalar değişmediyse eskisini tutar)
function Ltk-Oku([switch]$Zorla) {
    $script:LtkYenilendi = $false
    $lib = Join-Path $LtkVeri 'library.json'; $sag = Join-Path $LtkVeri 'mod-health-verdicts.json'; $rap = Join-Path $LtkVeri 'wad-reports.json'
    if (-not (Test-Path $lib)) { if ($script:LtkKutuphane) { $script:LtkYenilendi = $true }; $script:LtkKutuphane = $null; $script:LtkDamga = ''; return }
    $damga = "$((Get-Item $lib).LastWriteTimeUtc.Ticks)|$(if (Test-Path $sag) { (Get-Item $sag).LastWriteTimeUtc.Ticks })|$(if (Test-Path $rap) { (Get-Item $rap).LastWriteTimeUtc.Ticks })"
    if (-not $Zorla -and $script:LtkKutuphane -and $damga -eq $script:LtkDamga) { return }
    $j = Json-Oku $lib
    $saglik = $null; try { $saglik = (Json-Oku $sag)['verdicts'] } catch {}
    $rapor = $null; try { $rapor = (Json-Oku $rap)['reports'] } catch {}   # LTK'nın modun ana şampiyonu tahmini
    $profil = @($j['profiles']) | Where-Object { $_['id'] -eq $j['activeProfileId'] } | Select-Object -First 1
    $acik = @{}; if ($profil) { foreach ($id in @($profil['enabledMods'])) { $acik["$id"] = $true } }
    $klasor = Join-Path $LtkVeri 'mods'
    $modlar = New-Object Collections.ArrayList
    $rose = Rose-Girdileri
    foreach ($e in @($j['mods'])) {
        if (-not $e) { continue }
        if ($rose["$($e['id'])"]) { continue }   # Rose'un kendi koyduğu skin; listeye girmez
        $m = @{ Id = "$($e['id'])"; Slug = "$($e['slug'])"; Bicim = "$($e['format'])"; Sha = "$($e['sourceSha256'])"; Ayar = $null }
        try { $m.Ayar = [IO.File]::ReadAllText((Join-Path $klasor "$($m.Slug)\mod.config.json")) | ConvertFrom-Json } catch {}
        $m.Ad = if ($m.Ayar -and $m.Ayar.display_name) { "$($m.Ayar.display_name)" } else { $m.Slug }
        # Tamamı küçük harf adlar ("crystal rose kai'sa") başharfleri büyük gösterilir; Türkçe İ olmasın diye değişmez kültür
        if ($m.Ad -ceq $m.Ad.ToLowerInvariant()) { $m.Ad = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($m.Ad) }
        if ($Ayar.customAd -and $Ayar.customAd[$m.Id]) { $m.Ad = $Ayar.customAd[$m.Id] }   # Enes'in verdiği ad
        $m.Birincil = 0
        if ($rapor -and $rapor.ContainsKey($m.Id)) { try { $pc = $rapor[$m.Id]['derived']['primaryChampion']; if ($pc) { $m.Birincil = Kod-Id $pc } } catch {} }
        $v = if ($saglik -and $saglik.ContainsKey($m.Id)) { $saglik[$m.Id] } else { $null }
        $m.Engelli = [bool]($v -and ("$($v['health'])" -eq 'unrepairable' -or @(@($v['rules']) | Where-Object { $_ -and "$($_['rule'])" -eq 'bin/skinhack' -and "$($_['severity'])" -ne 'info' }).Count))
        $m.Acik = [bool]$acik[$m.Id]
        $m.Sampiyonlar = Mod-Sampiyonlari $m $klasor
        $m.Ana = if ($m.Birincil) { $m.Birincil } elseif ($m.Sampiyonlar.Count) { [int]$m.Sampiyonlar[0] } else { 0 }
        $m.Skinler = if ($m.Ana) { Mod-Skinleri $m $klasor $m.Ana } else { $null }   # 0 = klasik
        [void]$modlar.Add($m)
    }
    $script:LtkKutuphane = @{ Profil = $profil; Modlar = $modlar }
    $script:LtkDamga = $damga
    $script:LtkYenilendi = $true
    Custom-Disaridan-Esitle
}

# '<şampiyon kimliği>' -> o şampiyonun modları; şampiyonsuz modlar 'diger'. Skinhack sayılanlar yok.
function Custom-Gruplar {
    $g = @{}
    if (-not $script:LtkKutuphane) { return $g }
    foreach ($m in $script:LtkKutuphane.Modlar) {
        if ($m.Engelli) { continue }
        $k = if ($m.Ana) { "$($m.Ana)" } else { 'diger' }
        if (-not $g.ContainsKey($k)) { $g[$k] = New-Object Collections.ArrayList }
        [void]$g[$k].Add($m)
    }
    return $g
}
# LTK'da şu an açık olan mod (grubun içinden)
function Ltk-Acik-Mod($liste) { foreach ($m in @($liste)) { if ($m.Acik) { return $m } }; return $null }
function Grup-Anahtari($liste) { $ilk = @($liste)[0]; if ($ilk -and $ilk.Ana) { "$($ilk.Ana)" } else { 'diger' } }
# Bu şampiyon için seçtiğin mod. Kaynak Riot Plus'ın kendi kaydı (customSecim): "yalnız benim şampiyonum" kipinde LTK'da
# yalnız maçtaki şampiyonun modu açık durur, diğer seçimler orada görünmez ama kayıtta kalır. Kayıt yoksa LTK'da açık olan.
function Custom-Secili($liste) {
    $k = Grup-Anahtari $liste
    if ($k -ne 'diger' -and $Ayar.customSecim -and $Ayar.customSecim.ContainsKey($k)) {
        $id = "$($Ayar.customSecim[$k])"
        if (-not $id) { return $null }
        foreach ($m in @($liste)) { if ($m.Id -eq $id) { return $m } }
    }
    return Ltk-Acik-Mod $liste
}
# LTK'nın açık listesi bizim yazmadığımız biçimde değiştiyse (ilk okuma, LTK penceresinden seçim) seçim kaydına işlenir.
# Kendi yazdığımız liste (Ltk-Yaz) önceden "bilinen" sayılır; böylece daraltma kayıttaki seçimleri silmez.
$script:LtkBilinenAcik = $null
function Custom-Disaridan-Esitle {
    if (-not $script:LtkKutuphane) { return }
    # Rose her maç için LTK'daki açık modları kapatıp sonra geri açar; bu, seçim kaydına "sen kapattın" diye işlenmesin
    if ((Rose-Kipi) -or (Rose-Acik)) { $script:LtkBilinenAcik = $null; return }
    $profil = $script:LtkKutuphane.Profil
    $simdi = if ($profil) { @(@($profil['enabledMods']) | Where-Object { $_ } | ForEach-Object { "$_" }) } else { @() }
    if ($null -eq $Ayar.customSecim) { $Ayar.customSecim = @{} }
    $bilinen = $script:LtkBilinenAcik
    $script:LtkBilinenAcik = $simdi
    $degisti = $false
    foreach ($m in $script:LtkKutuphane.Modlar) {
        if ($m.Engelli -or -not $m.Ana) { continue }
        $k = "$($m.Ana)"
        if ($null -eq $bilinen) {
            # ilk okuma: kaydı olmayan şampiyona LTK'daki seçimi al, kayıtta olanı ezme
            if ($m.Acik -and -not $Ayar.customSecim.ContainsKey($k)) { $Ayar.customSecim[$k] = $m.Id; $degisti = $true }
        } elseif ($m.Acik -and $bilinen -notcontains $m.Id) {
            if ("$($Ayar.customSecim[$k])" -ne $m.Id) { $Ayar.customSecim[$k] = $m.Id; $degisti = $true }
        } elseif (-not $m.Acik -and $bilinen -contains $m.Id -and "$($Ayar.customSecim[$k])" -eq $m.Id) {
            # LTK'dan kapatıldı; aynı şampiyonda açık başka mod yoksa klasik
            if (-not @($script:LtkKutuphane.Modlar | Where-Object { $_.Acik -and "$($_.Ana)" -eq $k }).Count) { $Ayar.customSecim[$k] = ''; $degisti = $true }
        }
    }
    if ($degisti -and -not $Kare) { Ayar-Kaydet }
}
# Bu maçta oynadığın şampiyon: seçimde kilitlediğin (ARAM gibi pick sırası olmayan modda atanan), maçta son seçilen; yoksa 0
function Custom-Mac-Sampiyonu {
    $faz = $script:SonFaz
    $b = $script:SecimBilgi
    if ($faz -eq 'ChampSelect' -and $b -and [int]$b.Benim -gt 0 -and ($b.Kilitli -or -not $b.PickVar)) { return [int]$b.Benim }
    if (@('GameStart', 'InProgress', 'Reconnect') -contains $faz -and $script:SonSampiyon) { return [int]$script:SonSampiyon }
    return 0
}
function Custom-Engelli-Sayisi { if ($script:LtkKutuphane) { @($script:LtkKutuphane.Modlar | Where-Object { $_.Engelli }).Count } else { 0 } }
# Oyuncu custom açıkken bu şampiyonda seçili mod
function Custom-Secim($id) {
    if (-not $id -or -not $Ayar.custom -or (Rose-Kipi) -or -not (Ltk-Kurulu)) { return $null }
    $g = Custom-Gruplar
    if ($g.ContainsKey("$id")) { return Custom-Secili $g["$id"] }
    return $null
}

# Modun yazdığı skin numaraları (0 = klasik); arşivin içindekiler tablosundan, sha'ya göre dosyada önbellek
$script:ModSkinBellek = $null
function Mod-Skinleri($m, $klasor, $id) {
    if (@('fantome', 'modpkg') -notcontains $m.Bicim) { return $null }
    if ($null -eq $script:ModSkinBellek) {
        $script:ModSkinBellek = @{}
        try { $j = [IO.File]::ReadAllText($ModSkinDosyasi) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $script:ModSkinBellek[$p.Name] = [int[]]@($p.Value) } } catch {}
    }
    $kod = $script:SampiyonKod[[int]$id]
    if (-not $kod) { return $null }
    $anahtar = "$($m.Sha)|$kod"
    if ($script:ModSkinBellek.ContainsKey($anahtar)) { return ,$script:ModSkinBellek[$anahtar] }
    try {
        $arsiv = Join-Path $klasor "$($m.Slug).$($m.Bicim)"
        $r = if ($m.Bicim -eq 'modpkg') { [int[]]@([ModWad]::SkinNumaralariHam($arsiv, $kod)) } else { [int[]]@([ModWad]::SkinNumaralari($arsiv, $kod)) }
    } catch { return $null }
    $script:ModSkinBellek[$anahtar] = $r
    try { [void](New-Item -ItemType Directory -Force $CustomGorselKlasoru); [IO.File]::WriteAllText($ModSkinDosyasi, ($script:ModSkinBellek | ConvertTo-Json -Depth 3 -Compress), (New-Object Text.UTF8Encoding($false))) } catch {}
    return ,$r
}

# Skin adları: Data Dragon'ın şampiyon dosyasından (tr + en), arka planda iner, sampiyon-skinleri.json'da saklanır
$script:SkinAdlari = $null          # Kod -> @{ tr = @{ 'num' = ad }; en = ... }
$script:SkinAdGorevleri = @{}
function Skin-Adlari-Yukle {
    if ($null -ne $script:SkinAdlari) { return }
    $script:SkinAdlari = @{}
    try {
        $j = [IO.File]::ReadAllText($SkinAdDosyasi) | ConvertFrom-Json
        if ("$($j.surum)" -eq "$($script:DdSurum)") {
            foreach ($p in $j.skinler.PSObject.Properties) {
                $d = @{}
                foreach ($y in 'tr', 'en') { $h = @{}; if ($p.Value.$y) { foreach ($q in $p.Value.$y.PSObject.Properties) { $h[$q.Name] = "$($q.Value)" } }; $d[$y] = $h }
                $script:SkinAdlari[$p.Name] = $d
            }
        }
    } catch {}
}
function Skin-Adi($id, $num) {
    $kod = $script:SampiyonKod[[int]$id]
    if (-not $kod) { return "skin $num" }
    Skin-Adlari-Yukle
    $d = $script:SkinAdlari[$kod]
    $yer = if ($script:Dil -eq 'en') { 'en' } else { 'tr' }
    if ($d -and $d[$yer] -and $d[$yer]["$num"]) { return $d[$yer]["$num"] }
    if (-not $d) { Skin-Adi-Iste $kod }
    return "skin $num"
}
function Skin-Adi-Iste($kod) {
    if ($Sessiz -or -not $script:DdSurum) { return }
    foreach ($y in @(@('tr', 'tr_TR'), @('en', 'en_US'))) {
        $anahtar = "$kod|$($y[0])"
        if ($script:SkinAdGorevleri.ContainsKey($anahtar)) { continue }
        # Encoding şart: yoksa WebClient ANSI okur, "Cefakâr Kılıç" bozulur
        try { $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $script:SkinAdGorevleri[$anahtar] = $wc.DownloadStringTaskAsync("https://ddragon.leagueoflegends.com/cdn/$($script:DdSurum)/data/$($y[1])/champion/$kod.json") } catch { $script:SkinAdGorevleri[$anahtar] = $null }
    }
}
function Skin-Adi-Tick {
    $yeni = $false
    foreach ($anahtar in @($script:SkinAdGorevleri.Keys)) {
        $g = $script:SkinAdGorevleri[$anahtar]
        if (-not $g -or -not $g.IsCompleted) { continue }
        $script:SkinAdGorevleri[$anahtar] = $null   # başarısız olsa da yeniden istenmez
        if ($g.IsFaulted) { continue }
        $kod, $yer = $anahtar.Split('|')
        if (Skin-Adi-Isle $kod $yer $g.Result) { $yeni = $true }
    }
    if ($yeni) { Skin-Adlari-Kaydet; Custom-Yenile }
}
function Skin-Adi-Isle($kod, $yer, $metin) {
    try {
        $veri = ($metin | ConvertFrom-Json).data.$kod
        $h = @{}
        foreach ($s in @($veri.skins)) { $h["$([int]$s.num)"] = if ([int]$s.num -eq 0) { if ($yer -eq 'en') { 'Base skin' } else { 'Klasik' } } else { "$($s.name)" } }
        Skin-Adlari-Yukle
        if (-not $script:SkinAdlari[$kod]) { $script:SkinAdlari[$kod] = @{} }
        $script:SkinAdlari[$kod][$yer] = $h
        return $true
    } catch { return $false }
}
function Skin-Adlari-Kaydet {
    try { [IO.File]::WriteAllText($SkinAdDosyasi, (@{ surum = $script:DdSurum; skinler = $script:SkinAdlari } | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false))) } catch {}
}

# O skin sende var mı: LoL açıkken client'ın yerel API'sinden (10 dk önbellek); bilinmiyorsa $null
$script:SkinSahip = @{}
function Skin-Sahip($id, $num) {
    if ($Deneme -or -not (Surec 'LeagueClientUx')) { return $null }
    $lcu = Lcu-Bilgi
    if (-not $lcu) { return $null }
    # Önbellek hesaba bağlı: lockfile şifresi her client açılışında (başka hesaba girince de) değişir
    $anahtar = "$($lcu.Sifre)|$id"
    $k = $script:SkinSahip[$anahtar]
    if (-not $k -or ($null -eq $k.Sahip -and ([DateTime]::Now - $k.Zaman).TotalSeconds -gt 30) -or ([DateTime]::Now - $k.Zaman).TotalMinutes -gt 10) {
        $k = @{ Zaman = [DateTime]::Now; Sahip = $null }
        $script:SkinSahip[$anahtar] = $k
        if ($true) {
            if ($lcu) {
                $s = Lcu 'GET' '/lol-summoner/v1/current-summoner' $lcu $null 1500
                if ($s.Kod -eq '200') {
                    try {
                        $sid = ($s.Govde | ConvertFrom-Json).summonerId
                        $r = Lcu 'GET' "/lol-champions/v1/inventories/$sid/champions/$id/skins" $lcu $null 1500
                        if ($r.Kod -eq '200') {
                            $liste = $r.Govde | ConvertFrom-Json   # PS 5.1: önce değişkene, sonra dolaş
                            $h = @{}; foreach ($x in $liste) { if ($x.ownership) { $h["$([int]$x.id % 1000)"] = [bool]$x.ownership.owned } }
                            if ($h.Count) { $k.Sahip = $h }
                        }
                    } catch {}
                }
            }
        }
    }
    if ($k.Sahip -and $k.Sahip.ContainsKey("$num")) { return $k.Sahip["$num"] }
    return $null
}

# Modun oyunda nerede görüneceği: @{ Metin; Uyari; Num }
function Mod-Gorunum($m) {
    if (-not $m -or -not $m.Ana -or $null -eq $m.Skinler -or -not $m.Skinler.Count) { return $null }
    if ($m.Skinler -contains 0) { return @{ Metin = (T 'Klasik skinde görünür' 'Shows on the base skin'); Uyari = $false; Num = 0 } }
    $num = [int]$m.Skinler[0]; $ad = Skin-Adi $m.Ana $num
    $sahip = Skin-Sahip $m.Ana $num
    if ($sahip -eq $true) { return @{ Metin = (T "$ad skininde görünür · sende var" "Shows on $ad · you own it"); Uyari = $false; Num = $num } }
    if ($sahip -eq $false) { return @{ Metin = (T "Yalnız $ad skininde · sende yok" "Only on $ad · you don't own it"); Uyari = $true; Num = $num } }
    return @{ Metin = (T "Yalnız $ad skininde görünür" "Only shows on $ad"); Uyari = $true; Num = $num }
}

# Görseller: elle seçilen > modun kendi görseli (META/image.png) > yazdığı skinin splash'ı > şampiyonun splash'ı
$script:YerelGorselBellek = @{}
$script:GorselsizSha = @{}
function Yerel-Gorsel($yol) {
    if (-not $yol -or -not (Test-Path -LiteralPath $yol)) { return $null }
    if ($script:YerelGorselBellek[$yol]) { return $script:YerelGorselBellek[$yol] }
    try {
        $bi = New-Object Windows.Media.Imaging.BitmapImage
        $bi.BeginInit(); $bi.UriSource = New-Object Uri($yol); $bi.CacheOption = 'OnLoad'; $bi.DecodePixelWidth = 880; $bi.EndInit(); $bi.Freeze()
        $script:YerelGorselBellek[$yol] = $bi
        return $bi
    } catch { return $null }
}
function Mod-Gorsel-Yolu($m) {
    $el = $Ayar.customGorsel[$m.Id]
    if ($el) { $p = Join-Path $CustomGorselKlasoru $el; if (Test-Path -LiteralPath $p) { return $p } }
    $ds = Join-Path $CustomGorselKlasoru "$($m.Sha)-ds.jpg"   # divineskins'ten bulunan
    if ($m.Bicim -ne 'fantome' -or $script:GorselsizSha[$m.Sha]) {
        if (Test-Path -LiteralPath $ds) { return $ds }
        Ds-Baslat $m
        return $null
    }
    $p = Join-Path $CustomGorselKlasoru "$($m.Sha).png"
    if (Test-Path -LiteralPath $p) { return $p }
    try { if ([ModWad]::GorselCikar((Join-Path (Join-Path $LtkVeri 'mods') "$($m.Slug).fantome"), $p)) { return $p } } catch {}
    $script:GorselsizSha[$m.Sha] = $true
    if (Test-Path -LiteralPath $ds) { return $ds }
    Ds-Baslat $m
    return $null
}

# ---- Otomatik görsel: divineskins.gg kataloğu ----
# Kendi görseli olmayan mod, divineskins'in açık katalog API'sinde (tarayıcı gerekmez; site Cloudflare'lı ama api. değil) aranır:
# modun adı, adın ilk kelimesi atılmışı, sonra şampiyon adı. Şampiyon tutan ve yazarı ya da adı eşleşen sonucun önizlemesi
# JPEG olarak gorsel\custom\<sha>-ds.jpg'ye iner (WPF webp açamaz, CDN format=jpeg verir). Sonuç ds-gorsel.json'da; mod tekrar aranmaz.
$DsApi = 'https://api.divineskins.gg/api/catalog/skins'
$DsCdn = 'https://lol-assets.divine-cdn.com/cdn-cgi/image/width=1280,quality=90,format=jpeg,fit=scale-down,onerror=redirect/'
$DsSonucDosyasi = Join-Path $CustomGorselKlasoru 'ds-gorsel.json'
$script:DsSonuc = $null    # sha -> 'yok' | imagePath
$script:DsIsler = @{}      # sha -> @{ Mod; Asama; Gorev; Aramalar }
function Ds-Sonuc-Yukle {
    if ($null -ne $script:DsSonuc) { return }
    $script:DsSonuc = @{}
    try { $j = [IO.File]::ReadAllText($DsSonucDosyasi) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $script:DsSonuc[$p.Name] = "$($p.Value)" } } catch {}
}
function Ds-Sonuc-Yaz($sha, $deger) {
    $script:DsSonuc[$sha] = $deger
    try { [void](New-Item -ItemType Directory -Force $CustomGorselKlasoru); [IO.File]::WriteAllText($DsSonucDosyasi, ($script:DsSonuc | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false))) } catch {}
}
function Ds-Kelimeler($s) {
    $atla = @('repathed', 'mod', 'copy', 'wad', 'client', 'by', 'the', 'skin', 'skins', 'custom')
    return ,@(("$s".ToLowerInvariant() -replace '[^a-z0-9]+', ' ').Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { $_.Length -gt 1 -and $atla -notcontains $_ })
}
function Ds-Baslat($m) {
    if ($Sessiz -or -not $m.Ana -or -not $m.Sha) { return }
    Ds-Sonuc-Yukle
    if ($script:DsSonuc.ContainsKey($m.Sha) -or $script:DsIsler.ContainsKey($m.Sha)) { return }
    $temiz = ("$($m.Ad)" -replace '\(.*?\)', '' -replace '\.wad\.client', '' -replace '\s+-\s+copy$', '').Trim()
    $kelime = @($temiz.Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    $aramalar = New-Object Collections.ArrayList
    if ($temiz) { [void]$aramalar.Add($temiz) }
    if ($kelime.Count -ge 3) { [void]$aramalar.Add(($kelime[1..($kelime.Count - 1)] -join ' ')) }
    $en = $script:SampiyonEn[[int]$m.Ana]; if ($en) { [void]$aramalar.Add($en) }
    $script:DsIsler[$m.Sha] = @{ Mod = $m; Asama = 'sira'; Gorev = $null; Aramalar = $aramalar }
}
# API hız sınırı var (arka arkaya ~20 istekte 429): aynı anda tek istek, aralarında en az 2 sn; Ds-Tick sırayla başlatır
$script:DsSonIstek = [DateTime]::MinValue
function Ds-Sonraki($is) {
    if (-not $is.Aramalar.Count) { Ds-Sonuc-Yaz $is.Mod.Sha 'yok'; $script:DsIsler.Remove($is.Mod.Sha); return }
    $q = $is.Aramalar[0]; $is.Aramalar.RemoveAt(0)
    $script:DsSonIstek = [DateTime]::Now
    try {
        $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $wc.Headers.Add('User-Agent', 'RiotPlus')
        $is.Gorev = $wc.DownloadStringTaskAsync("$DsApi`?search=$([uri]::EscapeDataString($q))&page=0&size=40"); $is.Asama = 'ara'
    } catch { $is.Gorev = $null; $is.Asama = 'sira' }
}
# En iyi aday: şampiyon tutmalı; yazar tutuyorsa 1 ortak kelime yeter, tutmuyorsa adın en az %60'ı (en az 2 kelime)
function Ds-Sec($m, $liste) {
    $norm = { param($x) ("$x".ToLowerInvariant() -replace '[^a-z0-9]', '') }
    $sampiyonlar = @((& $norm $script:SampiyonKod[[int]$m.Ana]), (& $norm $script:SampiyonEn[[int]$m.Ana])) | Where-Object { $_ }
    $yazarlar = @(@($m.Ayar.authors) | ForEach-Object { "$_".ToLowerInvariant() })
    if ("$($m.Ayar.description)" -match 'by\s+([A-Za-z0-9_.-]+)') { $yazarlar += $Matches[1].ToLowerInvariant() }
    $yazarlar = @($yazarlar | Where-Object { $_ -and $_.Length -ge 3 })
    # Şampiyonun adı sayılmaz (her sonuçta geçer; "Blood King Talon" yalnız "talon" ortak diye başka modla eşleşiyordu)
    $sk = @((Ds-Kelimeler $script:SampiyonEn[[int]$m.Ana]) + (Ds-Kelimeler $script:SampiyonKod[[int]$m.Ana]) + $sampiyonlar)
    $adHam = Ds-Kelimeler $m.Ad
    $ad = @($adHam | Where-Object { $sk -notcontains $_ })
    $en = $null; $enPuan = 0
    foreach ($c in @($liste)) {
        if (-not $c -or -not $c.imagePath) { continue }
        if ($c.champion -and $sampiyonlar -notcontains (& $norm $c.champion)) { continue }
        $sanatci = "$($c.artistUsername)".ToLowerInvariant()
        $yazarTutar = [bool]@($yazarlar | Where-Object { $sanatci.StartsWith($_) -or $_.StartsWith($sanatci) }).Count
        $ck = Ds-Kelimeler $c.name   # önce değişkene: dizi tek nesne olarak döner
        $ortak = @($ck | Where-Object { $ad -contains $_ } | Select-Object -Unique).Count
        $uygun = ($yazarTutar -and $ortak -ge 1) -or ($ortak -ge [Math]::Max(2, [Math]::Ceiling($ad.Count * 0.6)))
        $puan = $ortak + $(if ($yazarTutar) { 3 } else { 0 })
        if ($uygun -and $puan -gt $enPuan) { $en = $c; $enPuan = $puan }
    }
    return $en
}
function Ds-Tick {
    if (-not $script:DsIsler.Count) { return }
    $yeni = $false
    $aktif = @($script:DsIsler.Values | Where-Object { $_.Gorev })
    if (-not $aktif.Count) {
        # Boşta: sıradaki aramayı 2 sn aralıkla başlat
        $sira = @($script:DsIsler.Values | Where-Object { $_.Asama -eq 'sira' }) | Select-Object -First 1
        if ($sira -and ([DateTime]::Now - $script:DsSonIstek).TotalSeconds -ge 2) { Ds-Sonraki $sira }
        return
    }
    foreach ($is in $aktif) {
        $sha = $is.Mod.Sha
        if (-not $is.Gorev.IsCompleted) { continue }
        $g = $is.Gorev; $is.Gorev = $null
        if ($is.Asama -eq 'ara') {
            # Ağ hatası / hız sınırı: "yok" yazılmaz, bu oturumda bırakılır, sonraki açılışta yeniden denenir
            if ($g.IsFaulted) { $script:DsIsler.Remove($sha); $script:DsSonIstek = [DateTime]::Now.AddSeconds(30); continue }
            $aday = $null
            try { $aday = Ds-Sec $is.Mod (($g.Result | ConvertFrom-Json).content) } catch {}
            if ($aday) {
                $is.Asama = 'indir'; $is.Yol = "$(Join-Path $CustomGorselKlasoru "$sha-ds.jpg").iniyor"; $is.Kaynak = "$($aday.imagePath)"
                try { [void](New-Item -ItemType Directory -Force $CustomGorselKlasoru); $wc = New-Object Net.WebClient; $wc.Headers.Add('User-Agent', 'RiotPlus'); $is.Gorev = $wc.DownloadFileTaskAsync("$DsCdn$($aday.imagePath)", $is.Yol) } catch { $script:DsIsler.Remove($sha) }
            } elseif ($is.Aramalar.Count) { $is.Asama = 'sira' }
            else { Ds-Sonuc-Yaz $sha 'yok'; $script:DsIsler.Remove($sha) }
        } else {
            $hedef = Join-Path $CustomGorselKlasoru "$sha-ds.jpg"
            $tamam = $false
            try { $b = [IO.File]::ReadAllBytes($is.Yol); $tamam = -not $g.IsFaulted -and $b.Length -gt 1000 -and $b[0] -eq 0xFF -and $b[1] -eq 0xD8 } catch {}
            if ($tamam) { Move-Item -LiteralPath $is.Yol -Destination $hedef -Force; Ds-Sonuc-Yaz $sha $is.Kaynak; $yeni = $true }
            else { Remove-Item -LiteralPath $is.Yol -ErrorAction SilentlyContinue; if (-not $g.IsFaulted) { Ds-Sonuc-Yaz $sha 'yok' } }
            $script:DsIsler.Remove($sha)
        }
    }
    if ($yeni) { $script:KahramanKod = $null; Custom-Yenile }
}
function Custom-Gorsel($m, $id) {
    $kod = if ($id) { $script:SampiyonKod[[int]$id] } else { $null }
    if ($m) {
        $p = Mod-Gorsel-Yolu $m
        if ($p) { $g = Yerel-Gorsel $p; if ($g) { return @{ Kaynak = $g; Anahtar = "yerel|$p" } } }
        if ($kod -and $m.Skinler -and $m.Skinler.Count -and -not ($m.Skinler -contains 0)) { $sk = "${kod}_$($m.Skinler[0])"; return @{ Kaynak = (Gorsel 'skin' $sk); Anahtar = "skin|$sk" } }
    }
    return @{ Kaynak = (Gorsel 'splash' $kod); Anahtar = "splash|$kod" }
}

# Yazılacak açık mod listesi: her şampiyonda en çok bir mod, "Diğer" modları ayrı ayrı. $secim'deki şampiyon seçimleri
# önce kalıcı kayda (customSecim) işlenir. Rakiplerde de görünsün kapalıysa şampiyon modlarından yalnız maçtakinin modu açılır;
# maç dışında o an LTK'da açık tek şampiyon açık kalır (her seçimde LTK yeniden başlamasın diye), birden çoksa ya da
# kip yeni değiştiyse ($script:CustomDaralt) hiçbiri.
$script:CustomDaralt = $false
function Custom-Hedef($secim) {
    if (-not $secim) { $secim = @{} }
    if ($null -eq $Ayar.customSecim) { $Ayar.customSecim = @{} }
    $yazildi = $false
    foreach ($k in @($secim.Keys)) { if ("$k" -notlike 'diger:*') { $Ayar.customSecim["$k"] = "$($secim[$k])"; $yazildi = $true } }
    if ($yazildi) { Ayar-Kaydet }
    $hedef = New-Object 'Collections.Generic.List[string]'
    $gruplar = Custom-Gruplar
    $herkes = [bool]$Ayar.customRakip
    $mac = if ($herkes) { 0 } else { Custom-Mac-Sampiyonu }
    $acikSampiyon = @($gruplar.Keys | Where-Object { $_ -ne 'diger' -and (Ltk-Acik-Mod $gruplar[$_]) })
    foreach ($k in $gruplar.Keys) {
        if ($k -eq 'diger') {
            foreach ($m in $gruplar[$k]) {
                $ac = if ($secim.ContainsKey("diger:$($m.Id)")) { [bool]$secim["diger:$($m.Id)"] } else { $m.Acik }
                if ($ac) { $hedef.Add($m.Id) }
            }
            continue
        }
        $s = Custom-Secili $gruplar[$k]
        if (-not $s) { continue }
        if ($herkes) { $hedef.Add($s.Id) }
        elseif ($mac) { if ($k -eq "$mac") { $hedef.Add($s.Id) } }
        elseif (-not $script:CustomDaralt -and $acikSampiyon.Count -eq 1 -and $acikSampiyon[0] -eq $k) { $hedef.Add($s.Id) }
    }
    return ,$hedef
}
function Custom-Ayni($hedef) {
    if (-not $script:LtkKutuphane -or -not $script:LtkKutuphane.Profil) { return $false }
    $simdi = @(@($script:LtkKutuphane.Profil['enabledMods']) | ForEach-Object { "$_" })
    if ($simdi.Count -ne $hedef.Count) { return $false }
    foreach ($id in $hedef) { if ($simdi -notcontains $id) { return $false } }
    return $true
}
# LTK tepside açılmalı ve patcher'ı kendiliğinden başlatmalı
function Ltk-Ayar-Tamam {
    try { $a = Json-Oku (Join-Path $LtkVeri 'settings.json'); return ([bool]$a['startInTray'] -and [bool]$a['alwaysStartPatcher']) } catch { return $false }
}

# Yalnız LTK kapalıyken çağrılır
function Ltk-Yaz($hedef) {
    if ($Deneme) {
        $adlar = @($hedef | ForEach-Object { $id = $_; $m = @($script:LtkKutuphane.Modlar | Where-Object { $_.Id -eq $id })[0]; if ($m) { $m.Ad } else { $id } })
        Yaz "deneme: LTK'ya yazılmadı ($($hedef.Count) mod açık olurdu: $($adlar -join ', '))" $RenkSoluk; return
    }
    $lib = Join-Path $LtkVeri 'library.json'
    if (-not $script:LtkYedeklendi) { Copy-Item -LiteralPath $lib -Destination "$lib.riotplus-yedek" -Force; $script:LtkYedeklendi = $true }
    $j = Json-Oku $lib
    foreach ($p in @($j['profiles'])) { if ($p -and $p['id'] -eq $j['activeProfileId']) { $p['enabledMods'] = [object[]]@($hedef) } }
    Json-Yaz $lib $j
    $script:LtkBilinenAcik = @($hedef | ForEach-Object { "$_" })   # kendi yazdığımız; "dışarıdan değişti" sayılmasın
    $ayarYol = Join-Path $LtkVeri 'settings.json'
    try {
        $a = Json-Oku $ayarYol
        if (-not $a['startInTray'] -or -not $a['alwaysStartPatcher']) { $a['startInTray'] = $true; $a['alwaysStartPatcher'] = $true; Json-Yaz $ayarYol $a }
    } catch {}
    Ltk-Oku -Zorla
}

# LTK'yı ve patcher'ını kapatır (LTK'nın kapat düğmesi tepsiye küçülttüğü için süreç sonlandırılır; maçta çağrılmaz)
function Ltk-Durdur {
    $script:PatcherBekle = $null
    if ($Deneme) { return }
    $p = @(Get-Process -Name 'ltk-manager', 'ltk_patcher_host' -ErrorAction SilentlyContinue)
    if (-not $p.Count) { return }
    $p | Stop-Process -Force -ErrorAction SilentlyContinue
    $son = [DateTime]::Now.AddSeconds(8)
    while ([DateTime]::Now -lt $son -and @(Get-Process -Name 'ltk-manager', 'ltk_patcher_host' -ErrorAction SilentlyContinue).Count) { Bekle 0.3 }
}
# Riot Plus kapanırken LTK'yı da kapatır (ayar: ltkKapat). Maç sürüyorsa dokunmaz: oyun açıkken LTK durdurulmaz.
function Ltk-Kapanista-Durdur($adlar = @('ltk-manager', 'ltk_patcher_host'), $oyun = 'League of Legends') {
    if ($Deneme -or -not $Ayar.ltkKapat) { return 'atlandi' }
    if (Rose-Kipi) { return 'atlandi' }   # Rose kipinde LTK Rose'undur; Rose kendi açtığını kendi kapatır
    $p = @(Get-Process -Name $adlar -ErrorAction SilentlyContinue)
    if (-not $p.Count) { return 'yok' }
    $not = if (Get-Process -Name $oyun -ErrorAction SilentlyContinue) { "Riot Plus kapandı; maç sürdüğü için LTK'ya dokunulmadı." } else { $p | Stop-Process -Force -ErrorAction SilentlyContinue; "Riot Plus kapandı; LTK de kapatıldı." }
    try { [IO.File]::AppendAllText($GunlukDosyasi, "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  $not`r`n", (New-Object Text.UTF8Encoding($false))) } catch {}
    if ($not -match 'dokunulmadı') { 'mac' } else { 'durdu' }
}
function Ltk-Baslat($dosyalar = @()) {
    if ($Deneme) { return }
    if (@($dosyalar).Count) { Start-Process -FilePath $LtkExe -ArgumentList @($dosyalar | ForEach-Object { '"' + $_ + '"' }) }
    else { Start-Process -FilePath $LtkExe }
}
# LTK 1.32.2'nin "açılışta patcher'ı başlat"ı, mod listesi arayüze yüklenmeden çalışırsa listeyi boş sanıp başlatmadan çıkıyor
# (useAutoStartPatcher yarışı). Tek bekleme noktası "lig HDD'de mi" uyarı kontrolü (hasSeenHddWarning=false iken yapılır);
# o araya girince liste yetişiyor. Bu yüzden her açılıştan önce bayrak sıfırlanır ve LTK'nın günlüğünde
# "Start patcher requested" aranır; görülmezse LTK yeniden açılır (3 deneme). 4 Kas 2026: 1. açılış başladı, bayraksız 2. başlamadı.
function Ltk-Gunluk { Get-ChildItem (Join-Path $LtkVeri 'logs') -Filter 'ltk-manager*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1 }
function Ltk-Gunluk-Konum { $g = Ltk-Gunluk; if ($g) { @{ Yol = $g.FullName; Uzunluk = $g.Length } } else { $null } }
# LTK açıkken de okunur (paylaşımlı); renk kodları atılır
function Ltk-Gunluk-Oku($g, [long]$bas = 0) {
    try {
        $fs = New-Object IO.FileStream($g.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try {
            if ($bas -gt $fs.Length) { $bas = 0 }
            [void]$fs.Seek($bas, [IO.SeekOrigin]::Begin)
            $metin = (New-Object IO.StreamReader($fs)).ReadToEnd()
        } finally { $fs.Dispose() }
        return ($metin -replace "\x1b\[[0-9;]*m", '')
    } catch { return '' }
}
function Ltk-Gunlukte($konum, $desen) {
    $g = Ltk-Gunluk
    if (-not $g) { return $false }
    $bas = if ($konum -and $konum.Yol -eq $g.FullName) { [long]$konum.Uzunluk } else { 0 }
    return (Ltk-Gunluk-Oku $g $bas).Contains($desen)
}
# Çalışan LTK bu açılışında patcher'ı başlatmayı denedi mi (derleme sürerken ltk_patcher_host henüz yoktur)
function Ltk-Patcher-Istendi {
    $p = Surec 'ltk-manager'; $g = Ltk-Gunluk
    if (-not $p -or -not $g) { return $false }
    $sat = @((Ltk-Gunluk-Oku $g) -split "`n" | Where-Object { $_.Contains('Start patcher requested') }) | Select-Object -Last 1
    if (-not $sat -or $sat -notmatch '^\s*(\d{4}-\d\d-\d\dT[\d:.]+Z)') { return $false }
    try { return ([DateTime]::Parse($Matches[1]) -ge $p.StartTime.AddSeconds(-2)) } catch { return $false }
}
function Hdd-Bayragi-Sifirla {
    $yol = Join-Path $LtkVeri 'settings.json'
    try { $a = Json-Oku $yol; if ($a['hasSeenHddWarning'] -ne $false) { $a['hasSeenHddWarning'] = $false; Json-Yaz $yol $a } } catch {}
}
# LTK'yı açar ve patcher'ı başlattığını doğrular; yalnız LTK kapalıyken çağrılır
function Ltk-Calistir {
    if ($Deneme) { return }
    for ($i = 1; $i -le 3; $i++) {
        Hdd-Bayragi-Sifirla
        $konum = Ltk-Gunluk-Konum
        Ltk-Baslat
        $son = [DateTime]::Now.AddSeconds(12)
        while ([DateTime]::Now -lt $son) {
            Bekle 0.5
            if (Ltk-Gunlukte $konum 'Start patcher requested') { Ltk-Ac-Bildir; return }
        }
        if ($i -lt 3) { Yaz (T "LTK patcher'ı başlatmadı, yeniden açıyorum ($i/3)..." "LTK didn't start its patcher, reopening ($i/3)...") $RenkSoluk; Ltk-Durdur }
    }
    Yaz (T "LTK patcher'ı kendisi başlatmadı. 'LTK'yı aç' deyip Start'a basman lazım." "LTK didn't start its patcher. Open LTK and press Start.") $RenkTuruncu
}

# LTK açılınca skinleri derler (ilk seferde ~1 dk), sonra patcher süreci (ltk_patcher_host) oyunu beklemeye başlar.
# Bekleme arka planda: sonucu Ltk-Durum-Guncelle bildirir, araç bu sırada kilitlenmez.
$script:PatcherBekle = $null
function Ltk-Ac-Bildir {
    $script:PatcherBekle = @{ Bitis = [DateTime]::Now.AddSeconds($PatcherBekleSn) }
    Yaz (T 'LTK skinleri hazırlıyor; ilk seferde bir dakikayı bulabilir.' 'LTK is preparing the skins; the first time can take a minute.') $RenkSoluk
}
function Patcher-Bekle-Tick {
    if (-not $script:PatcherBekle) { return }
    if ($script:LtkDurum.Patcher) { $script:PatcherBekle = $null; Yaz (T 'Custom hazır abi; LTK tepside, oyuna girince skinler gelir.' 'Customs are ready; LTK is in the tray.') $RenkYesil }
    elseif (-not $script:LtkDurum.Acik -or [DateTime]::Now -gt $script:PatcherBekle.Bitis) {
        $script:PatcherBekle = $null
        Yaz (T "LTK patcher'ı başlatmadı. 'LTK'yı aç' deyip Start'a basabilirsin." "LTK didn't start its patcher. Open LTK and press Start.") $RenkTuruncu
    }
}

# Seçimi uygular; -Hazirlik: yalnız LTK kapalıysa açar (açılışta, lobide)
function Custom-Uygula([switch]$Hazirlik) {
    if (Rose-Kipi) { Rose-Uygula -Hazirlik:$Hazirlik; return }
    $secim = $script:CustomIstek; $script:CustomIstek = $null
    # Rose açıkken (kaynak LTK'ya elle alınmış ama Rose dışarıdan açılmış) LTK'ya dokunulmaz: ikisi aynı LTK'yı kullanır
    if (Rose-Acik) { Yaz (T "Rose açık; ikisi aynı LTK'yı kullandığı için custom'ı şimdi uygulamıyorum. Rose'u kapat ya da kaynağı Rose yap." "Rose is running; both use the same LTK, so customs aren't applied now. Close Rose or switch the source to Rose.") $RenkTuruncu; Custom-Yenile; return }
    if (-not (Ltk-Kurulu)) { Yaz (T 'LTK Manager kurulu değil; Custom skinler bölümünden kurabilirsin.' 'LTK Manager is not installed; install it from Custom skins.') $RenkTuruncu; return }
    if ($Hazirlik -and (Ltk-Acik) -and ((Ltk-Patcher) -or $script:PatcherBekle -or (Ltk-Patcher-Istendi))) { return }
    if (Oyun-Acik) { Yaz (T 'Maçtayken custom değiştirilemez; maç bitince seç.' "Can't change customs mid-game; pick after the game.") $RenkTuruncu; Custom-Yenile; return }
    Ltk-Oku -Zorla
    if (-not $script:LtkKutuphane) {
        if ($Ayar.custom -and -not (Ltk-Acik)) { Ltk-Calistir }   # ilk açılış: LTK kütüphanesini kendisi kurar
        Custom-Yenile; return
    }
    $hedef = Custom-Hedef $secim
    $script:CustomDaralt = $false
    $acikti = Ltk-Acik
    $gerek = (-not (Custom-Ayni $hedef)) -or -not (Ltk-Ayar-Tamam)
    if ($gerek) {
        if ($acikti) { Ltk-Durdur }
        Ltk-Yaz $hedef
    }
    if ($secim -and $secim.Count -eq 1) {
        $k = @($secim.Keys)[0]
        if ($k -like 'diger:*') {
            $m = $script:LtkKutuphane.Modlar | Where-Object { "diger:$($_.Id)" -eq $k } | Select-Object -First 1
            if ($m) { Yaz $(if ($secim[$k]) { T "$($m.Ad) açık." "$($m.Ad) is on." } else { T "$($m.Ad) kapalı." "$($m.Ad) is off." }) $RenkSoluk }
        } else {
            $m = $script:LtkKutuphane.Modlar | Where-Object { $_.Id -eq $secim[$k] } | Select-Object -First 1
            Yaz $(if ($m) { T "$(Sampiyon-Adi ([int]$k)): $($m.Ad) seçildi." "$(Sampiyon-Adi ([int]$k)): $($m.Ad) selected." } else { T "$(Sampiyon-Adi ([int]$k)) klasik skine döndü." "$(Sampiyon-Adi ([int]$k)) is back to the base skin." }) $RenkSoluk
        }
    }
    # 9 Kas: maç dışında (rakipte görünsün kapalıyken) açılacak mod yoksa LTK'yı açmaya çalışma; patcher boş listeyle
    # başlamaz, 3 deneme boşa döner ve "Start'a bas" diye yanlış yönlendirir. Şampiyon kilitlenince Custom-Mac-Tick açar.
    if ($Ayar.custom -and $hedef.Count -eq 0) {
        if (Ltk-Acik) { Ltk-Durdur }
        Yaz (T 'Custom hazır: şampiyonu kilitleyince onun modu açılır, LTK o an kendisi başlar.' 'Customs ready: lock a champion and its mod turns on; LTK starts by itself then.') $RenkSoluk
    }
    elseif ($Ayar.custom -and ($gerek -or -not (Ltk-Acik))) { Ltk-Calistir }
    elseif ($Ayar.custom -and -not (Ltk-Patcher) -and -not $script:PatcherBekle -and -not (Ltk-Patcher-Istendi)) {
        Yaz (T "LTK açık ama patcher'ı başlamamış; yeniden açıyorum." "LTK is open but its patcher never started; reopening.") $RenkSoluk
        Ltk-Durdur; Ltk-Calistir
    }
    elseif ($Ayar.custom -and -not $secim) { Yaz (T 'Custom açık; LTK zaten çalışıyor.' 'Customs on; LTK is already running.') $RenkSoluk }
    Custom-Yenile
    if ($script:CustomIstek) { Custom-Uygula }   # bu sırada yapılan seçim
}

# "Rakiplerde de görünsün" kapalıyken: seçimde şampiyonun kesinleşince (kilit / ARAM'da atanan / takas) LTK'daki açık
# liste yalnız onun moduna indirilir. Şampiyon başına bir kez denenir; seçimden çıkınca sıfırlanır.
$script:CustomMacSon = 0
function Custom-Mac-Tick {
    if ($script:SonFaz -ne 'ChampSelect') { $script:CustomMacSon = 0; return }
    if (-not $Ayar.custom -or $Ayar.customRakip -or $script:Mesgul -or $script:BekleyenIslem -or -not (Ltk-Kurulu)) { return }
    if ((Rose-Kipi) -or (Rose-Acik)) { return }
    $mac = Custom-Mac-Sampiyonu
    if (-not $mac -or $mac -eq $script:CustomMacSon) { return }
    $script:CustomMacSon = $mac
    try { Ltk-Oku } catch {}
    if (Custom-Ayni (Custom-Hedef $null)) { return }
    $s = Custom-Secim $mac
    Yaz $(if ($s) { T "$(Sampiyon-Adi $mac): $($s.Ad) açılıyor; diğer şampiyonların custom'ı bu maçta kapalı." "$(Sampiyon-Adi $mac): turning on $($s.Ad); other champions' customs are off this game." } else { T "$(Sampiyon-Adi $mac) klasik; diğer şampiyonların custom'ı bu maçta kapalı." "$(Sampiyon-Adi $mac) uses the base skin; other customs are off this game." }) $RenkSoluk
    $script:BekleyenIslem = 'custom'   # zamanlayıcı turunun sonunda çalışır (otomatikler önce)
}

function Custom-Durdur {
    if (Rose-Kipi) {
        if (-not (Rose-Acik)) { Yaz (T 'Custom kapalı.' 'Customs off.') $RenkSoluk }
        elseif (Rose-Durdur) { Yaz (T "Custom kapalı; Rose'u durdurdum." 'Customs off; stopped Rose.') $RenkSoluk }
        else { $Ayar.custom = $true; Ayar-Kaydet }
        Custom-Yenile; return
    }
    if (Oyun-Acik) { Yaz (T "Maçtayken custom kapatılamaz; maç bitince kapat." "Can't turn customs off mid-game.") $RenkTuruncu; $Ayar.custom = $true; Ayar-Kaydet; Custom-Yenile; return }
    Ltk-Durdur
    Yaz (T "Custom kapalı; LTK'yı durdurdum." "Customs off; stopped LTK.") $RenkSoluk
    Custom-Yenile
}

# Seçilen dosyaları LTK'ya verir; içe alınanlar kendi şampiyonunda seçili olur
function Mod-Ekle {
    $dosyalar = @($script:EklenecekDosyalar); $script:EklenecekDosyalar = @()
    if (-not $dosyalar.Count) { return }
    if (-not (Ltk-Kurulu)) { Yaz (T 'Önce LTK Manager kurulmalı.' 'Install LTK Manager first.') $RenkTuruncu; return }
    if ((Rose-Kipi) -or (Rose-Acik)) { Yaz (T "Rose kipinde modlar Rose'un kendi menüsünden eklenir (LoL'ün içinde). Buradan eklemek için kaynağı LTK yap." "In Rose mode, add mods from Rose's own menu (inside LoL). Switch the source to LTK to add them here.") $RenkTuruncu; return }
    if (Oyun-Acik) { Yaz (T 'Maçtayken mod eklenemez; maç bitince ekle.' "Can't add mods mid-game.") $RenkTuruncu; return }
    if ($Deneme) { Yaz "deneme: $($dosyalar.Count) dosya LTK'ya verilmedi" $RenkSoluk; return }
    try { Ltk-Oku -Zorla } catch {}
    $onceki = @{}; if ($script:LtkKutuphane) { foreach ($m in $script:LtkKutuphane.Modlar) { $onceki[$m.Id] = $true } }
    Yaz (T "LTK'ya veriyorum ($($dosyalar.Count) dosya)..." "Handing $($dosyalar.Count) file(s) to LTK...") $RenkSoluk
    Ltk-Baslat $dosyalar
    # LTK içe alınca library.json'a yazar; yeni modlar gelip 3 sn değişmeyene dek beklenir (en çok 60 sn)
    $son = [DateTime]::Now.AddSeconds(60); $yeni = @(); $sabit = 0
    while ([DateTime]::Now -lt $son) {
        Bekle 1
        try { Ltk-Oku -Zorla } catch { continue }
        if (-not $script:LtkKutuphane) { continue }
        $simdi = @($script:LtkKutuphane.Modlar | Where-Object { -not $onceki[$_.Id] })
        if ($simdi.Count -and $simdi.Count -eq $yeni.Count) { $sabit++ } else { $sabit = 0 }
        $yeni = $simdi
        if ($yeni.Count -ge $dosyalar.Count -or ($yeni.Count -and $sabit -ge 3)) { break }
    }
    if (-not $yeni.Count) { Yaz (T 'LTK modu almadı; sebebi LTK penceresinde yazıyor.' "LTK didn't take the mod; see LTK's window.") $RenkTuruncu; return }
    Bekle 3   # sağlık kontrolü (skinhack) yazılsın
    Ltk-Oku -Zorla
    $secim = @{}; $adlar = @(); $engelli = @()
    foreach ($y in $yeni) {
        $m = $script:LtkKutuphane.Modlar | Where-Object { $_.Id -eq $y.Id } | Select-Object -First 1
        if (-not $m) { continue }
        if ($m.Engelli) { $engelli += $m.Ad; continue }
        if ($m.Ana) { $secim["$($m.Ana)"] = $m.Id; $adlar += "$($m.Ad) ($(Sampiyon-Adi $m.Ana))" }
        else { $secim["diger:$($m.Id)"] = $true; $adlar += $m.Ad }
    }
    $hedef = Custom-Hedef $secim
    Ltk-Durdur
    Ltk-Yaz $hedef
    if ($adlar.Count) { Yaz ((T 'Eklendi ve seçildi: ' 'Added and selected: ') + ($adlar -join ', ')) $RenkYesil }
    if ($engelli.Count) { Yaz ((T "LTK skinhack saydı, kapalı kaldı: " "LTK flagged as skinhack, left off: ") + ($engelli -join ', ')) $RenkTuruncu }
    if ($Ayar.custom) { Ltk-Calistir }
    Custom-Yenile
}

# GitHub'daki son sürümü arka planda sorar (açılışta bir kez)
function Ltk-Surum-Sor {
    if ($Sessiz) { return }
    try {
        $wc = New-Object Net.WebClient
        $wc.Encoding = [Text.Encoding]::UTF8
        $wc.Headers.Add('User-Agent', 'RiotPlus'); $wc.Headers.Add('Accept', 'application/vnd.github+json')
        $script:LtkSurumGorevi = $wc.DownloadStringTaskAsync($LtkSurumUrl)
    } catch {}
}
function Ltk-Surum-Tick {
    $g = $script:LtkSurumGorevi
    if (-not $g -or -not $g.IsCompleted) { return }
    $script:LtkSurumGorevi = $null
    if ($g.IsFaulted) { return }
    $r = $g.Result | ConvertFrom-Json
    $a = @($r.assets) | Where-Object { "$($_.name)" -match '^LTK\.Manager_[\d.]+_x64-setup\.exe$' } | Select-Object -First 1
    if (-not $a) { return }
    $surum = [version]("$($r.tag_name)".TrimStart('v'))
    $script:LtkSon = @{ Surum = $surum; Url = "$($a.browser_download_url)"; Sha = ("$($a.digest)" -replace '^sha256:', '').ToLowerInvariant() }
    $kurulu = Ltk-Surum
    if ($kurulu -and $surum -gt $kurulu) {
        $m = T "LTK'nın yeni sürümü çıkmış ($surum). Üstteki yeşil şeritten güncelleyebilirsin." "A new LTK is out ($surum). Update it from the green strip at the top."
        Yaz $m $RenkSoluk
        if ($script:LtkBildirilen -ne $surum) { $script:LtkBildirilen = $surum; Bildir $m }   # küçültülmüşse balon, sürüm başına bir kez
    }
    Guncelle-Serit
    Custom-Yenile
}

# LTK'nın yeni sürümü varsa kahraman görselinin üstünde kalıcı şerit; tıklayınca Ltk-Kur (indir + özet + imza + /S)
# 5 Kas: açılıştaki "yeni sürüm" mesajı 2 sn sonra "skinler hazırlanıyor" mesajıyla ezildi, Enes hiç görmedi.
$script:LtkBildirilen = $null
function Guncelle-Serit {
    if ($script:Kapandi -or -not $GuncelleSerit) { return }
    $son = $script:LtkSon; $kurulu = Ltk-Surum
    if ($son -and $kurulu -and $son.Surum -gt $kurulu) {
        $GuncelleYazi.Text = T "LTK $($son.Surum) çıktı · sende $kurulu" "LTK $($son.Surum) is out · you have $kurulu"
        $GuncelleBaglanti.Text = T 'Güncelle' 'Update'
        $GuncelleSerit.ToolTip = T 'Resmi sürümü indirir, özetini ve imzasını kontrol edip kurar (yönetici izni ister). Maçtayken kurmaz.' "Downloads the official release, checks its hash and signature, then installs (asks for admin). Not mid-game."
        $GuncelleSerit.Visibility = 'Visible'
    } else { $GuncelleSerit.Visibility = 'Collapsed' }
}

# Resmi kurulum dosyasını indirir, özetini ve imzasını kontrol eder, sessiz kurar (yönetici izni ister)
function Ltk-Kur {
    $s = $script:LtkSon
    if (-not $s) { Yaz (T "LTK'nın son sürümünü öğrenemedim; internet var mı?" "Couldn't get LTK's latest version; are you online?") $RenkTuruncu; return }
    if (Oyun-Acik) { Yaz (T 'Maçtayken kurulmaz; maç bitince dene.' 'Not mid-game; try after.') $RenkTuruncu; return }
    if (Rose-Acik) { Yaz (T "Rose açıkken LTK kurulmaz (LTK'yı o kullanıyor); önce Rose'u durdur." "LTK can't be installed while Rose is running (it uses LTK); stop Rose first.") $RenkTuruncu; return }
    if ($Deneme) { Yaz "deneme: LTK $($s.Surum) kurulmadı" $RenkSoluk; return }
    $klasor = Join-Path $env:TEMP 'riotplus-ltk'
    [void](New-Item -ItemType Directory -Force $klasor)
    $yol = Join-Path $klasor "LTK.Manager_$($s.Surum)_x64-setup.exe"
    Yaz (T "LTK $($s.Surum) iniyor..." "Downloading LTK $($s.Surum)...") $RenkSoluk
    $wc = New-Object Net.WebClient; $wc.Headers.Add('User-Agent', 'RiotPlus')
    $g = $wc.DownloadFileTaskAsync($s.Url, $yol)
    while (-not $g.IsCompleted) { Bekle 0.3 }
    if ($g.IsFaulted -or -not (Test-Path $yol)) { Yaz (T 'İndirme olmadı.' 'Download failed.') $RenkKirmizi; return }
    $sha = (Get-FileHash -LiteralPath $yol -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($s.Sha -and $sha -ne $s.Sha) { Remove-Item -LiteralPath $yol -Force; Yaz (T "İnen dosyanın özeti GitHub'dakiyle tutmadı, kurmadım." "The download's hash didn't match GitHub's; not installing.") $RenkKirmizi; return }
    $imza = Get-AuthenticodeSignature -LiteralPath $yol
    if ($imza.Status -ne 'Valid' -or -not "$($imza.SignerCertificate.Subject)".StartsWith($LtkImzaci)) { Yaz (T 'Kurulum dosyasının imzası beklenen gibi değil, kurmadım.' "The installer's signature isn't the expected one; not installing.") $RenkKirmizi; return }
    Ltk-Durdur
    Yaz (T 'Kuruyorum; Windows yönetici izni soracak.' 'Installing; Windows will ask for admin rights.') $RenkSoluk
    try { $p = Start-Process -FilePath $yol -ArgumentList '/S' -Verb RunAs -PassThru -ErrorAction Stop }
    catch { Yaz (T 'Yönetici izni verilmedi, kurulum yapılmadı.' 'No admin rights given; not installed.') $RenkTuruncu; if ($Ayar.custom -and -not (Rose-Kipi)) { Ltk-Calistir }; return }
    while (-not $p.HasExited) { Bekle 0.5 }
    if ($p.ExitCode -ne 0) { Yaz ((T 'Kurulum hata verdi, kod ' 'Installer failed, code ') + $p.ExitCode) $RenkKirmizi }
    else { Yaz (T "LTK $(Ltk-Surum) kuruldu." "LTK $(Ltk-Surum) installed.") $RenkYesil }
    Guncelle-Serit
    if ($Ayar.custom) { $script:CustomIstek = $null; Custom-Uygula }
    Custom-Yenile
}

# ---- Çökme koruması ----
# LTK her oyun açılışını incidents\<zaman>.json'a yazar. Oyun custom yüzünden açılamadıysa (verdict.consequence = game-stopped):
# LTK hemen durdurulur (yeniden bağlanınca oyun temiz açılsın), çökmeye yol açan WAD'a yazan açık modlar kapatılır, custom kapanır.
# 4 Kas 2026: 16.22 yamasında Challenger Recall (DATA.wad) oyunu 6 kez açtırmadı ("Installation is corrupt. WadFile mount failed").
$script:OlayGorulen = $null
$script:CokmeIstek = $null
function Olay-Tick {
    $son = Get-ChildItem (Join-Path $LtkVeri 'incidents') -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if (-not $son) { if ($null -eq $script:OlayGorulen) { $script:OlayGorulen = '' }; return }
    if ($null -eq $script:OlayGorulen) { $script:OlayGorulen = $son.Name; return }   # açılıştaki eski olaylar sayılmaz
    if ([string]::CompareOrdinal($son.Name, $script:OlayGorulen) -le 0) { return }   # adlar zaman damgası, sıralı
    $script:OlayGorulen = $son.Name
    if ((Rose-Kipi) -or (Rose-Acik)) { return }   # Rose'un oturumu; LTK'yı ve modlarını o toparlar
    try { $o = Json-Oku $son.FullName } catch { return }
    $v = $o['verdict']
    if (-not $v -or "$($v['consequence'])" -ne 'game-stopped') { return }
    $script:CokmeIstek = @{ Wad = "$($v['subject'])"; Baslik = "$($v['title'])" }
    $script:BekleyenIslem = 'cokme'
}
function Cokme-Isle {
    $c = $script:CokmeIstek; $script:CokmeIstek = $null
    if (-not $c) { return }
    Ltk-Durdur
    try { Ltk-Oku -Zorla } catch {}
    $suclu = @()
    $rap = $null; try { $rap = (Json-Oku (Join-Path $LtkVeri 'wad-reports.json'))['reports'] } catch {}
    if ($script:LtkKutuphane -and $rap -and $c.Wad) {
        foreach ($m in $script:LtkKutuphane.Modlar) {
            if (-not $m.Acik -or -not $rap.ContainsKey($m.Id)) { continue }
            if (@(@($rap[$m.Id]['affectedWads']) | Where-Object { "$_" -like "*/$($c.Wad)" -or "$_" -eq $c.Wad }).Count) { $suclu += $m }
        }
    }
    if ($suclu.Count) {
        $kalan = @(@($script:LtkKutuphane.Profil['enabledMods']) | ForEach-Object { "$_" } | Where-Object { @($suclu | ForEach-Object { $_.Id }) -notcontains $_ })
        Ltk-Yaz $kalan
    }
    $Ayar.custom = $false; Ayar-Kaydet
    $adlar = ($suclu | ForEach-Object { $_.Ad }) -join ', '
    $metin = if ($adlar) { T "Custom oyunu açtırmadı ($adlar → $($c.Wad)). O modu kapattım, custom'ı da şimdilik kapattım; yeniden bağlan." "A custom stopped the game ($adlar → $($c.Wad)). Turned it and customs off; reconnect." }
             else { T "Custom oyunu açtırmadı ($($c.Wad)). Custom'ı kapattım; yeniden bağlan." "A custom stopped the game ($($c.Wad)). Customs off; reconnect." }
    Yaz $metin $RenkKirmizi
    Bildir $metin
    Custom-Yenile
}

# Süreç durumu + kütüphane değişikliği (zamanlayıcıdan, 2 sn'de bir)
function Ltk-Durum-Guncelle {
    $script:LtkDurum = @{ Acik = (Ltk-Acik); Patcher = (Ltk-Patcher) }
    Rose-Durum-Oku
    if (Rose-Kipi) {
        # Rose kipi: LTK'yı Rose açıp kapatır; burada yalnız durum gösterilir, LTK yeniden açılmaz
        $script:PatcherBekle = $null
        if ($CustomGorunum.Visibility -eq 'Visible') { Custom-Bilgi-Guncelle }
        return
    }
    Patcher-Bekle-Tick
    try { Ltk-Oku } catch {}
    if ($CustomGorunum.Visibility -eq 'Visible') { if ($script:LtkYenilendi -and -not $script:Mesgul) { Custom-Liste-Olustur } else { Custom-Bilgi-Guncelle } }
    # Custom açıkken LTK kapanmışsa (elle kapatıldı, PC yeniden başladı) lobide/sırada/seçimde yeniden açılır; 2 dakikada bir denenir
    if ($Ayar.custom -and -not $Deneme -and -not $script:RoseDurum.Acik -and -not $script:LtkDurum.Acik -and -not $script:Mesgul -and -not $script:BekleyenIslem -and
        @('Lobby', 'Matchmaking', 'ReadyCheck', 'ChampSelect') -contains $script:SonFaz -and (Ltk-Kurulu) -and
        ([DateTime]::Now - $script:LtkOtoZaman).TotalMinutes -ge 2) {
        $script:LtkOtoZaman = [DateTime]::Now; $script:BekleyenIslem = 'customhazir'
    }
}

# ---- Pencere ----
$script:Yukleniyor = $true
$Ayar = Ayar-Yukle
$script:Dil = $Ayar.dil
Rose-Durum-Oku
$Baslik = Baslik-Metni
Sampiyon-Yukle

$PencereXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Riot Plus" Width="452" SizeToContent="Height" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="CanMinimize" WindowStartupLocation="CenterScreen" UseLayoutRounding="True"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="#ECE5D8" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <FontFamily x:Key="Dar">Bahnschrift</FontFamily>
    <FontFamily x:Key="IkonFont">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="#1C232D"/><Setter Property="Foreground" Value="#ECE5D8"/>
      <Setter Property="BorderBrush" Value="#2A333F"/><Setter Property="Padding" Value="9,6"/><Setter Property="FontSize" Value="12.5"/>
    </Style>
    <Style x:Key="DarYazi" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource Dar}"/><Setter Property="FontStretch" Value="SemiCondensed"/><Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="BolumBaslik" TargetType="TextBlock">
      <Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Foreground" Value="#8C95A1"/><Setter Property="Margin" Value="0,0,0,4"/>
    </Style>
    <Style x:Key="Baglanti" TargetType="TextBlock">
      <Setter Property="Cursor" Value="Hand"/><Setter Property="TextTrimming" Value="CharacterEllipsis"/>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="TextDecorations" Value="Underline"/><Setter Property="Foreground" Value="White"/></Trigger></Style.Triggers>
    </Style>
    <!-- Apple HIG (Kas 2026) uyarlaması: kapsül düğmeler, her düğmede basma durumu, kayan anahtar,
         içerik üstünde yüzen "cam" (Liquid Glass) katman, gruplu bölüm kartları. Ayrıntı: notlar\11-ogrenme\apple-hig -->
    <!-- Cam: yarı saydam koyu dolgu + üstte parlak, altta sönük ince kenar (ışığın camın üst kenarına vurması) -->
    <LinearGradientBrush x:Key="CamKenar" StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#59FFFFFF" Offset="0"/><GradientStop Color="#14FFFFFF" Offset="0.45"/><GradientStop Color="#0AFFFFFF" Offset="0.7"/><GradientStop Color="#26FFFFFF" Offset="1"/>
    </LinearGradientBrush>
    <LinearGradientBrush x:Key="CamParilti" StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#1FFFFFFF" Offset="0"/><GradientStop Color="#00FFFFFF" Offset="0.55"/>
    </LinearGradientBrush>
    <Style x:Key="Cam" TargetType="Border">
      <Setter Property="BorderBrush" Value="{StaticResource CamKenar}"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Background" Value="#00000000"/>
      <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="Black" BlurRadius="12" ShadowDepth="2" Opacity="0.35"/></Setter.Value></Setter>
    </Style>
    <!-- Gruplu bölüm kartı (iOS Ayarlar'daki "inset grouped" liste) ve kart içi ince ayraç -->
    <Style x:Key="Grup" TargetType="Border">
      <Setter Property="CornerRadius" Value="12"/><Setter Property="Background" Value="#1A212B"/>
      <Setter Property="BorderBrush" Value="#222A35"/><Setter Property="BorderThickness" Value="1"/>
    </Style>
    <Style x:Key="Ayrac" TargetType="Border">
      <Setter Property="Height" Value="1"/><Setter Property="Background" Value="#262F3B"/><Setter Property="Margin" Value="14,0,0,0"/>
    </Style>
    <Style x:Key="PencereDugme" TargetType="Button">
      <Setter Property="Width" Value="30"/><Setter Property="Height" Value="26"/><Setter Property="Foreground" Value="#E6FFFFFF"/><Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontFamily" Value="{StaticResource IkonFont}"/><Setter Property="FontSize" Value="10"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="13" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#26FFFFFF"/><Setter Property="Foreground" Value="White"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#40FFFFFF"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="KapatPencereDugme" TargetType="Button" BasedOn="{StaticResource PencereDugme}">
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="13" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#C42B1C"/><Setter Property="Foreground" Value="White"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#A32417"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <!-- Ana düğme: kapsül (HIG: yan yana düğmelerde kapsül), basınca hafif küçülür ve koyulaşır -->
    <Style x:Key="Birincil" TargetType="Button">
      <Setter Property="Background" Value="#1FBF62"/><Setter Property="Foreground" Value="#06210F"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/>
      <Setter Property="FontFamily" Value="{StaticResource Dar}"/><Setter Property="FontStretch" Value="SemiCondensed"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontSize" Value="17"/>
      <Setter Property="Height" Value="46"/><Setter Property="Padding" Value="24,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="23" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" RenderTransformOrigin="0.5,0.5">
          <Border.RenderTransform><ScaleTransform/></Border.RenderTransform>
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#29CC6E"/></Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="B" Property="Background" Value="#19A653"/>
            <Setter TargetName="B" Property="RenderTransform"><Setter.Value><ScaleTransform ScaleX="0.96" ScaleY="0.96"/></Setter.Value></Setter>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <!-- İkincil: çerçeve yerine gri dolgulu kapsül (HIG: tercih edileni boyutla değil stille ayır) -->
    <Style x:Key="Ikincil" TargetType="Button" BasedOn="{StaticResource Birincil}">
      <Setter Property="Foreground" Value="#ECE5D8"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="23" Background="#252E3A" BorderBrush="#2E3846" BorderThickness="1" Padding="{TemplateBinding Padding}" RenderTransformOrigin="0.5,0.5">
          <Border.RenderTransform><ScaleTransform/></Border.RenderTransform>
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#2D3745"/></Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="B" Property="Background" Value="#343F4E"/>
            <Setter TargetName="B" Property="RenderTransform"><Setter.Value><ScaleTransform ScaleX="0.96" ScaleY="0.96"/></Setter.Value></Setter>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Kucuk" TargetType="Button">
      <Setter Property="Foreground" Value="#ECE5D8"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/><Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Height" Value="28"/><Setter Property="Padding" Value="12,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="14" Padding="{TemplateBinding Padding}" Background="#232B36" RenderTransformOrigin="0.5,0.5">
          <Border.RenderTransform><ScaleTransform/></Border.RenderTransform>
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#2C3542"/></Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="B" Property="Background" Value="#343E4C"/>
            <Setter TargetName="B" Property="RenderTransform"><Setter.Value><ScaleTransform ScaleX="0.95" ScaleY="0.95"/></Setter.Value></Setter>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <!-- Anahtar: Apple oranlarında (iz 40x24, beyaz topuz, gölgeli). Kayma animasyonu kodda (Anahtar-Kaydir) -->
    <Style x:Key="Anahtar" TargetType="ToggleButton">
      <Setter Property="Width" Value="40"/><Setter Property="Height" Value="24"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/><Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ToggleButton">
        <Grid Background="#00000000">
          <Border x:Name="Iz" CornerRadius="12" Background="#3A4350"/>
          <Ellipse x:Name="Topuz" Width="20" Height="20" Fill="#F4F4F4" HorizontalAlignment="Left" Margin="2,0">
            <Ellipse.Effect><DropShadowEffect Color="Black" BlurRadius="4" ShadowDepth="1" Opacity="0.35"/></Ellipse.Effect>
          </Ellipse>
        </Grid>
        <ControlTemplate.Triggers>
          <Trigger Property="IsChecked" Value="True">
            <Setter TargetName="Iz" Property="Background" Value="#1FBF62"/>
            <Setter TargetName="Topuz" Property="Fill" Value="White"/><Setter TargetName="Topuz" Property="HorizontalAlignment" Value="Right"/>
          </Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Alan" TargetType="TextBox">
      <Setter Property="Foreground" Value="#ECE5D8"/><Setter Property="CaretBrush" Value="#ECE5D8"/><Setter Property="SelectionBrush" Value="#1FBF62"/>
      <Setter Property="FontSize" Value="12.5"/><Setter Property="Height" Value="30"/><Setter Property="Padding" Value="7,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox">
        <Border x:Name="K" CornerRadius="8" Background="#1C232D" BorderBrush="#2A333F" BorderThickness="1">
          <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="K" Property="BorderBrush" Value="#3A4452"/></Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="K" Property="BorderBrush" Value="#8C95A1"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Liste" TargetType="ListBox">
      <Setter Property="Focusable" Value="False"/><Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="#ECE5D8"/><Setter Property="FontSize" Value="13"/><Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
      <Setter Property="ItemContainerStyle"><Setter.Value><Style TargetType="ListBoxItem">
        <Setter Property="Focusable" Value="False"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Padding" Value="9,6"/>
        <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="B" CornerRadius="6" Padding="{TemplateBinding Padding}" Background="Transparent"><ContentPresenter/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#252E39"/></Trigger>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="B" Property="Background" Value="#2A3542"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate></Setter.Value></Setter>
      </Style></Setter.Value></Setter>
    </Style>
    <Style x:Key="InceKaydirma" TargetType="ScrollBar">
      <Setter Property="Width" Value="6"/><Setter Property="MinWidth" Value="6"/><Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border CornerRadius="3" Background="#3A4452"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
        </Track>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <!-- Cam kapsülün içindeki düğme: zemini cam verir, düğme yalnız üzerine gelince/basınca aydınlanır -->
    <Style x:Key="CamDugme" TargetType="Button" BasedOn="{StaticResource Kucuk}">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="B" CornerRadius="14" Padding="{TemplateBinding Padding}" Background="#00FFFFFF"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#1FFFFFFF"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#38FFFFFF"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Border CornerRadius="12" Background="#141A22">
      <Border.Effect><DropShadowEffect Color="Black" BlurRadius="24" ShadowDepth="4" Opacity="0.5"/></Border.Effect></Border>
    <Grid x:Name="Kok" Background="#141A22">
      <StackPanel>
        <!-- Kahraman: şampiyonun görseli, başlık çubuğu üstünde -->
        <Grid x:Name="Kahraman" Height="196" ClipToBounds="True" Background="#1C232D">
          <Image x:Name="KahramanResim" Stretch="UniformToFill" VerticalAlignment="Top" Margin="0,-8,0,0"/>
          <Border IsHitTestVisible="False"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#8C141A22" Offset="0"/><GradientStop Color="#00141A22" Offset="0.3"/>
            <GradientStop Color="#26141A22" Offset="0.55"/><GradientStop Color="#FF141A22" Offset="1"/></LinearGradientBrush></Border.Background></Border>
          <Border x:Name="KahramanKarart" Background="#A6141A22" Visibility="Collapsed" IsHitTestVisible="False"/>
          <Grid x:Name="BaslikCubugu" Height="38" VerticalAlignment="Top" Background="Transparent">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="12,0,0,0">
              <Image x:Name="BaslikLogo" Width="16" Height="16"/>
              <TextBlock Text="Riot Plus" Style="{StaticResource DarYazi}" FontSize="13.5" Foreground="White" Margin="8,0,0,1" VerticalAlignment="Center">
                <TextBlock.Effect><DropShadowEffect Color="Black" BlurRadius="6" ShadowDepth="0" Opacity="0.7"/></TextBlock.Effect></TextBlock>
            </StackPanel>
            <!-- Başlık kontrolleri tek cam kapsülde (HIG Toolbars: ilgili öğeleri grupla); dil iki parçalı seçici -->
            <Border x:Name="BaslikCam" Style="{StaticResource Cam}" CornerRadius="16" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,2,8,0">
              <Grid>
                <StackPanel Orientation="Horizontal" Margin="3">
                  <Border x:Name="DilTRKutu" Tag="tr" CornerRadius="13" Height="26" MinWidth="30" Padding="7,0" Cursor="Hand">
                    <TextBlock x:Name="DilTR" Text="TR" Tag="tr" FontSize="11.5" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                  <Border x:Name="DilENKutu" Tag="en" CornerRadius="13" Height="26" MinWidth="30" Padding="7,0" Cursor="Hand">
                    <TextBlock x:Name="DilEN" Text="EN" Tag="en" FontSize="11.5" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                  <Border Width="1" Height="14" Background="#33FFFFFF" Margin="5,0"/>
                  <Button x:Name="KucultDugme" Style="{StaticResource PencereDugme}" Content="&#xE921;"/>
                  <Button x:Name="KapatDugme" Style="{StaticResource KapatPencereDugme}" Content="&#xE8BB;"/>
                </StackPanel>
              </Grid>
            </Border>
          </Grid>
          <StackPanel VerticalAlignment="Bottom" Margin="16,0,16,12" IsHitTestVisible="False">
            <TextBlock x:Name="KahramanAd" Style="{StaticResource DarYazi}" FontSize="40" Foreground="#ECE5D8" TextTrimming="CharacterEllipsis"/>
            <TextBlock x:Name="KahramanNot" Foreground="#CFC8BC" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
          </StackPanel>
          <!-- "Görseli değiştir": cam kapsül; kapsül düğmenin görünürlüğünü izler -->
          <Border x:Name="GorselCam" Style="{StaticResource Cam}" CornerRadius="15" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,14,14"
                  Visibility="{Binding Visibility, ElementName=GorselDugme}">
            <Grid><Button x:Name="GorselDugme" Style="{StaticResource CamDugme}" Visibility="Collapsed" Margin="1"/></Grid>
          </Border>
          <!-- LTK güncelleme şeridi: yeni sürüm varken uygulama açık kaldıkça görünür (mesaj satırı gibi silinmez); cam kapsül -->
          <Border x:Name="GuncelleSerit" Style="{StaticResource Cam}" Visibility="Collapsed" Cursor="Hand" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,42,0,0" CornerRadius="14">
            <Grid>
              <StackPanel Orientation="Horizontal" Margin="11,5,12,6">
                <Ellipse Width="7" Height="7" Fill="#1FBF62" VerticalAlignment="Center" Margin="0,1,8,0"/>
                <TextBlock x:Name="GuncelleYazi" FontSize="12.5" Foreground="White" VerticalAlignment="Center"/>
                <TextBlock x:Name="GuncelleBaglanti" FontSize="12.5" FontWeight="SemiBold" Foreground="#3DDC84" VerticalAlignment="Center" Margin="10,0,0,0"/>
              </StackPanel>
            </Grid>
          </Border>
        </Grid>

        <!-- Sekmeler: bölümlü kontrol (HIG Segmented controls); seçili parçanın altındaki hap kayarak geçer -->
        <Border Margin="16,2,16,4" Height="34" CornerRadius="17" Background="#1A212B" BorderBrush="#232B36" BorderThickness="1" Padding="2">
          <Grid>
            <Border x:Name="SekmeHap" HorizontalAlignment="Left" CornerRadius="15" Background="#2B3541" BorderBrush="#394555" BorderThickness="1">
              <Border.Effect><DropShadowEffect Color="Black" BlurRadius="6" ShadowDepth="1" Opacity="0.35"/></Border.Effect>
            </Border>
            <UniformGrid x:Name="Sekmeler" Rows="1"/>
          </Grid>
        </Border>

        <!-- Sayfalar: ana sayfa ve Custom sayfası aynı yerde; görünmeyen Hidden kalır, pencere boyu sabit -->
        <Grid>
        <StackPanel x:Name="AnaSayfa">
        <!-- Ana eylem -->
        <Grid Margin="16,12,16,8">
          <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Button x:Name="AnaDugme" Style="{StaticResource Birincil}"><TextBlock x:Name="AnaDugmeYazi"/></Button>
          <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
            <TextBlock x:Name="SiraSecim" Style="{StaticResource Baglanti}" Foreground="#ECE5D8"/>
            <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
              <TextBlock x:Name="Rol1Secim" Style="{StaticResource Baglanti}" Foreground="#8C95A1"/>
              <TextBlock x:Name="RolAra" Foreground="#8C95A1"/>
              <TextBlock x:Name="Rol2Secim" Style="{StaticResource Baglanti}" Foreground="#8C95A1"/>
            </StackPanel>
          </StackPanel>
        </Grid>
        <TextBlock x:Name="HalYazi" Margin="16,0,16,12" Foreground="#8C95A1" TextWrapping="Wrap"/>

        <!-- Bölümler gruplu kartlarda (HIG Lists and tables: inset grouped; Layout: ilgili öğeleri grupla).
             Başlık, kart içindeki satır yazısıyla aynı hizada; satırlar arasında soldan girintili ince ayraç. -->
        <Grid>
          <StackPanel x:Name="AnaGorunum" Margin="16,0,16,10">
            <TextBlock x:Name="SecimBaslik" Style="{StaticResource BolumBaslik}" Margin="14,0,0,6"/>
            <Border Style="{StaticResource Grup}">
              <StackPanel>
                <Grid MinHeight="44" Margin="14,0,12,0">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <TextBlock x:Name="KabulAd" VerticalAlignment="Center"/>
                  <TextBlock x:Name="KabulNot" Grid.Column="1" Foreground="#8C95A1" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="0,0,8,0"/>
                  <ToggleButton x:Name="AnahtarKabul" Grid.Column="2" Style="{StaticResource Anahtar}" Tag="kabul"/>
                </Grid>
                <Border Style="{StaticResource Ayrac}"/>
                <Grid MinHeight="54" Margin="14,0,12,0">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <TextBlock x:Name="BanAd" VerticalAlignment="Center"/>
                  <StackPanel x:Name="BanPortreler" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"/>
                  <ToggleButton x:Name="AnahtarBan" Grid.Column="2" Style="{StaticResource Anahtar}" Tag="ban"/>
                </Grid>
                <Border Style="{StaticResource Ayrac}"/>
                <Grid MinHeight="54" Margin="14,0,12,0">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel VerticalAlignment="Center"><TextBlock x:Name="OynaAd"/><TextBlock x:Name="OynaRol" FontSize="11.5" Foreground="#8C95A1"/></StackPanel>
                  <StackPanel x:Name="OynaPortreler" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"/>
                  <ToggleButton x:Name="AnahtarPick" Grid.Column="2" Style="{StaticResource Anahtar}" Tag="pick"/>
                </Grid>
                <Border Style="{StaticResource Ayrac}"/>
                <Grid MinHeight="44" Margin="14,0,12,0">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <TextBlock x:Name="CustomAd" VerticalAlignment="Center"/>
                  <TextBlock x:Name="CustomNot" Grid.Column="1" Style="{StaticResource Baglanti}" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="0,0,8,0"/>
                  <ToggleButton x:Name="AnahtarCustom" Grid.Column="2" Style="{StaticResource Anahtar}" Tag="custom"/>
                </Grid>
              </StackPanel>
            </Border>
            <TextBlock x:Name="SorunBaslik" Style="{StaticResource BolumBaslik}" Margin="14,14,0,6"/>
            <Border Style="{StaticResource Grup}">
              <StackPanel x:Name="SorunPanel"/>
            </Border>
          </StackPanel>
        </Grid>
        </StackPanel>

          <!-- Rol listeleri sayfası -->
          <Border x:Name="Duzenleyici" Visibility="Hidden" Background="#141A22" Padding="16,14,16,10" Height="{Binding ActualHeight, ElementName=AnaSayfa}">
            <StackPanel>
              <Grid x:Name="DuzenleTablo">
                <Grid.ColumnDefinitions><ColumnDefinition Width="60"/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/></Grid.RowDefinitions>
              </Grid>
              <Grid Margin="0,8,0,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                  <ToggleButton x:Name="AnahtarKilitle" Style="{StaticResource Anahtar}" Tag="kilitle"/>
                  <TextBlock x:Name="KilitleYazi" Margin="10,0,0,0" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                  <TextBlock x:Name="BekleYazi" Foreground="#8C95A1" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <Button x:Name="BekleEksi" Style="{StaticResource Kucuk}" Content="−" Width="28" Padding="0"/>
                  <TextBlock x:Name="BekleDeger" Style="{StaticResource DarYazi}" FontSize="15" Width="30" TextAlignment="Center" VerticalAlignment="Center"/>
                  <Button x:Name="BekleArti" Style="{StaticResource Kucuk}" Content="+" Width="28" Padding="0"/>
                </StackPanel>
              </Grid>
              <TextBlock x:Name="DuzenleNot" Foreground="#8C95A1" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,0"/>
            </StackPanel>
          </Border>

        <!-- Custom sayfası: üstteki görsel sayfada seçili şampiyonun custom'ını gösterir; şampiyon şeridi + seçenek kartları -->
        <Border x:Name="CustomGorunum" Visibility="Hidden" Background="#141A22" AllowDrop="True" Height="{Binding ActualHeight, ElementName=AnaSayfa}">
          <DockPanel Margin="16,12,16,10">
            <!-- Kaynak: custom'ı kim uygular. LTK Manager = kendi eklediğin modlar (Riot Plus yönetir); Rose = Rose yönetir -->
            <Border DockPanel.Dock="Top" Height="30" CornerRadius="15" Background="#1A212B" BorderBrush="#232B36" BorderThickness="1" Padding="2" Margin="0,0,0,10">
              <UniformGrid Rows="1">
                <Border x:Name="KaynakLtk" CornerRadius="13" BorderThickness="1" Cursor="Hand" Tag="ltk">
                  <TextBlock x:Name="KaynakLtkYazi" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="12.5" FontWeight="SemiBold" Text="LTK Manager"/>
                </Border>
                <Border x:Name="KaynakRose" CornerRadius="13" BorderThickness="1" Cursor="Hand" Tag="rose">
                  <TextBlock x:Name="KaynakRoseYazi" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="12.5" FontWeight="SemiBold" Text="Rose"/>
                </Border>
              </UniformGrid>
            </Border>
            <!-- Rose kipi: mod listesi yerine Rose'un durumu ve başlat / durdur -->
            <StackPanel x:Name="RosePanel" DockPanel.Dock="Top" Visibility="Collapsed">
              <TextBlock x:Name="RoseAciklama" FontSize="12.5" Foreground="#8C95A1" TextWrapping="Wrap" Margin="0,0,0,10"/>
              <Border Style="{StaticResource Grup}" Margin="0,0,0,8">
                <Grid Margin="14,10,12,11">
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
                    <TextBlock x:Name="RoseDurumYazi" FontWeight="SemiBold"/>
                    <TextBlock x:Name="RoseDurumNot" FontSize="11.5" Foreground="#8C95A1" TextWrapping="Wrap" Margin="0,2,0,0"/>
                  </StackPanel>
                  <Button x:Name="RoseDugme" Grid.Column="1" Style="{StaticResource Kucuk}" VerticalAlignment="Center"/>
                </Grid>
              </Border>
              <TextBlock x:Name="RoseUyari" FontSize="11.5" Foreground="#8C95A1" TextWrapping="Wrap" Margin="2,2,2,0"/>
            </StackPanel>
            <ScrollViewer x:Name="SampiyonKaydir" DockPanel.Dock="Top" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" Focusable="False" Margin="-4,0,-4,8">
              <StackPanel x:Name="SampiyonSerit" Orientation="Horizontal" Margin="4"/>
            </ScrollViewer>
            <StackPanel x:Name="LtkAlt" DockPanel.Dock="Bottom" Margin="0,8,0,0">
              <!-- Custom'lar rakiplerde de görünsün mü (kapalıyken maçta yalnız oynadığın şampiyonunki açık) -->
              <Border Style="{StaticResource Grup}" Margin="0,0,0,8">
                <Grid Margin="14,8,12,9">
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
                    <TextBlock x:Name="RakipYazi"/>
                    <TextBlock x:Name="RakipNot" FontSize="11.5" Foreground="#8C95A1" TextWrapping="Wrap" Margin="0,2,0,0"/>
                  </StackPanel>
                  <ToggleButton x:Name="AnahtarRakip" Grid.Column="1" Style="{StaticResource Anahtar}" Tag="customRakip"/>
                </Grid>
              </Border>
              <!-- Riot Plus kapanınca LTK Manager da kapansın mı -->
              <Border Style="{StaticResource Grup}" Margin="0,0,0,8">
                <Grid Margin="14,8,12,9">
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
                    <TextBlock x:Name="LtkKapatYazi"/>
                    <TextBlock x:Name="LtkKapatNot" FontSize="11.5" Foreground="#8C95A1" TextWrapping="Wrap" Margin="0,2,0,0"/>
                  </StackPanel>
                  <ToggleButton x:Name="AnahtarLtkKapat" Grid.Column="1" Style="{StaticResource Anahtar}" Tag="ltkKapat"/>
                </Grid>
              </Border>
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="ModEkle" Style="{StaticResource Kucuk}"/>
                  <Button x:Name="LtkAc" Style="{StaticResource Kucuk}" Margin="6,0,0,0"/>
                  <Button x:Name="RoseAktar" Style="{StaticResource Kucuk}" Margin="6,0,0,0"/>
                </StackPanel>
                <TextBlock x:Name="LtkGuncelle" Style="{StaticResource Baglanti}" Foreground="#1FBF62" FontSize="12.5" HorizontalAlignment="Right" VerticalAlignment="Center" Visibility="Collapsed"/>
              </Grid>
              <TextBlock x:Name="CustomBilgi" Foreground="#8C95A1" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"/>
            </StackPanel>
            <ScrollViewer x:Name="CustomKaydir" VerticalScrollBarVisibility="Auto" Focusable="False" Margin="-8,0,-8,0">
              <ScrollViewer.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource InceKaydirma}"/></ScrollViewer.Resources>
              <StackPanel x:Name="CustomListe" Margin="8,0"/>
            </ScrollViewer>
          </DockPanel>
        </Border>

        </Grid>

        <!-- Son mesaj -->
        <Border x:Name="MesajKutu" BorderBrush="#2A333F" BorderThickness="0,1,0,0" Padding="16,10,16,12" Background="Transparent">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="16"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <Image x:Name="MesajLogo" Width="16" Height="16" VerticalAlignment="Top" Margin="0,1,0,0"/>
            <TextBlock x:Name="MesajYazi" Grid.Column="1" Margin="9,0,10,0" TextWrapping="Wrap" TextTrimming="CharacterEllipsis" MaxHeight="38" Foreground="#CFC8BC"/>
            <TextBlock x:Name="MesajSaat" Grid.Column="2" Foreground="#8C95A1" FontSize="12" VerticalAlignment="Top" Margin="0,1,0,0"/>
          </Grid>
        </Border>
      </StackPanel>

      <!-- Açılır menüler: yuvarlak köşe + gölge (kenar boşluğu gölgeye yer açar, HorizontalOffset hizayı korur) -->
      <Popup x:Name="SecimMenu" AllowsTransparency="True" Placement="Bottom" StaysOpen="False" Focusable="False" HorizontalOffset="-10">
        <Border Background="#1E2630" BorderBrush="#303A47" BorderThickness="1" CornerRadius="10" Margin="10,4,10,14" Padding="4" MinWidth="150">
          <Border.Effect><DropShadowEffect Color="Black" BlurRadius="14" ShadowDepth="3" Opacity="0.45"/></Border.Effect>
          <ListBox x:Name="SecimListe" Style="{StaticResource Liste}"/></Border>
      </Popup>
      <Popup x:Name="OneriPopup" AllowsTransparency="True" Placement="Bottom" StaysOpen="False" Focusable="False" HorizontalOffset="-10">
        <Border Background="#1E2630" BorderBrush="#303A47" BorderThickness="1" CornerRadius="10" Margin="10,3,10,14" Padding="4">
          <Border.Effect><DropShadowEffect Color="Black" BlurRadius="14" ShadowDepth="3" Opacity="0.45"/></Border.Effect>
          <ListBox x:Name="OneriListe" Style="{StaticResource Liste}"/></Border>
      </Popup>
    </Grid>
  </Grid>
</Window>
'@

$Pencere = [Windows.Markup.XamlReader]::Parse($PencereXaml)
function Bul($ad) { $Pencere.FindName($ad) }
foreach ($ad in 'Kok', 'Kahraman', 'KahramanResim', 'KahramanKarart', 'KahramanAd', 'KahramanNot', 'BaslikCubugu', 'BaslikLogo', 'DilTR', 'DilEN', 'KucultDugme', 'KapatDugme',
                 'AnaDugme', 'AnaDugmeYazi', 'SiraSecim', 'Rol1Secim', 'RolAra', 'Rol2Secim', 'HalYazi',
                 'AnaGorunum', 'SecimBaslik', 'KabulAd', 'KabulNot', 'AnahtarKabul', 'BanAd', 'BanPortreler', 'AnahtarBan', 'OynaAd', 'OynaRol', 'OynaPortreler', 'AnahtarPick', 'Sekmeler',
                 'SorunPanel', 'SorunBaslik', 'Duzenleyici', 'DuzenleTablo', 'AnahtarKilitle', 'KilitleYazi', 'BekleYazi', 'BekleEksi', 'BekleDeger', 'BekleArti', 'DuzenleNot',
                 'MesajKutu', 'MesajLogo', 'MesajYazi', 'MesajSaat', 'SecimMenu', 'SecimListe', 'OneriPopup', 'OneriListe',
                 'CustomAd', 'CustomNot', 'AnahtarCustom', 'CustomGorunum', 'CustomKaydir', 'CustomListe',
                 'ModEkle', 'LtkAc', 'LtkGuncelle', 'CustomBilgi', 'AnaSayfa', 'SampiyonKaydir', 'SampiyonSerit', 'GorselDugme',
                 'GuncelleSerit', 'GuncelleYazi', 'GuncelleBaglanti', 'SekmeHap', 'BaslikCam', 'DilTRKutu', 'DilENKutu', 'GorselCam', 'RakipYazi', 'RakipNot', 'AnahtarRakip', 'LtkKapatYazi', 'LtkKapatNot', 'AnahtarLtkKapat',
                 'KaynakLtk', 'KaynakLtkYazi', 'KaynakRose', 'KaynakRoseYazi', 'RosePanel', 'RoseAciklama', 'RoseDurumYazi', 'RoseDurumNot', 'RoseDugme', 'RoseUyari', 'LtkAlt', 'RoseAktar') {
    Set-Variable -Name $ad -Value (Bul $ad) -Scope Script
}
$Pencere.Title = $Baslik
try { $Pencere.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri($IkonYolu))) } catch {}
try {
    $logo = New-Object Windows.Media.Imaging.BitmapImage
    $logo.BeginInit(); $logo.UriSource = New-Object Uri($LogoYolu); $logo.CacheOption = 'OnLoad'; $logo.EndInit()
    $BaslikLogo.Source = $logo; $MesajLogo.Source = $logo
} catch {}
# Köşeler yuvarlak kırpılır (WPF ClipToBounds köşe yarıçapını bilmez)
$Kok.Add_SizeChanged({ $this.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, $this.ActualWidth, $this.ActualHeight)), 12, 12) })

# ---- Hareket ve cam (Apple HIG uyarlaması, 7 Kas 2026) ----
# Animasyon: Windows'ta animasyonlar kapalıysa ya da resim alınırken (-Sessiz) hareket yok, son hal anında gelir.
$script:Hareket = (-not $Sessiz) -and [Windows.SystemParameters]::ClientAreaAnimation
function Kaydir-Anim([double]$baslangic, [double]$bitis, [int]$ms) {
    $a = New-Object Windows.Media.Animation.DoubleAnimation($baslangic, $bitis, (New-Object Windows.Duration([TimeSpan]::FromMilliseconds($ms))))
    $kolay = New-Object Windows.Media.Animation.CubicEase; $kolay.EasingMode = 'EaseOut'; $a.EasingFunction = $kolay
    return $a
}
# Anahtar: son konum şablondaki tetikleyiciden gelir (hep doğru); kullanıcı ya da kod değiştirince topuz eski
# yerinden kayarak gelir. Animasyon bitince durur (FillBehavior Stop), yani asıl değer hiç bozulmaz.
function Anahtar-Kaydir($k, [int]$yon) {
    if (-not $script:Hareket -or -not ($k -is [Windows.Controls.Primitives.ToggleButton]) -or -not $k.IsLoaded) { return }
    try {
        $topuz = $k.Template.FindName('Topuz', $k)
        if (-not $topuz) { return }
        if (-not ($topuz.RenderTransform -is [Windows.Media.TranslateTransform]) -or $topuz.RenderTransform.IsFrozen) { $topuz.RenderTransform = New-Object Windows.Media.TranslateTransform }
        $mesafe = $k.ActualWidth - $topuz.Width - 4
        $a = Kaydir-Anim (-$yon * $mesafe) 0 180
        $a.FillBehavior = 'Stop'
        $topuz.RenderTransform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $a)
    } catch {}
}
$Pencere.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler]{ Anahtar-Kaydir $_.OriginalSource 1 })
$Pencere.AddHandler([Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, [Windows.RoutedEventHandler]{ Anahtar-Kaydir $_.OriginalSource -1 })

# Cam (Liquid Glass benzeri): kapsülün arkasına şampiyon görselinin bulanık bir kopyası konur, üstüne koyu bir
# renk katmanı ve hafif üst parıltı gelir. Görsel değişince kopya da kendiliğinden değişir (VisualBrush canlıdır).
function Cam-Arka($kapsul) {
    try {
        $ic = $kapsul.Child
        $r = [double]$kapsul.CornerRadius.TopLeft
        $bulanik = New-Object Windows.Shapes.Rectangle
        $bulanik.Margin = '-24'; $bulanik.IsHitTestVisible = $false
        $firca = New-Object Windows.Media.VisualBrush($KahramanResim)
        $firca.ViewboxUnits = 'Absolute'; $firca.Stretch = 'Fill'
        $bulanik.Fill = $firca
        $bulanik.Effect = New-Object Windows.Media.Effects.BlurEffect
        $bulanik.Effect.Radius = 16
        $renk = New-Object Windows.Shapes.Rectangle
        $renk.Fill = Firca '#8C141A22'; $renk.IsHitTestVisible = $false
        $parilti = New-Object Windows.Shapes.Rectangle
        $parilti.Fill = $Pencere.FindResource('CamParilti'); $parilti.IsHitTestVisible = $false
        $ic.Children.Insert(0, $parilti); $ic.Children.Insert(0, $renk); $ic.Children.Insert(0, $bulanik)
        $guncelle = {
            param($kp, $ic, $firca, $r)
            if ($ic.ActualWidth -le 0) { return }
            $ic.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, $ic.ActualWidth, $ic.ActualHeight)), [Math]::Max(0, $r - 1), [Math]::Max(0, $r - 1))
            try {
                $p = $ic.TranslatePoint((New-Object Windows.Point(-24, -24)), $KahramanResim)
                # Parantez şart: PowerShell'de virgül + 'dan önce bağlanır, yoksa 6 öğeli dizi gider
                $firca.Viewbox = New-Object Windows.Rect($p.X, $p.Y, ($ic.ActualWidth + 48), ($ic.ActualHeight + 48))
            } catch {}
        }
        $is = @{ Kp = $kapsul; Ic = $ic; Firca = $firca; R = $r; Is = $guncelle }
        $ic.Tag = $is
        $ic.Add_SizeChanged({ $t = $this.Tag; & $t.Is $t.Kp $t.Ic $t.Firca $t.R })
        [void]$script:Camlar.Add($is)
    } catch {}
}
$script:Camlar = New-Object Collections.ArrayList
function Camlari-Hizala { foreach ($t in $script:Camlar) { & $t.Is $t.Kp $t.Ic $t.Firca $t.R } }
foreach ($kp in $BaslikCam, $GorselCam, $GuncelleSerit) { Cam-Arka $kp }
$Kahraman.Add_SizeChanged({ Camlari-Hizala })

# Tıklama yalnız basışın başladığı öğede sayılır. 4 Kas: açılır menüde seçim yapılınca menü kapanırken
# alttaki "Ekrana gelmiyor" satırı da bırakmayı aldı ve LoL'ü açtı; bu kontrol öyle "hayalet" tıkları yok sayar.
$script:BasmaKaynagi = $null
$Pencere.Add_PreviewMouseLeftButtonDown({ $script:BasmaKaynagi = $_.OriginalSource })
$Pencere.AddHandler([Windows.UIElement]::MouseLeftButtonUpEvent, [Windows.Input.MouseButtonEventHandler]{ $script:BasmaKaynagi = $null }, $true)
function Basildi($o) {
    $k = $script:BasmaKaynagi
    while ($k) {
        if ([object]::ReferenceEquals($k, $o)) { return $true }
        $k = if ($k -is [Windows.Media.Visual]) { [Windows.Media.VisualTreeHelper]::GetParent($k) } else { [Windows.LogicalTreeHelper]::GetParent($k) }
    }
    return $false
}

# Dil değişince yazısı yenilenecek öğeler
$script:Ceviriler = New-Object Collections.ArrayList
function Metin-Ata($o, [string]$metin) {
    if ($o -is [Windows.Controls.TextBlock]) { $o.Text = $metin }
    elseif ($o -is [Windows.Controls.ContentControl]) { $o.Content = $metin }
    else { $o.Text = $metin }   # WinForms tepsi menüsü öğesi
}
function Cevir($o, [string]$tr, [string]$en) {
    Metin-Ata $o (T $tr $en)
    [void]$script:Ceviriler.Add(@{ K = $o; Tr = $tr; En = $en })
}
function Ceviri-Degistir($o, [string]$tr, [string]$en) {
    foreach ($c in $script:Ceviriler) { if ([object]::ReferenceEquals($c.K, $o)) { $c.Tr = $tr; $c.En = $en } }
    Metin-Ata $o (T $tr $en)
}
$script:Ipuclari = New-Object Collections.ArrayList
function Ipucu-Ver($o, [string]$tr, [string]$en) {
    $o.ToolTip = T $tr $en
    [void]$script:Ipuclari.Add(@{ K = $o; Tr = $tr; En = $en })
}

# ---- Başlık çubuğu ----
$BaslikCubugu.Add_MouseLeftButtonDown({ if ($_.ClickCount -eq 1) { try { $Pencere.DragMove() } catch {} } })
$KucultDugme.Add_Click({ $Pencere.WindowState = 'Minimized' })
$KapatDugme.Add_Click({ $Pencere.Close() })
Ipucu-Ver $KucultDugme 'Küçült; çalışmaya devam eder' 'Minimize; keeps working'
Ipucu-Ver $KapatDugme "Riot Plus'ı kapat" 'Close Riot Plus'
# Dil yazıları başlık çubuğunun içinde: basış sürükleme başlatmasın diye olay burada tüketilir
foreach ($d in $DilTRKutu, $DilENKutu) {
    $d.Background = Firca '#00FFFFFF'
    $d.Add_MouseLeftButtonDown({ $_.Handled = $true; Dil-Sec $this.Tag })
    $d.Add_MouseEnter({ if ($this.Tag -ne $script:Dil) { $this.Background = Firca '#1AFFFFFF' } })
    $d.Add_MouseLeave({ Dil-Boya })
}
function Dil-Boya {
    foreach ($p in @(@($DilTR, $DilTRKutu, 'tr'), @($DilEN, $DilENKutu, 'en'))) {
        $aktif = $p[2] -eq $script:Dil
        $p[0].Foreground = Firca $(if ($aktif) { '#FFFFFFFF' } else { '#B3FFFFFF' })
        $p[0].FontWeight = if ($aktif) { 'SemiBold' } else { 'Normal' }
        $p[1].Background = Firca $(if ($aktif) { '#33FFFFFF' } else { '#00FFFFFF' })
    }
}
Dil-Boya

# ---- Sekmeler: Ana sayfa / Rol listeleri / Custom skinler ----
# Üç sayfa aynı yerde durur (görünmeyen Hidden, pencere boyu sabit). Sekmeler bölümlü kontrol: eşit genişlikte
# üç parça, seçilinin altındaki hap (SekmeHap) seçim değişince kayarak yeni parçaya geçer.
$script:Sekme = 'ana'
$script:SekmeOgeleri = [ordered]@{}
function Sekme-Olustur($ad, $tr, $en) {
    $g = New-Object Windows.Controls.Grid
    $g.Cursor = 'Hand'; $g.Background = Firca '#00000000'; $g.Tag = $ad
    $t = New-Object Windows.Controls.TextBlock
    $t.VerticalAlignment = 'Center'; $t.HorizontalAlignment = 'Center'; $t.FontSize = 13; $t.FontWeight = 'SemiBold'
    Cevir $t $tr $en
    [void]$g.Children.Add($t)
    $g.Add_MouseEnter({ if ($this.Tag -ne $script:Sekme) { $script:SekmeOgeleri[$this.Tag].Yazi.Foreground = Firca '#FFFFFF' } })
    $g.Add_MouseLeave({ Sekme-Boya })
    $g.Add_MouseLeftButtonUp({ if (Basildi $this) { Sekme-Sec $this.Tag } })
    [void]$Sekmeler.Children.Add($g)
    $script:SekmeOgeleri[$ad] = @{ Kok = $g; Yazi = $t }
}
function Sekme-Boya {
    foreach ($ad in $script:SekmeOgeleri.Keys) {
        $o = $script:SekmeOgeleri[$ad]; $aktif = $ad -eq $script:Sekme
        $o.Yazi.Foreground = Firca $(if ($aktif) { '#FFFFFF' } else { $RenkSoluk })
    }
}
# Hap: genişliği bir parça kadar; konumu seçili parçanın sırası. $kaydir yoksa (ilk açılış, boy değişimi) anında yerleşir.
function Hap-Tasi([bool]$kaydir) {
    $n = $Sekmeler.Children.Count
    if (-not $n -or $Sekmeler.ActualWidth -le 0) { return }
    $gen = $Sekmeler.ActualWidth / $n
    $sira = [Array]::IndexOf([object[]]@($script:SekmeOgeleri.Keys), $script:Sekme)
    $SekmeHap.Width = $gen
    if (-not ($SekmeHap.RenderTransform -is [Windows.Media.TranslateTransform]) -or $SekmeHap.RenderTransform.IsFrozen) { $SekmeHap.RenderTransform = New-Object Windows.Media.TranslateTransform }
    $tt = $SekmeHap.RenderTransform
    $hedef = $sira * $gen
    if ($kaydir -and $script:Hareket) {
        # Okunan X, animasyon sürüyorsa o anki konumdur; asıl değer hedefe yazılır, animasyon bitince orada kalır
        $a = Kaydir-Anim $tt.X $hedef 240
        $a.FillBehavior = 'Stop'
        $tt.X = $hedef
        $tt.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $a)
    } else { $tt.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $null); $tt.X = $hedef }
}
$Sekmeler.Add_SizeChanged({ Hap-Tasi $false })
function Sekme-Sec($ad) {
    $SecimMenu.IsOpen = $false; $OneriPopup.IsOpen = $false
    $onceki = $script:Sekme
    $script:Sekme = $ad
    Hap-Tasi ($onceki -ne $ad)
    $AnaSayfa.Visibility = if ($ad -eq 'ana') { 'Visible' } else { 'Hidden' }
    $Duzenleyici.Visibility = if ($ad -eq 'roller') { 'Visible' } else { 'Hidden' }
    $CustomGorunum.Visibility = if ($ad -eq 'custom') { 'Visible' } else { 'Hidden' }
    Sekme-Boya
    if ($ad -eq 'roller') {
        # Kutular genişliği belli olmadan doldurulunca yazı sona kaymış kalıyor; başa alınır
        $Duzenleyici.UpdateLayout()
        foreach ($c in $script:Seciciler) { $c.CaretIndex = 0; $c.ScrollToHorizontalOffset(0) }
    }
    if ($ad -eq 'custom') { try { Ltk-Oku } catch {}; Custom-Liste-Olustur; $CustomKaydir.ScrollToTop() }
    $script:KahramanKod = $null
    Gorunum-Guncelle
}
Sekme-Olustur 'ana' 'Ana sayfa' 'Home'
Sekme-Olustur 'roller' 'Rol listeleri' 'Role lists'
Sekme-Olustur 'custom' 'Custom skinler' 'Custom skins'
Sekme-Boya

# ---- Seçim menüsü (sıra ve rol yazılarına tıklayınca) ----
$script:MenuSonra = $null
function Menu-Ac($hedef, $ogeler, [scriptblock]$sonra) {
    $SecimListe.Items.Clear()
    foreach ($o in $ogeler) {
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = $o.Metin; $t.Tag = $o.Deger
        if ($o.Secili) { $t.FontWeight = 'SemiBold'; $t.Foreground = Firca '#FFFFFF' }
        [void]$SecimListe.Items.Add($t)
    }
    $script:MenuSonra = $sonra
    $SecimMenu.PlacementTarget = $hedef
    $SecimMenu.IsOpen = $true
}
$SecimListe.Add_PreviewMouseLeftButtonUp({
    $e = $_.OriginalSource
    try { while ($e -and -not ($e -is [Windows.Controls.ListBoxItem])) { $e = [Windows.Media.VisualTreeHelper]::GetParent($e) } } catch { $e = $null }
    if (-not $e) { return }
    $_.Handled = $true
    $script:MenuDeger = $e.Content.Tag
    $SecimMenu.IsOpen = $false
    # Seçimin işi bu tıklama olayı bittikten sonra çalışır (uzun işler olayın içinde mesaj pompalamasın)
    if ($script:MenuSonra) { [void]$Pencere.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, [Action]{ if ($script:MenuSonra) { & $script:MenuSonra $script:MenuDeger } }) }
})

function Rol1-Ata($yeni) {
    $eski = [string]$Ayar.rol1
    $Ayar.rol1 = $yeni
    if ($yeni -and $yeni -ne 'FILL' -and $yeni -eq $Ayar.rol2) { $Ayar.rol2 = if ($eski -and $eski -ne 'FILL') { $eski } else { 'FILL' } }
    Ayar-Kaydet; Gorunum-Guncelle
}
function Rol2-Ata($yeni) {
    $eski = [string]$Ayar.rol2
    if ($yeni -ne 'FILL' -and $yeni -eq $Ayar.rol1) {
        if ($eski -eq 'FILL') { return }   # 1. rol 2.'ye taşınamaz (boş kalırdı)
        $Ayar.rol1 = $eski
    }
    $Ayar.rol2 = $yeni
    Ayar-Kaydet; Gorunum-Guncelle
}
$SiraSecim.Add_MouseLeftButtonUp({
    if (-not (Basildi $this)) { return }
    Menu-Ac $SiraSecim @($SiraListesi | ForEach-Object { @{ Metin = (T $_.Tr $_.En); Deger = $_.Id; Secili = ($_.Id -eq [int]$Ayar.sira) } }) { param($d) $Ayar.sira = [int]$d; Ayar-Kaydet; Gorunum-Guncelle }
})
$Rol1Secim.Add_MouseLeftButtonUp({
    if (-not (Basildi $this)) { return }
    if ([int]$Ayar.sira -eq 450) { return }
    Menu-Ac $Rol1Secim @($Rol1Kodlar | ForEach-Object { @{ Metin = (Rol-Kod-Adi $_); Deger = $_; Secili = ($_ -eq [string]$Ayar.rol1) } }) { param($d) Rol1-Ata ([string]$d) }
})
$Rol2Secim.Add_MouseLeftButtonUp({
    if (-not (Basildi $this)) { return }
    Menu-Ac $Rol2Secim @($Rol2Kodlar | ForEach-Object { @{ Metin = (Rol-Kod-Adi $_); Deger = $_; Secili = ($_ -eq [string]$Ayar.rol2) } }) { param($d) Rol2-Ata ([string]$d) }
})
Ipucu-Ver $SiraSecim 'Hangi sıraya girilsin; değiştirmek için tıkla' 'Which queue to join; click to change'
Ipucu-Ver $Rol1Secim "Ana rol; değiştirmek için tıkla. Client'taki roller: client'ta seçili olana dokunmaz." "Main role; click to change. Client's roles: keep what's set in the client."
Ipucu-Ver $Rol2Secim 'Yedek rol; değiştirmek için tıkla' 'Backup role; click to change'

# ---- Rol ve kahraman yardımcıları ----
function Rol-Kodundan($kod) { switch ("$kod") { 'TOP' { 'top' } 'JUNGLE' { 'jungle' } 'MIDDLE' { 'middle' } 'BOTTOM' { 'bottom' } 'UTILITY' { 'utility' } default { $null } } }
# Oyna satırı ve kahraman için geçerli rol: seçimde atanan rol, değilse ana rol (client'taki roller seçiliyse lobideki tercih)
function Aktif-Rol {
    if ($script:SonFaz -eq 'ChampSelect' -and $script:SecimBilgi) { return $script:SecimBilgi.Rol }
    $r = Rol-Kodundan $Ayar.rol1
    if (-not $r -and -not $Ayar.rol1) { $r = Rol-Kodundan $script:LobiRol1 }
    if ($r) { return $r } else { return 'genel' }
}
function Rol-Listesi($rol) {
    $l = @($Ayar.pickListe[$rol])
    if (-not @($l | Where-Object { $_ -gt 0 }).Count -and $rol -ne 'genel') { $l = @($Ayar.pickListe['genel']) }
    return ,$l
}
function Varsayilan-Sampiyon {
    $rol = Aktif-Rol
    $id = @($Ayar.pickListe[$rol]) | Where-Object { $_ -gt 0 } | Select-Object -First 1
    if ($id) { return @{ Id = [int]$id; Not = $(if ($rol -ne 'genel') { T "$(Rol-Adi $rol) için ilk tercihin" "Your first pick for $(Rol-Adi $rol)" } else { T 'İlk tercihin' 'Your first pick' }) } }
    $id = @($Ayar.pickListe['genel']) | Where-Object { $_ -gt 0 } | Select-Object -First 1
    if ($id) { return @{ Id = [int]$id; Not = T 'Rolsüz listende ilk sırada' 'First on your any-role list' } }
    return @{ Id = 0; Not = T 'Rol listene şampiyon ekleyince burada görünür.' 'Add champions to your role list to see them here.' }
}

# ---- Görünüm: kahraman, ana düğme, rol yazısı, durum cümlesi, portreler ----
$script:KahramanKod = $null
function Kahraman-Guncelle {
    $faz = $script:SonFaz
    $v = Varsayilan-Sampiyon
    $id = $v.Id; $buyuk = 40; $karart = $false
    if ($faz -eq 'Matchmaking') {
        $s = $script:SiraDurum
        $ad = Sure-Kisa $(if ($s) { $s.Sure } else { 0 }); $buyuk = 58; $karart = $true
        $sira = Sira-Adi $Ayar.sira
        $not = if ($s -and $s.Tahmini -gt 0) { T "$sira aranıyor, tahmini $(Sure-Kisa $s.Tahmini)" "Searching $sira, estimated $(Sure-Kisa $s.Tahmini)" } else { T "$sira aranıyor" "Searching $sira" }
    } elseif ($faz -eq 'ReadyCheck') {
        $ad = T 'Maç bulundu' 'Match found'; $karart = $true
        $not = if ($script:HazirYanit -eq 'Accepted') { T 'Kabul ettim, diğerleri bekleniyor.' 'Accepted, waiting for the others.' } elseif ($script:HazirYanit -eq 'Declined') { T 'Reddettin.' 'You declined.' } else { T "Kabul etmek için client'a bak." 'Accept it in the client.' }
    } elseif ($faz -eq 'ChampSelect') {
        $b = $script:SecimBilgi
        $kalan = if ($b) { [Math]::Max(0, [int][Math]::Ceiling($b.Kalan)) } else { 0 }
        $rolAd = if ($b -and $b.Rol -ne 'genel') { Rol-Adi $b.Rol } else { '' }
        $sonu = if ($rolAd) { T " $rolAd, $kalan sn kaldı." " $rolAd, ${kalan}s left." } else { T " $kalan sn kaldı." " ${kalan}s left." }
        if ($b -and $b.Benim -gt 0) {
            $id = $b.Benim; $ad = Sampiyon-Adi $id
            $not = $(if ($b.Kilitli) { T 'Kilitlendi.' 'Locked in.' } else { T 'Üzerindesin.' 'Hovering.' }) + $sonu
        } else { $ad = T 'Şampiyon seçimi' 'Champ select'; $not = (T 'Seçim sürüyor.' 'Picking.') + $sonu }
    } elseif (@('GameStart', 'InProgress', 'Reconnect') -contains $faz) {
        if ($script:SonSampiyon) { $id = $script:SonSampiyon }
        $ad = if ($id) { Sampiyon-Adi $id } else { 'Riot Plus' }
        $not = if ($faz -eq 'Reconnect') { T "Maçtan düştün; 2'ye basıp yeniden bağlan." "You dropped out; press 2 to reconnect." } else { T 'Maçtasın. İyi oyunlar.' 'In game. Have a good one.' }
    } else {
        $ad = if ($id) { Sampiyon-Adi $id } else { 'Riot Plus' }
        $not = $v.Not
    }
    # Custom sayfası açıkken: sayfada seçili şampiyon ve onun custom'ı
    $sayfa = $CustomGorunum.Visibility -eq 'Visible' -and $script:CustomOdak -and $script:CustomOdak -ne 'diger'
    if ($sayfa) {
        $id = [int]$script:CustomOdak; $ad = Sampiyon-Adi $id; $buyuk = 40; $karart = $false
        $cm = Custom-Secili (Custom-Gruplar)[$script:CustomOdak]
        $not = if ($cm) { "Custom: $($cm.Ad)" } else { T 'Klasik skin; custom seçilmedi' 'Base skin; no custom picked' }
    } else {
        # Ana sayfada seçili custom'ın görseli gelir, adı notun sonuna eklenir
        $cm = Custom-Secim $id
        if ($cm -and -not $karart) { $not = "$not · $($cm.Ad)" }
    }
    $GorselDugme.Visibility = if ($sayfa -and $cm) { 'Visible' } else { 'Collapsed' }
    $gorsel = if ($id) { Custom-Gorsel $cm $id } else { @{ Kaynak = $null; Anahtar = '' } }
    if ($gorsel.Anahtar -ne $script:KahramanKod) { $script:KahramanKod = $gorsel.Anahtar; $KahramanResim.Source = $gorsel.Kaynak }
    $KahramanAd.Text = $ad; $KahramanAd.FontSize = $buyuk
    $KahramanNot.Text = $not
    $KahramanKarart.Visibility = if ($karart) { 'Visible' } else { 'Collapsed' }
}

$script:EylemModu = $null
$script:EylemIslem = 'sira'
function Eylem-Guncelle {
    $faz = $script:SonFaz
    $mod = if ($faz -eq 'Matchmaking') { 'cik' } elseif (@('ReadyCheck', 'ChampSelect', 'GameStart', 'InProgress', 'Reconnect') -contains $faz) { 'gec' } else { 'gir' }
    if ($mod -eq $script:EylemModu) { return }
    $script:EylemModu = $mod
    switch ($mod) {
        'gir' { $AnaDugme.Style = $Pencere.FindResource('Birincil'); Ceviri-Degistir $AnaDugmeYazi 'Sıraya gir' 'Queue up'; $script:EylemIslem = 'sira'; Ceviri-Degistir $TepsiSira 'Sıraya gir' 'Queue up' }
        'cik' { $AnaDugme.Style = $Pencere.FindResource('Ikincil'); Ceviri-Degistir $AnaDugmeYazi 'Sıradan çık' 'Leave queue'; $script:EylemIslem = 'sira'; Ceviri-Degistir $TepsiSira 'Sıradan çık' 'Leave queue' }
        'gec' { $AnaDugme.Style = $Pencere.FindResource('Ikincil'); Ceviri-Degistir $AnaDugmeYazi "LoL'e geç" 'Go to LoL'; $script:EylemIslem = 'ac'; Ceviri-Degistir $TepsiSira "LoL'e geç" 'Go to LoL' }
    }
}

function Rol-Yazisi-Guncelle {
    $SiraSecim.Text = Sira-Adi $Ayar.sira
    if ([int]$Ayar.sira -eq 450) {
        $Rol1Secim.Text = T 'Rol seçimi yok' 'No roles'; $Rol1Secim.Cursor = 'Arrow'
        $RolAra.Visibility = 'Collapsed'; $Rol2Secim.Visibility = 'Collapsed'; return
    }
    $Rol1Secim.Cursor = 'Hand'
    if (-not $Ayar.rol1) {
        $bilinen = Rol-Kodundan $script:LobiRol1
        $Rol1Secim.Text = if ($bilinen) { (T "Client'taki roller: " "Client's roles: ") + (Rol-Kod-Adi $script:LobiRol1) } else { Rol-Kod-Adi '' }
        $RolAra.Visibility = 'Collapsed'; $Rol2Secim.Visibility = 'Collapsed'
    } elseif ($Ayar.rol1 -eq 'FILL') {
        $Rol1Secim.Text = Rol-Kod-Adi 'FILL'
        $RolAra.Visibility = 'Collapsed'; $Rol2Secim.Visibility = 'Collapsed'
    } else {
        $Rol1Secim.Text = Rol-Kod-Adi $Ayar.rol1
        $RolAra.Text = T ', yedek ' ', backup '; $RolAra.Visibility = 'Visible'
        $Rol2Secim.Text = Rol-Kod-Adi $Ayar.rol2; $Rol2Secim.Visibility = 'Visible'
    }
}

$script:SurecDurum = @{ Riot = $false; Lol = 'kapali'; Mac = $false }
function Hal-Guncelle {
    $d = $script:SurecDurum
    $faz = $script:SonFaz
    $cumle = if ($d.Mac) { T 'Maçtasın.' "You're in a game." }
        elseif ($d.Lol -eq 'kapali') { if ($d.Riot) { T 'LoL kapalı, Riot Client açık.' 'LoL is closed, Riot Client is open.' } else { T 'LoL kapalı.' 'LoL is closed.' } }
        elseif ($d.Lol -eq 'aciliyor') { T 'LoL açılıyor.' 'LoL is starting.' }
        elseif ($d.Lol -eq 'gizli') { T "LoL açık ama penceresi gizli; 1'e bas." "LoL is open but its window is hidden; press 1." }
        else {
            switch ($faz) {
                'None'        { T 'LoL açık, ana ekrandasın.' 'LoL is open, on the home screen.' }
                'Lobby'       { T 'LoL açık, lobidesin.' "LoL is open, you're in a lobby." }
                'Matchmaking' { T 'Sıradasın.' "You're in queue." }
                'ReadyCheck'  { T 'Maç bulundu.' 'Match found.' }
                'ChampSelect' { T 'Şampiyon seçimindesin.' "You're in champ select." }
                'EndOfGame'   { T 'Maç bitti.' 'The game is over.' }
                default       { T 'LoL açık.' 'LoL is open.' }
            }
        }
    $HalYazi.Inlines.Clear()
    $HalYazi.Inlines.Add((New-Object Windows.Documents.Run($cumle)))
    $p = Ping-Ozet
    if ($p) {
        $HalYazi.Inlines.Add((New-Object Windows.Documents.Run(" $($p[0])")))
        $deger = New-Object Windows.Documents.Run($p[1]); $deger.Foreground = Firca $p[2]; $deger.FontWeight = 'SemiBold'
        $HalYazi.Inlines.Add($deger)
        $HalYazi.Inlines.Add((New-Object Windows.Documents.Run($p[3])))
    }
}

# Portre: 40x40 şampiyon ikonu; boşsa kesik çizgili kutu; banlı kırmızı çizgi, alınmış soluk, seçili yeşil çerçeve
function Portre-Olustur($panel) {
    $kok = New-Object Windows.Controls.Grid
    $kok.Width = 40; $kok.Height = 40; $kok.Margin = '0,0,6,0'; $kok.Cursor = 'Hand'; $kok.Background = Firca '#00000000'
    $bos = New-Object Windows.Shapes.Rectangle
    $bos.RadiusX = 6; $bos.RadiusY = 6; $bos.Fill = Firca '#1A212B'; $bos.Stroke = Firca '#3A4452'; $bos.StrokeDashArray = [Windows.Media.DoubleCollection]::Parse('3 2')
    $resim = New-Object Windows.Controls.Image
    $resim.Stretch = 'UniformToFill'
    $resim.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, 40, 40)), 6, 6)
    $cizgi = New-Object Windows.Shapes.Rectangle
    $cizgi.Width = 2.5; $cizgi.Height = 52; $cizgi.Fill = Firca $RenkKirmizi; $cizgi.Visibility = 'Collapsed'
    $cizgi.RenderTransformOrigin = '0.5,0.5'; $cizgi.RenderTransform = New-Object Windows.Media.RotateTransform(45)
    $cerceve = New-Object Windows.Controls.Border
    $cerceve.CornerRadius = 8; $cerceve.BorderThickness = 2; $cerceve.BorderBrush = Firca $RenkYesil; $cerceve.Margin = '-3'; $cerceve.Visibility = 'Collapsed'
    foreach ($o in $bos, $resim, $cizgi, $cerceve) { [void]$kok.Children.Add($o) }
    $kok.Add_MouseLeftButtonUp({ if (Basildi $this) { Duzenle-Ac } })
    [void]$panel.Children.Add($kok)
    return @{ Kok = $kok; Bos = $bos; Resim = $resim; Cizgi = $cizgi; Cerceve = $cerceve; Anahtar = '' }
}
function Portre-Ayarla($slot, $id, $hal) {
    $anahtar = "$id|$hal|$($script:Dil)"
    if ($slot.Anahtar -eq $anahtar) { return }
    $slot.Anahtar = $anahtar
    $kod = if ($id -gt 0) { $script:SampiyonKod[[int]$id] } else { $null }
    if ($kod) {
        $slot.Resim.Source = Gorsel 'ikon' $kod; $slot.Bos.Visibility = 'Collapsed'
        $slot.Kok.ToolTip = (Sampiyon-Adi $id) + $(switch ($hal) { 'banli' { T ' (banlandı)' ' (banned)' } 'alindi' { T ' (alındı)' ' (taken)' } 'secili' { T ' (senin)' ' (yours)' } default { '' } })
    } else { $slot.Resim.Source = $null; $slot.Bos.Visibility = 'Visible'; $slot.Kok.ToolTip = T 'Boş; doldurmak için tıkla' 'Empty; click to fill' }
    $slot.Resim.Opacity = if ($hal -eq 'alindi') { 0.3 } elseif ($hal -eq 'banli') { 0.4 } else { 1 }
    $slot.Cizgi.Visibility = if ($hal -eq 'banli') { 'Visible' } else { 'Collapsed' }
    $slot.Cerceve.Visibility = if ($hal -eq 'secili') { 'Visible' } else { 'Collapsed' }
}
$script:BanSlot = @(0..2 | ForEach-Object { Portre-Olustur $BanPortreler })
$script:OynaSlot = @(0..2 | ForEach-Object { Portre-Olustur $OynaPortreler })
function Portre-Guncelle {
    $b = $script:SecimBilgi
    $rol = Aktif-Rol
    $OynaRol.Text = Rol-Adi $rol
    $pick = Rol-Listesi $rol
    for ($i = 0; $i -lt 3; $i++) {
        $bid = [int]$Ayar.banListe[$i]
        Portre-Ayarla $script:BanSlot[$i] $bid $(if ($b -and $bid -gt 0 -and $b.Banli[$bid]) { 'banli' } else { '' })
        $pid_ = [int]$pick[$i]
        $hal = if (-not $b -or $pid_ -le 0) { '' } elseif ($b.Benim -eq $pid_) { 'secili' } elseif ($b.Banli[$pid_]) { 'banli' } elseif ($b.Alinan[$pid_]) { 'alindi' } else { '' }
        Portre-Ayarla $script:OynaSlot[$i] $pid_ $hal
    }
    $KabulNot.Text = if ($script:SonFaz -eq 'ReadyCheck' -and $script:HazirYanit -eq 'Accepted') { T 'Kabul edildi' 'Accepted' } elseif ($Ayar.kabul) { T 'Maç bulununca kabul ederim' "I'll accept when a match is found" } else { T 'Kapalı; kabulü sen yaparsın' "Off; you'll accept yourself" }
}

function Gorunum-Guncelle {
    if ($script:Kapandi) { return }
    Kahraman-Guncelle
    Eylem-Guncelle
    Rol-Yazisi-Guncelle
    Portre-Guncelle
    Custom-Satir-Guncelle
    Hal-Guncelle
}

# ---- Durum (süreçler) ----
function Durum-Guncelle {
    if ($script:Kapandi) { return }
    $p = @(Get-Process -Name 'RiotClientServices', 'Riot Client', 'LeagueClient', 'LeagueClientUx', 'League of Legends' -ErrorAction SilentlyContinue)
    $adlar = $p | ForEach-Object { $_.Name }
    $ux = $p | Where-Object { $_.Name -eq 'LeagueClientUx' }
    $lol = if (-not $ux -and $adlar -contains 'LeagueClient') { 'aciliyor' } elseif (-not $ux) { 'kapali' } elseif (@($ux | Where-Object { $_.MainWindowHandle -ne 0 }).Count) { 'acik' } else { 'gizli' }
    if ($Deneme -and $lol -eq 'kapali' -and $script:SonFaz) { $lol = 'acik' }   # sahte client
    $script:SurecDurum = @{ Riot = ($adlar -contains 'RiotClientServices' -or $adlar -contains 'Riot Client'); Lol = $lol; Mac = ($adlar -contains 'League of Legends') }
    try { Ltk-Durum-Guncelle } catch {}
    Hal-Guncelle
}

# ---- Şampiyon seçimi bölümü ----
Cevir $SecimBaslik 'Şampiyon seçimi' 'Champ select'
Cevir $KabulAd 'Kabul' 'Accept'
Cevir $BanAd 'Banla' 'Ban'
Cevir $OynaAd 'Oyna' 'Play'
Ipucu-Ver $AnahtarKabul 'Maç bulununca otomatik kabul' 'Auto-accept when a match is found'
Ipucu-Ver $AnahtarBan 'Sıran gelince listedeki ilk uygun şampiyonu banlar; arkadaşının seçeceğini banlamaz' "Bans the first available champion on your turn; never a teammate's pick"
Ipucu-Ver $AnahtarPick 'Rolüne göre listedeki ilk uygun şampiyonu seçer' 'Picks the first available champion for your role'
foreach ($k in $AnahtarKabul, $AnahtarBan, $AnahtarPick, $AnahtarKilitle) {
    $k.IsChecked = [bool]$Ayar[$k.Tag]
    $k.Add_Click({
        $Ayar[$this.Tag] = [bool]$this.IsChecked
        Ayar-Kaydet
        if ($this.Tag -ne 'kilitle') { $script:Secim = $null }
        Portre-Guncelle
    })
}

# ---- Sorun mu var? ----
Cevir $SorunBaslik 'Sorun mu var?' 'Something wrong?'
$Sorunlar = @(
    @{ Islem = 'ekran';   Tus = '1'; Tr = 'Ekrana gelmiyor'; En = "LoL won't show up"
       IpucuTr = 'Yalnız client arayüzünü yeniden başlatır; giriş ve parti korunur.'; IpucuEn = 'Restarts only the client UI; login and party are kept.' }
    @{ Islem = 'yukleme'; Tus = '2'; Tr = 'Yükleme ekranında kaldı'; En = 'Stuck on the loading screen'
       IpucuTr = 'Maç başladı mı bakar; oyun penceresini tazeler ya da yeniden bağlar.'; IpucuEn = 'Checks the match; refreshes the game window or reconnects.' }
    @{ Islem = 'ac';      Tus = '3'; Tr = "LoL'ü aç"; En = 'Open LoL'
       IpucuTr = "Açıksa öne getirir. Kapalıysa sorar: LTK Manager ile, Rose ile ya da düz (hiçbir şey yüklenmeden)."; IpucuEn = 'Brings it up if open. If closed it asks: with LTK Manager, with Rose, or plain (nothing loaded).' }
    @{ Islem = 'kapat';   Tus = '4'; Tr = 'Hepsini kapat'; En = 'Close everything'
       IpucuTr = "LoL ve Riot Client süreçlerini kapatır; Vanguard'a dokunmaz. İki kez basılır."; IpucuEn = 'Closes LoL and Riot Client; leaves Vanguard alone. Needs two presses.' }
)
# Satırlar gruplu kartın içinde: ilk ve son satırın köşesi kartla aynı yuvarlaklıkta, aralarda soldan girintili ayraç
$sorunNo = 0
foreach ($s in $Sorunlar) {
    if ($sorunNo -gt 0) {
        $ayrac = New-Object Windows.Controls.Border
        $ayrac.Style = $Pencere.FindResource('Ayrac')
        [void]$SorunPanel.Children.Add($ayrac)
    }
    $kose = if ($sorunNo -eq 0) { '11,11,0,0' } elseif ($sorunNo -eq $Sorunlar.Count - 1) { '0,0,11,11' } else { '0' }
    $sorunNo++
    $satir = New-Object Windows.Controls.Border
    $satir.Height = 40; $satir.CornerRadius = $kose; $satir.Padding = '14,0,12,0'; $satir.Cursor = 'Hand'; $satir.Background = Firca '#00000000'; $satir.Tag = $s.Islem
    $satir.ClipToBounds = $true
    $g = New-Object Windows.Controls.Grid
    $ad = New-Object Windows.Controls.TextBlock
    $ad.VerticalAlignment = 'Center'
    if ($s.Islem -eq 'kapat') { $ad.Foreground = Firca '#F0797C' }
    Cevir $ad $s.Tr $s.En
    $tus = New-Object Windows.Controls.Border
    $tus.HorizontalAlignment = 'Right'; $tus.VerticalAlignment = 'Center'; $tus.MinWidth = 20; $tus.Height = 20; $tus.CornerRadius = 4
    $tus.Background = Firca '#19202A'; $tus.BorderBrush = Firca '#343E4B'; $tus.BorderThickness = '1,1,1,2'
    $tusYazi = New-Object Windows.Controls.TextBlock
    $tusYazi.Text = $s.Tus; $tusYazi.FontSize = 11; $tusYazi.FontWeight = 'SemiBold'; $tusYazi.Foreground = Firca $RenkSoluk
    $tusYazi.HorizontalAlignment = 'Center'; $tusYazi.VerticalAlignment = 'Center'; $tusYazi.Margin = '5,0'
    $tus.Child = $tusYazi
    [void]$g.Children.Add($ad); [void]$g.Children.Add($tus)
    if ($s.Islem -eq 'kapat') {
        # Onay perdesi: soldan sağa kayar; yazı satır genişliğinde sabit durur, perde açıldıkça görünür
        $ortu = New-Object Windows.Controls.Border
        $ortu.HorizontalAlignment = 'Left'; $ortu.Width = 0; $ortu.Margin = '-14,0,-12,0'; $ortu.CornerRadius = '0,0,11,11'; $ortu.ClipToBounds = $true; $ortu.Visibility = 'Collapsed'
        $ortu.Background = New-Object Windows.Media.LinearGradientBrush((Firca '#8E1F27').Color, (Firca '#D93A42').Color, 0)
        $ortuIc = New-Object Windows.Controls.Grid
        $ortuIc.HorizontalAlignment = 'Left'
        $ortuYazi = New-Object Windows.Controls.TextBlock
        $ortuYazi.Foreground = Firca '#FFFFFF'; $ortuYazi.FontWeight = 'SemiBold'; $ortuYazi.HorizontalAlignment = 'Center'; $ortuYazi.VerticalAlignment = 'Center'
        $ortuIc.Children.Add($ortuYazi) | Out-Null
        $ortu.Child = $ortuIc
        [void]$g.Children.Add($ortu)
        $KapatOrtu = $ortu; $KapatOrtuIc = $ortuIc; $KapatOrtuYazi = $ortuYazi; $KapatSatir = $satir
    }
    $satir.Child = $g
    Ipucu-Ver $satir $s.IpucuTr $s.IpucuEn
    # Üzerine gelince açık, basılıyken daha açık zemin (HIG: özel düğmede her zaman basma durumu olsun)
    $satir.Add_MouseEnter({ if ($this.Tag -ne $script:Calisan) { $this.Background = Firca '#212A35' } })
    $satir.Add_MouseLeave({ if ($this.Tag -ne $script:Calisan) { $this.Background = Firca '#00000000' } })
    $satir.Add_MouseLeftButtonDown({ $this.Background = Firca '#29333F' })
    $satir.Add_MouseLeftButtonUp({ $this.Background = Firca $(if ($this.IsMouseOver -or $this.Tag -eq $script:Calisan) { '#212A35' } else { '#00000000' }); if (Basildi $this) { if ($this.Tag -eq 'ac' -and (Ac-Sorulur)) { Ac-Menu $this } else { Kart-Bas $this.Tag } } })
    $s.Satir = $satir
    [void]$SorunPanel.Children.Add($satir)
}

# "LoL'ü aç": LoL kapalıyken nasıl açılacağı sorulur; son kullanılan kip işaretli gelir
function Ac-Sorulur { (Lol-Kapali) -and -not $script:Mesgul }
function Ac-Menu($hedef) {
    $simdi = Ac-Kipi
    Menu-Ac $hedef @(
        @{ Metin = (T 'LTK Manager ile aç (kendi modların)' 'Open with LTK Manager (your own mods)'); Deger = 'ltk'; Secili = ($simdi -eq 'ltk') }
        @{ Metin = (T 'Rose ile aç' 'Open with Rose'); Deger = 'rose'; Secili = ($simdi -eq 'rose') }
        @{ Metin = (T 'Düz aç (custom yok)' 'Open plain (no customs)'); Deger = 'duz'; Secili = ($simdi -eq 'duz') }
    ) { param($d) $script:AcIstek = "$d"; Kart-Bas 'ackip' }
}
# Çalışan seçeneğin satırı işaretli kalır; ana düğme çalışırken soluklaşır
function Satir-Isaretle {
    foreach ($s in $Sorunlar) { $s.Satir.Background = Firca $(if ($s.Islem -eq $script:Calisan -or ($s.Islem -eq 'ac' -and $script:Calisan -eq 'ackip')) { '#212A35' } else { '#00000000' }) }
    $AnaDugme.Opacity = if ($script:Calisan -and $script:Calisan -eq $script:EylemIslem) { 0.7 } else { 1 }
}

# ---- "Hepsini kapat" onayı ----
$script:KapatHazir = $false
$script:KapatBitis = [DateTime]::MinValue
$KapatSayac = New-Object Windows.Threading.DispatcherTimer
$KapatSayac.Interval = [TimeSpan]::FromMilliseconds(200)
function Perde-Kaydir($hedef, $ms) {
    $a = New-Object Windows.Media.Animation.DoubleAnimation($KapatOrtu.ActualWidth, $hedef, (New-Object Windows.Duration([TimeSpan]::FromMilliseconds($ms))))
    $kolay = New-Object Windows.Media.Animation.CubicEase; $kolay.EasingMode = 'EaseOut'; $a.EasingFunction = $kolay
    if ($hedef -le 0) { $a.Add_Completed({ if (-not $script:KapatHazir) { $KapatOrtu.Visibility = 'Collapsed' } }) }
    $KapatOrtu.BeginAnimation([Windows.FrameworkElement]::WidthProperty, $a)
}
function Perde-Yazi {
    $kalan = [Math]::Max(1, [int][Math]::Ceiling(($script:KapatBitis - [DateTime]::Now).TotalSeconds))
    $KapatOrtuYazi.Text = T "Emin misin? Kapatmak için tekrar bas ($kalan)" "Sure? Press again to close ($kalan)"
}
function Kapat-Kur {
    $script:KapatHazir = $true
    $script:KapatBitis = [DateTime]::Now.AddSeconds($KapatOnaySn)
    $genislik = $KapatSatir.ActualWidth
    $KapatOrtuIc.Width = $genislik
    Perde-Yazi
    $KapatOrtu.Visibility = 'Visible'
    Perde-Kaydir $genislik 300
    $KapatSayac.Start()
}
function Kapat-Vazgec {
    $script:KapatHazir = $false
    $KapatSayac.Stop()
    Perde-Kaydir 0 200
}
$KapatSayac.Add_Tick({ if ([DateTime]::Now -ge $script:KapatBitis) { Kapat-Vazgec } else { Perde-Yazi } })

# Satır / tuş / düğme basışı: "kapat" ikinci basışta çalışır
function Kart-Bas($islem) {
    if ($islem -eq 'kapat') {
        if (-not $script:KapatHazir) { Kapat-Kur; return }
        Kapat-Vazgec
    }
    Calistir $islem
}
$AnaDugme.Add_Click({ Kart-Bas $script:EylemIslem })
Ipucu-Ver $AnaDugme 'Kısayol: 5' 'Shortcut: 5'

# ---- Rol listesi düzenleyicisi ----
Cevir $KilitleYazi 'Sıra gelince kilitle' 'Lock in on my turn'
Cevir $BekleYazi 'Önce bekle (sn)' 'Wait first (s)'
Cevir $DuzenleNot 'Soldan sağa dener; alınmışsa ya da sende yoksa sıradakine geçer. Rolsüz listesi kör seçimde ve rol listesi tükenince kullanılır.' "Tries left to right; skips taken or unowned champions. The any-role list is used in blind pick and when a role list runs out."
Ipucu-Ver $AnahtarKilitle 'Kapalıysa yalnız üzerine gelir, kilitlemeyi sen yaparsın' "If off, it only hovers; you lock in"
Ipucu-Ver $BekleDeger 'Sıra sana gelince ban/pick atmadan önce bu kadar bekler; süre bitmek üzereyse beklemez.' 'Waits this long on your turn before banning/picking; skips the wait if time is almost up.'
$BekleDeger.Text = "$($Ayar.bekleSn)"
foreach ($d in @(@($BekleEksi, -1), @($BekleArti, 1))) {
    $d[0].Tag = $d[1]
    $d[0].Add_Click({
        $Ayar.bekleSn = [Math]::Max(0, [Math]::Min(25, [int]$Ayar.bekleSn + [int]$this.Tag))
        $BekleDeger.Text = "$($Ayar.bekleSn)"
        Ayar-Kaydet
    })
}
# Rol listeleri artık kendi sekmesi (Sekme-Sec); eski adlar portre tıkı ve -Kare için duruyor
function Duzenle-Ac { Sekme-Sec 'roller' }
function Duzenle-Kapat { Sekme-Sec 'ana' }

# Tablo: Ban + 6 rol; her hücre küçük ikon + yazı kutusu (yazdıkça öneri listesi, iki dilde tanır)
$script:Seciciler = New-Object Collections.ArrayList
$script:SeciciResim = @{}
$satirNo = 0
foreach ($r in @('ban') + @($Roller.Keys)) {
    $e = New-Object Windows.Controls.TextBlock
    $e.VerticalAlignment = 'Center'; $e.Foreground = Firca $RenkSoluk
    if ($r -eq 'ban') { Cevir $e 'Ban' 'Ban' } else { Cevir $e $Roller[$r] $RollerEn[$r] }
    [Windows.Controls.Grid]::SetRow($e, $satirNo)
    [void]$DuzenleTablo.Children.Add($e)
    for ($i = 0; $i -lt 3; $i++) {
        $hucre = New-Object Windows.Controls.Grid
        $hucre.Margin = '0,0,6,0'; $hucre.VerticalAlignment = 'Center'
        $t = New-Object Windows.Controls.TextBox
        $t.Style = $Pencere.FindResource('Alan'); $t.Padding = '30,0,6,0'; $t.Tag = "${r}:$i"
        $ikon = New-Object Windows.Controls.Image
        $ikon.Width = 20; $ikon.Height = 20; $ikon.HorizontalAlignment = 'Left'; $ikon.Margin = '5,0,0,0'; $ikon.IsHitTestVisible = $false
        $ikon.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, 20, 20)), 4, 4)
        [void]$hucre.Children.Add($t); [void]$hucre.Children.Add($ikon)
        [Windows.Controls.Grid]::SetRow($hucre, $satirNo); [Windows.Controls.Grid]::SetColumn($hucre, $i + 1)
        [void]$DuzenleTablo.Children.Add($hucre)
        $script:SeciciResim["${r}:$i"] = $ikon
        [void]$script:Seciciler.Add($t)
    }
    $satirNo++
}
function Secici-Id($c) {
    $p = "$($c.Tag)".Split(':'); $liste = $p[0]; $sira = [int]$p[1]
    if ($liste -eq 'ban') { return [int]$Ayar.banListe[$sira] }
    return [int]$Ayar.pickListe[$liste][$sira]
}
function Secici-Ikon($c, $id) {
    $kod = if ($id -gt 0) { $script:SampiyonKod[[int]$id] } else { $null }
    $script:SeciciResim["$($c.Tag)"].Source = if ($kod) { Gorsel 'ikon' $kod } else { $null }
}
# Yazarken: ad tam tanınınca ya da kutu boşalınca kaydeder. Çıkarken: tanınmayan ad kırmızı kalır, kaydedilmez
function Secici-Degisti($c, $cikis) {
    if ($script:Yukleniyor) { return }
    $metin = $c.Text.Trim()
    $id = 0
    if ($metin) {
        $id = [int]$script:SampiyonAd[(Ad-Normal $metin)]
        if (-not $id) { if ($cikis) { $c.Foreground = Firca $RenkKirmizi }; return }
        if ($cikis) {
            $ad = Sampiyon-Adi $id
            if ($c.Text -ne $ad) { $c.Text = $ad }
        }
    }
    $c.Foreground = Firca $RenkYazi
    Secici-Ikon $c $id
    $p = "$($c.Tag)".Split(':'); $liste = $p[0]; $sira = [int]$p[1]
    # Doğrudan atama: "$x = if (...) { dizi }" diziyi kopyalar, değişiklik ayara yansımazdı
    if ($liste -eq 'ban') { $hedef = $Ayar.banListe } else { $hedef = $Ayar.pickListe[$liste] }
    if ($hedef[$sira] -ne $id) { $hedef[$sira] = $id; Ayar-Kaydet }
}

$script:OneriAdlar = @()
$script:OneriHedef = $null
$script:OneriSeciliyor = $false
function Oneri-Doldur {
    $script:OneriAdlar = @(Sampiyon-Listesi | ForEach-Object { @{ Ad = $_; Norm = (Ad-Normal $_) } })
}
function Oneri-Goster($tb) {
    $aranan = Ad-Normal $tb.Text
    if (-not $aranan) { $OneriPopup.IsOpen = $false; return }
    $bas = @($script:OneriAdlar | Where-Object { $_.Norm.StartsWith($aranan, [StringComparison]::Ordinal) } | ForEach-Object { $_.Ad })
    $ic  = @($script:OneriAdlar | Where-Object { -not $_.Norm.StartsWith($aranan, [StringComparison]::Ordinal) -and $_.Norm.Contains($aranan) } | ForEach-Object { $_.Ad })
    $liste = @(@($bas) + @($ic) | Select-Object -First 8)
    if (-not $liste.Count -or ($liste.Count -eq 1 -and $liste[0] -eq $tb.Text)) { $OneriPopup.IsOpen = $false; return }
    $OneriListe.ItemsSource = $liste
    $OneriListe.SelectedIndex = 0
    $OneriPopup.PlacementTarget = $tb
    $OneriPopup.MinWidth = $tb.ActualWidth
    $OneriPopup.IsOpen = $true
    $script:OneriHedef = $tb
}
function Oneri-Sec($ad) {
    $tb = $script:OneriHedef
    $OneriPopup.IsOpen = $false
    if (-not $tb -or -not $ad) { return }
    $script:OneriSeciliyor = $true
    $tb.Text = $ad; $tb.CaretIndex = $ad.Length
    $script:OneriSeciliyor = $false
    Secici-Degisti $tb $true
}
$OneriListe.Add_PreviewMouseLeftButtonUp({
    $e = $_.OriginalSource
    try { while ($e -and -not ($e -is [Windows.Controls.ListBoxItem])) { $e = [Windows.Media.VisualTreeHelper]::GetParent($e) } } catch { $e = $null }
    if ($e) { Oneri-Sec ([string]$e.DataContext) }
})
foreach ($c in $script:Seciciler) {
    $id = Secici-Id $c
    if ($id -gt 0) { $c.Text = Sampiyon-Adi $id; Secici-Ikon $c $id }
    $c.Add_TextChanged({
        if (-not $script:Yukleniyor -and -not $script:OneriSeciliyor -and $this.IsKeyboardFocused) { Oneri-Goster $this }
        Secici-Degisti $this $false
    })
    $c.Add_LostKeyboardFocus({ Secici-Degisti $this $true })
    $c.Add_PreviewKeyDown({
        $acik = $OneriPopup.IsOpen -and [object]::ReferenceEquals($script:OneriHedef, $this)
        switch ([string]$_.Key) {
            'Down'   { if ($acik) { $OneriListe.SelectedIndex = [Math]::Min($OneriListe.Items.Count - 1, $OneriListe.SelectedIndex + 1); $_.Handled = $true } }
            'Up'     { if ($acik) { $OneriListe.SelectedIndex = [Math]::Max(0, $OneriListe.SelectedIndex - 1); $_.Handled = $true } }
            'Return' { if ($acik) { Oneri-Sec ([string]$OneriListe.SelectedItem) } else { Secici-Degisti $this $true }; $_.Handled = $true }
            'Tab'    { if ($acik) { Oneri-Sec ([string]$OneriListe.SelectedItem) } }
            'Escape' { if ($acik) { $OneriPopup.IsOpen = $false; $_.Handled = $true } }
        }
    })
}
Oneri-Doldur

# ---- Custom skinler: "Skin" satırı + görünüm ----
Cevir $CustomAd 'Skin' 'Skin'
Cevir $ModEkle 'Mod ekle' 'Add mod'
Cevir $LtkAc "LTK'yı aç" 'Open LTK'
Ipucu-Ver $AnahtarCustom 'Açıkken LTK Manager tepside çalışır, seçtiğin custom skinler oyunda görünür.' 'When on, LTK Manager runs in the tray and your custom skins show in game.'
# CustomNot'un ipucu Custom-Satir-Guncelle'de: satırın tam metni (dar pencerede sonu kesilebiliyor) + ne işe yaradığı
Ipucu-Ver $ModEkle '.fantome ya da .modpkg dosyası seç; dosyayı bu bölüme sürükleyip bırakabilirsin de.' 'Pick a .fantome or .modpkg file; you can also drop files here.'
Ipucu-Ver $LtkAc "LTK Manager'ın kendi penceresi: ayrıntılı ayarlar, onarım" "LTK Manager's own window: advanced settings, repair"

# Skin satırının baktığı şampiyon: seçimde üzerinde olduğun, maçta oynadığın, değilse rolündeki ilk tercihin
function Custom-Sampiyon {
    $faz = $script:SonFaz
    if ($faz -eq 'ChampSelect' -and $script:SecimBilgi -and $script:SecimBilgi.Benim -gt 0) { return [int]$script:SecimBilgi.Benim }
    if (@('GameStart', 'InProgress', 'Reconnect', 'EndOfGame') -contains $faz -and $script:SonSampiyon) { return [int]$script:SonSampiyon }
    return [int](Varsayilan-Sampiyon).Id
}

# Skin satırı: asıl bilgi normal renkte, yalnız uyarı parçası turuncu (HIG Color: rengi tutarlı ve ölçülü kullan;
# eskiden tek bir uyarı yüzünden bütün satır turuncuya dönüyordu)
function Custom-Satir-Guncelle {
    $renk = $RenkYazi
    $parcalar = New-Object Collections.ArrayList   # @(metin, renk|$null); $null = satırın ana rengi
    $kurulu = Ltk-Kurulu
    if (Rose-Kipi) {
        $kurulu = $kurulu -and $script:RoseDurum.Kurulu
        if (-not $script:RoseDurum.Kurulu) { [void]$parcalar.Add(@((T 'Rose kurulu değil' 'Rose not installed'), $null)); $renk = $RenkSoluk }
        elseif (-not (Ltk-Kurulu)) { [void]$parcalar.Add(@((T 'Rose için LTK Manager gerekli' 'Rose needs LTK Manager'), $null)); $renk = $RenkSoluk }
        elseif (-not $Ayar.custom) { [void]$parcalar.Add(@((T 'Kapalı; oyunda custom yok' 'Off; no customs in game'), $null)); $renk = $RenkSoluk }
        else {
            [void]$parcalar.Add(@((T "Rose: skinini seçimde LoL'ün içinden seç" 'Rose: pick your skin in champ select, inside LoL'), $null))
            if (-not $script:RoseDurum.Acik -and -not $script:Mesgul) { [void]$parcalar.Add(@((T ' · Rose kapalı' ' · Rose not running'), $RenkTuruncu)) }
        }
    }
    elseif (-not $kurulu) { [void]$parcalar.Add(@((T 'LTK Manager kurulu değil' 'LTK Manager not installed'), $null)); $renk = $RenkSoluk }
    elseif (-not $Ayar.custom) { [void]$parcalar.Add(@((T 'Kapalı; oyunda custom yok' 'Off; no customs in game'), $null)); $renk = $RenkSoluk }
    else {
        $gruplar = Custom-Gruplar
        $id = Custom-Sampiyon
        if ($id -and $gruplar.ContainsKey("$id")) {
            $s = Custom-Secili $gruplar["$id"]
            [void]$parcalar.Add(@(("$(Sampiyon-Adi $id): " + $(if ($s) { $s.Ad } else { T 'Klasik' 'Base skin' })), $null))
            # Klasikte görünmeyen ve skini sende olmayan (ya da bilinmeyen) custom: uyar
            $gr = if ($s) { Mod-Gorunum $s } else { $null }
            if ($gr -and $gr.Uyari) { [void]$parcalar.Add(@((T " · yalnız $(Skin-Adi $id $gr.Num)" " · only on $(Skin-Adi $id $gr.Num)"), $RenkTuruncu)) }
        } else {
            $n = @($gruplar.Keys | Where-Object { $_ -ne 'diger' }).Count
            [void]$parcalar.Add(@($(if ($n) { T "$n şampiyonda custom var" "Customs for $n champions" } else { T 'Henüz custom yok' 'No customs yet' }), $null))
        }
        if (-not $script:LtkDurum.Acik -and -not $script:Mesgul) { [void]$parcalar.Add(@((T ' · LTK kapalı' ' · LTK not running'), $RenkTuruncu)) }
        elseif ($script:PatcherBekle) { [void]$parcalar.Add(@((T ' · hazırlanıyor' ' · preparing'), $RenkSoluk)) }
        elseif (-not $script:LtkDurum.Patcher -and -not $script:Mesgul) { [void]$parcalar.Add(@((T ' · patcher kapalı' ' · patcher stopped'), $RenkTuruncu)) }
    }
    $anahtar = (($parcalar | ForEach-Object { "$($_[0])|$($_[1])" }) -join '||') + "|$renk"
    if ($script:CustomNotAnahtar -ne $anahtar) {
        $script:CustomNotAnahtar = $anahtar
        $CustomNot.Inlines.Clear()
        foreach ($p in $parcalar) {
            $run = New-Object Windows.Documents.Run($p[0])
            if ($p[1]) { $run.Foreground = Firca $p[1] }
            $CustomNot.Inlines.Add($run)
        }
        $CustomNot.ToolTip = (($parcalar | ForEach-Object { $_[0] }) -join '') + "`n" + $(if (Rose-Kipi) { T 'Tıkla: Custom skinler sayfası (kaynak, Rose)' 'Click: Custom skins page (source, Rose)' } else { T 'Tıkla: şampiyonunun custom skinini seç' "Click: pick your champion's custom skin" })
    }
    $CustomNot.Foreground = Firca $renk
    $AnahtarCustom.IsEnabled = $kurulu
    $AnahtarCustom.IsChecked = ($kurulu -and [bool]$Ayar.custom)
}

$script:MenuGrup = $null
function Custom-Menu($hedef, $k) {
    $liste = (Custom-Gruplar)[$k]
    if (-not $liste) { return }
    $s = Custom-Secili $liste
    $ogeler = @(@{ Metin = (T 'Klasik' 'Base skin'); Deger = ''; Secili = (-not $s) })
    foreach ($m in (Mod-Sirala $liste)) { $ogeler += @{ Metin = $m.Ad; Deger = $m.Id; Secili = [bool]($s -and $s.Id -eq $m.Id) } }
    $script:MenuGrup = $k
    Menu-Ac $hedef $ogeler { param($d) Custom-Sec $script:MenuGrup ([string]$d) }
}
# Seçimler birikir; LTK yeniden başlarken gelen seçim de ardından uygulanır
function Custom-Istek-Ekle($anahtar, $deger) {
    if (-not $script:CustomIstek) { $script:CustomIstek = @{} }
    $script:CustomIstek[$anahtar] = $deger
    Kart-Bas 'custom'
}
function Custom-Sec($k, $modId) {
    $s = Custom-Secili (Custom-Gruplar)[$k]
    if ("$(if ($s) { $s.Id })" -eq "$modId") { return }
    Custom-Istek-Ekle "$k" "$modId"
}

# ---- Custom sayfası: şampiyon şeridi + seçenek kartları ----
$script:CustomOdak = $null   # sayfada seçili şampiyon kimliği (metin) ya da 'diger'
function Yuvarlak-Resim($kaynak, $g, $y, $r) {
    $i = New-Object Windows.Controls.Image
    $i.Width = $g; $i.Height = $y; $i.Stretch = 'UniformToFill'; $i.Source = $kaynak
    $i.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, $g, $y)), $r, $r)
    return $i
}
function Kesik-Kutu($g, $y) {
    $b = New-Object Windows.Shapes.Rectangle
    $b.Width = $g; $b.Height = $y; $b.RadiusX = 6; $b.RadiusY = 6; $b.Fill = Firca '#1A212B'; $b.Stroke = Firca '#3A4452'; $b.StrokeDashArray = [Windows.Media.DoubleCollection]::Parse('3 2')
    return $b
}
# Şeritteki portre: odaktaki yeşil çerçeveli, diğerleri soluk; custom'ı seçili şampiyonda köşede yeşil nokta
function Serit-Ogesi($k, $gruplar) {
    $kok = New-Object Windows.Controls.Grid
    # Sayfanın iç genişliği 388 px (pencere 452 - 2x16 - 2x16); 10 portre 34 + 5 boşlukla sığar, fazlası tekerlekle kayar
    $kok.Width = 34; $kok.Height = 34; $kok.Margin = '0,0,5,0'; $kok.Cursor = 'Hand'; $kok.Background = Firca '#00000000'; $kok.Tag = $k
    if ($k -eq 'diger') {
        [void]$kok.Children.Add((Kesik-Kutu 34 34))
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = T 'Diğer' 'Other'; $t.FontSize = 9; $t.Foreground = Firca $RenkSoluk; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
        [void]$kok.Children.Add($t)
        $kok.ToolTip = T 'Şampiyondan bağımsız modlar' 'Mods not tied to a champion'
    } else {
        [void]$kok.Children.Add((Yuvarlak-Resim (Gorsel 'ikon' $script:SampiyonKod[[int]$k]) 34 34 6))
        $s = Custom-Secili $gruplar[$k]
        $kok.ToolTip = (Sampiyon-Adi ([int]$k)) + ': ' + $(if ($s) { $s.Ad } else { T 'Klasik' 'Base skin' })
        if ($s) {
            $n = New-Object Windows.Shapes.Ellipse
            $n.Width = 10; $n.Height = 10; $n.Fill = Firca $RenkYesil; $n.Stroke = Firca '#141A22'; $n.StrokeThickness = 2
            $n.HorizontalAlignment = 'Right'; $n.VerticalAlignment = 'Bottom'; $n.Margin = '0,0,-3,-3'
            [void]$kok.Children.Add($n)
        }
    }
    $odakta = $k -eq $script:CustomOdak
    if ($odakta) {
        $c = New-Object Windows.Controls.Border
        $c.CornerRadius = 8; $c.BorderThickness = 2; $c.BorderBrush = Firca $RenkYesil; $c.Margin = '-3'; $c.IsHitTestVisible = $false
        [void]$kok.Children.Add($c)
    } else { $kok.Opacity = 0.55 }
    $kok.Add_MouseEnter({ $this.Opacity = 1 })
    $kok.Add_MouseLeave({ if ($this.Tag -ne $script:CustomOdak) { $this.Opacity = 0.55 } })
    $kok.Add_MouseLeftButtonUp({ if (Basildi $this) { $script:CustomOdak = "$($this.Tag)"; Custom-Liste-Olustur; $CustomKaydir.ScrollToTop() } })
    return $kok
}
# Şerit taşarsa fare tekerleği yatay kaydırır
$SampiyonKaydir.Add_PreviewMouseWheel({ $this.ScrollToHorizontalOffset($this.HorizontalOffset - $_.Delta / 3); $_.Handled = $true })
# Klasik skinde görünenler önce, sonra bilinmeyenler, en son belli bir skine bağlı olanlar; kendi içinde ada göre
function Mod-Sirala($liste) {
    return ,@(@($liste) | Sort-Object @{ Expression = { if ($_.Skinler -and ($_.Skinler -contains 0)) { 0 } elseif ($null -eq $_.Skinler -or -not $_.Skinler.Count) { 1 } else { 2 } } }, @{ Expression = { $_.Ad } })
}
# Seçenek kartı: küçük görsel + ad + nerede görüneceği + sağda seçim işareti (ya da "Diğer"de anahtar)
function Secenek-Karti($baslik, $alt, [bool]$uyari, $kaynak, [bool]$secili, $anahtar = $null) {
    $kart = New-Object Windows.Controls.Border
    $kart.CornerRadius = 12; $kart.Padding = '6'; $kart.Margin = '0,0,0,6'; $kart.BorderThickness = 1
    $kart.Background = Firca $(if ($secili) { '#1C232D' } else { '#00000000' })
    $kart.BorderBrush = Firca $(if ($secili) { '#2F3A47' } else { '#00000000' })
    $kart.Uid = if ($secili) { 'secili' } else { '' }
    $g = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = New-Object Windows.GridLength(88)
    $c1 = New-Object Windows.Controls.ColumnDefinition
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2)
    if ($kaynak) { $resim = Yuvarlak-Resim $kaynak 80 46 5 } else { $resim = Kesik-Kutu 80 46 }
    $resim.HorizontalAlignment = 'Left'
    [void]$g.Children.Add($resim)
    $yazi = New-Object Windows.Controls.StackPanel
    $yazi.VerticalAlignment = 'Center'; $yazi.Margin = '2,0,10,0'; [Windows.Controls.Grid]::SetColumn($yazi, 1)
    $b = New-Object Windows.Controls.TextBlock
    $b.Text = $baslik; $b.FontSize = 13.5; $b.TextTrimming = 'CharacterEllipsis'
    if ($secili) { $b.FontWeight = 'SemiBold' }
    $a = New-Object Windows.Controls.TextBlock
    $a.Text = $alt; $a.FontSize = 11.5; $a.Margin = '0,2,0,0'; $a.TextTrimming = 'CharacterEllipsis'
    $a.Foreground = Firca $(if ($uyari) { $RenkTuruncu } else { $RenkSoluk })
    $a.ToolTip = $alt
    [void]$yazi.Children.Add($b); [void]$yazi.Children.Add($a)
    [void]$g.Children.Add($yazi)
    if ($anahtar) { [Windows.Controls.Grid]::SetColumn($anahtar, 2); [void]$g.Children.Add($anahtar) }
    else {
        $isaret = New-Object Windows.Controls.Grid
        $isaret.Width = 18; $isaret.Height = 18; $isaret.VerticalAlignment = 'Center'; $isaret.Margin = '0,0,4,0'
        [Windows.Controls.Grid]::SetColumn($isaret, 2)
        $daire = New-Object Windows.Shapes.Ellipse
        $daire.StrokeThickness = 2
        if ($secili) { $daire.Fill = Firca $RenkYesil; $daire.Stroke = Firca $RenkYesil } else { $daire.Stroke = Firca '#3A4452' }
        [void]$isaret.Children.Add($daire)
        if ($secili) {
            $tik = New-Object Windows.Controls.TextBlock
            $tik.Text = [string][char]0xE73E; $tik.FontFamily = $Pencere.FindResource('IkonFont'); $tik.FontSize = 9; $tik.Foreground = Firca '#06210F'
            $tik.HorizontalAlignment = 'Center'; $tik.VerticalAlignment = 'Center'
            [void]$isaret.Children.Add($tik)
        }
        [void]$g.Children.Add($isaret)
        $kart.Cursor = 'Hand'
        $kart.Add_MouseEnter({ if ($this.Uid -ne 'secili') { $this.Background = Firca '#171E27' } })
        $kart.Add_MouseLeave({ if ($this.Uid -ne 'secili') { $this.Background = Firca '#00000000' } })
        $kart.Add_MouseLeftButtonUp({ if (Basildi $this) { $p = "$($this.Tag)".Split('|'); Custom-Sec $p[0] $p[1] } })
    }
    $kart.Child = $g
    return $kart
}

# Kaynak seçicinin boyası ve sayfanın hangi yarısının görüneceği (LTK: şampiyon şeridi + mod kartları; Rose: Rose paneli)
function Kaynak-Boya {
    $rose = Rose-Kipi
    foreach ($o in @(@($KaynakLtk, $KaynakLtkYazi, (-not $rose)), @($KaynakRose, $KaynakRoseYazi, $rose))) {
        $o[0].Background = Firca $(if ($o[2]) { '#2B3541' } else { '#00000000' })
        $o[0].BorderBrush = Firca $(if ($o[2]) { '#394555' } else { '#00000000' })
        $o[1].Foreground = Firca $(if ($o[2]) { '#FFFFFF' } else { $RenkSoluk })
    }
    $RosePanel.Visibility = if ($rose) { 'Visible' } else { 'Collapsed' }
    $LtkAlt.Visibility = if ($rose) { 'Collapsed' } else { 'Visible' }
    $CustomKaydir.Visibility = if ($rose) { 'Collapsed' } else { 'Visible' }
    if ($rose) { $SampiyonKaydir.Visibility = 'Collapsed' }
}
function Rose-Panel-Guncelle {
    $RoseAciklama.Text = T "Rose oyunun kendi skinlerini açar: skini şampiyon seçiminde LoL'ün içinden seçersin, Rose oyuna yükler. Custom modlarını da Rose'un LoL içindeki menüsünden eklersin. Rose LTK Manager'ı kendisi açıp kapattığı için bu kipte Riot Plus LTK'ya dokunmaz; LTK sayfasındaki seçimlerin durur ama Rose her maçta onları kapatır." "Rose unlocks the game's own skins: pick one in champ select inside LoL and Rose loads it. Add custom mods from Rose's menu inside LoL too. Rose opens and closes LTK Manager itself, so Riot Plus leaves LTK alone in this mode; your picks on the LTK page are kept, but Rose turns them off each game."
    $d = $script:RoseDurum
    $dugme = $null
    if (-not $d.Kurulu) {
        $RoseDurumYazi.Text = T 'Rose kurulu değil' 'Rose is not installed'
        $RoseDurumNot.Text = T "Resmi sürüm yalnız GitHub'da (Alban1911/Rose); başka sitelerdeki kopyalar zararlı yazılım." 'The official release is only on GitHub (Alban1911/Rose); copies on other sites are malware.'
        $dugme = @((T 'İndirme sayfası' 'Download page'), 'indir')
    } elseif (-not (Ltk-Kurulu)) {
        $RoseDurumYazi.Text = T 'LTK Manager kurulu değil' 'LTK Manager is not installed'
        $RoseDurumNot.Text = T "Rose skinleri LTK Manager üzerinden uygular. Kaynağı LTK'ya alıp oradan kurabilirsin." 'Rose applies skins through LTK Manager. Switch the source to LTK to install it.'
    } elseif ($d.Acik) {
        $RoseDurumYazi.Text = (T 'Rose çalışıyor' 'Rose is running') + $(if ($s = Rose-Surum) { " · $s" })
        $RoseDurumNot.Text = if ($script:LtkDurum.Acik) { T "LTK Manager açık (Rose'un oturumu)." "LTK Manager is open (Rose's session)." } else { T "Şampiyon seçiminde LTK'yı kendisi açar, maç bitince kapatır." 'It opens LTK in champ select and closes it after the game.' }
        $dugme = @((T "Rose'u durdur" 'Stop Rose'), 'durdur')
    } else {
        $RoseDurumYazi.Text = (T 'Rose kapalı' 'Rose is not running') + $(if ($s = Rose-Surum) { " · $s" })
        $RoseDurumNot.Text = if ($Ayar.custom) { T "Skin anahtarı açık ama Rose çalışmıyor; başlat." 'The Skin switch is on but Rose is not running; start it.' } else { T "Ana sayfadaki Skin anahtarı da Rose'u açıp kapatır." 'The Skin switch on the home page also starts and stops Rose.' }
        $dugme = @((T "Rose'u başlat" 'Start Rose'), 'baslat')
    }
    if ($dugme) { $RoseDugme.Content = $dugme[0]; $RoseDugme.Tag = $dugme[1]; $RoseDugme.Visibility = 'Visible' } else { $RoseDugme.Visibility = 'Collapsed' }
    $RoseUyari.Text = T "Rose ayrı bir programdır ve yönetici olarak çalışır; başlatırken ve durdururken Windows izin sorar (Rose'un kendi ayarında 'Windows ile başlat' açıksa başlatırken sormaz). Durdurmanın temiz yolu tepsideki Rose simgesinden Quit; buradaki düğme süreci sonlandırır." "Rose is a separate program and runs as administrator; Windows asks for permission when starting and stopping it (not on start if Rose's own 'start with Windows' is on). The clean way to stop it is Quit on Rose's tray icon; the button here ends the process."
}
function Custom-Bilgi-Guncelle {
    Kaynak-Boya
    if (Rose-Kipi) { Rose-Panel-Guncelle; return }
    $kurulu = Ltk-Kurulu
    $son = $script:LtkSon; $surum = Ltk-Surum
    $LtkAc.Visibility = if ($kurulu) { 'Visible' } else { 'Collapsed' }
    $RoseAktar.Visibility = if ($kurulu -and $script:RoseDurum.Kurulu) { 'Visible' } else { 'Collapsed' }
    $ModEkle.IsEnabled = $kurulu
    $ModEkle.Opacity = if ($kurulu) { 1 } else { 0.4 }
    if (-not $kurulu) {
        $metin = T 'Custom skinler için LTK Manager gerekli. Kur dersen resmi sürümü indirir, özetini ve imzasını kontrol edip kurarım.' 'Custom skins need LTK Manager. Install downloads the official release and checks its hash and signature first.'
        if ($son) { $LtkGuncelle.Text = T "LTK $($son.Surum) kur" "Install LTK $($son.Surum)"; $LtkGuncelle.Visibility = 'Visible' } else { $LtkGuncelle.Visibility = 'Collapsed' }
    } else {
        $durum = if (-not $Ayar.custom) { T 'custom kapalı' 'customs off' } elseif (-not $script:LtkDurum.Acik) { T 'LTK kapalı' 'LTK not running' } elseif ($script:LtkDurum.Patcher) { T 'oyuna hazır' 'ready for the game' } elseif ($script:PatcherBekle) { T 'skinler hazırlanıyor' 'preparing skins' } else { T "patcher kapalı; LTK'dan Start'a bas" 'patcher stopped; press Start in LTK' }
        $metin = "LTK $surum · $durum."
        $e = Custom-Engelli-Sayisi
        if ($e) { $metin += T " $e mod LTK'nın skinhack kontrolüne takıldığı için listede yok." " $e mods are hidden because LTK flags them as skinhacks." }
        if ($son -and $surum -and $son.Surum -gt $surum) { $LtkGuncelle.Text = T "$($son.Surum) sürümüne güncelle" "Update to $($son.Surum)"; $LtkGuncelle.Visibility = 'Visible' } else { $LtkGuncelle.Visibility = 'Collapsed' }
    }
    $CustomBilgi.Text = $metin
}

function Custom-Liste-Olustur {
    $SampiyonSerit.Children.Clear(); $CustomListe.Children.Clear()
    if (Rose-Kipi) { Custom-Bilgi-Guncelle; Kahraman-Guncelle; return }
    $gruplar = Custom-Gruplar
    $anahtarlar = @(@($gruplar.Keys | Where-Object { $_ -ne 'diger' } | Sort-Object { Sampiyon-Adi ([int]$_) }) + @(if ($gruplar.ContainsKey('diger')) { 'diger' }))
    # Odak: önceki seçim, yoksa şu anki şampiyon, yoksa ilk sıradaki
    if (-not $script:CustomOdak -or -not $gruplar.ContainsKey($script:CustomOdak)) {
        $simdi = "$(Custom-Sampiyon)"
        $script:CustomOdak = if ($gruplar.ContainsKey($simdi)) { $simdi } elseif ($anahtarlar.Count) { $anahtarlar[0] } else { $null }
    }
    foreach ($k in $anahtarlar) { [void]$SampiyonSerit.Children.Add((Serit-Ogesi $k $gruplar)) }
    $SampiyonKaydir.Visibility = if ($anahtarlar.Count) { 'Visible' } else { 'Collapsed' }
    $k = $script:CustomOdak
    if (-not $k) {
        $bos = New-Object Windows.Controls.TextBlock
        $bos.TextWrapping = 'Wrap'; $bos.Foreground = Firca $RenkSoluk; $bos.Margin = '0,6'
        $bos.Text = if (Ltk-Kurulu) { T "Henüz mod yok. Mod ekle'ye bas ya da .fantome dosyasını buraya sürükle." 'No mods yet. Press Add mod or drop a .fantome file here.' } else { T 'LTK Manager kurulunca modların burada görünür.' 'Your mods show up here once LTK Manager is installed.' }
        [void]$CustomListe.Children.Add($bos)
    } elseif ($k -eq 'diger') {
        foreach ($m in $gruplar[$k]) {
            $a = New-Object Windows.Controls.Primitives.ToggleButton
            $a.Style = $Pencere.FindResource('Anahtar'); $a.Tag = $m.Id; $a.IsChecked = $m.Acik
            $a.Add_Click({ Custom-Istek-Ekle "diger:$($this.Tag)" ([bool]$this.IsChecked) })
            [void]$CustomListe.Children.Add((Secenek-Karti $m.Ad (T 'Şampiyondan bağımsız; açıkken her maçta' 'Not tied to a champion; on in every game') $false (Yerel-Gorsel (Mod-Gorsel-Yolu $m)) $false $a))
        }
    } else {
        $id = [int]$k
        $s = Custom-Secili $gruplar[$k]
        $kart = Secenek-Karti (T 'Klasik' 'Base skin') (T 'Custom yok; oyunun kendi skinleri' "No custom; the game's own skins") $false (Gorsel 'splash' $script:SampiyonKod[$id]) (-not $s)
        $kart.Tag = "$k|"
        [void]$CustomListe.Children.Add($kart)
        foreach ($m in (Mod-Sirala $gruplar[$k])) {
            $gr = Mod-Gorunum $m
            $alt = if ($gr) { $gr.Metin } else { T 'Nerede görüneceği okunamadı' "Couldn't read where it shows" }
            $kart = Secenek-Karti $m.Ad $alt ([bool]($gr -and $gr.Uyari)) (Custom-Gorsel $m $id).Kaynak ([bool]($s -and $s.Id -eq $m.Id))
            $kart.Tag = "$k|$($m.Id)"
            [void]$CustomListe.Children.Add($kart)
        }
    }
    Custom-Bilgi-Guncelle
    Kahraman-Guncelle
}

function Custom-Yenile {
    if ($script:Kapandi) { return }
    Rose-Durum-Oku
    try { Ltk-Oku } catch {}
    Custom-Satir-Guncelle
    if ($CustomGorunum.Visibility -eq 'Visible') { Custom-Liste-Olustur }
}

function Custom-Gorunum-Ac([string]$odak) {
    if ($odak) { $script:CustomOdak = $odak }
    Sekme-Sec 'custom'
}
function Custom-Gorunum-Kapat { Sekme-Sec 'ana' }

# Görseli olmayan (ya da beğenilmeyen) mod için elle görsel: gorsel\custom\el-<modId>-<zaman>.<uzantı>
$script:GorselMod = $null
function Custom-Gorsel-Degistir($m, $islem) {
    if (-not $m) { return }
    $eski = $Ayar.customGorsel[$m.Id]
    if ($islem -eq 'sil') {
        $Ayar.customGorsel.Remove($m.Id); Ayar-Kaydet
        Yaz (T "$($m.Ad) kendi görseline döndü." "$($m.Ad) is back to its own image.") $RenkSoluk
    } else {
        $d = New-Object Microsoft.Win32.OpenFileDialog
        $d.Title = T "$($m.Ad) için görsel seç" "Pick an image for $($m.Ad)"
        $d.Filter = (T 'Görseller' 'Images') + ' (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg'
        if (-not $d.ShowDialog($Pencere)) { return }
        [void](New-Item -ItemType Directory -Force $CustomGorselKlasoru)
        $ad = "el-$($m.Id)-$([DateTime]::Now.Ticks)$([IO.Path]::GetExtension($d.FileName).ToLowerInvariant())"
        Copy-Item -LiteralPath $d.FileName -Destination (Join-Path $CustomGorselKlasoru $ad) -Force
        $Ayar.customGorsel[$m.Id] = $ad; Ayar-Kaydet
        Yaz (T "$($m.Ad) görseli değişti." "$($m.Ad) image updated.") $RenkSoluk
    }
    if ($eski) { Remove-Item -LiteralPath (Join-Path $CustomGorselKlasoru $eski) -ErrorAction SilentlyContinue }
    $script:KahramanKod = $null
    Custom-Liste-Olustur
}
Cevir $GorselDugme 'Görseli değiştir' 'Change image'
Ipucu-Ver $GorselDugme "Bu custom'ın görseli; oyundan aldığın bir ekran görüntüsünü de seçebilirsin." "This custom's image; you can pick an in-game screenshot too."
$GorselDugme.Add_Click({
    $m = Custom-Secili (Custom-Gruplar)[$script:CustomOdak]
    if (-not $m) { return }
    $script:GorselMod = $m
    $ogeler = @(@{ Metin = (T 'Görsel seç…' 'Pick an image…'); Deger = 'sec'; Secili = $false })
    if ($Ayar.customGorsel[$m.Id]) { $ogeler += @{ Metin = (T 'Modun kendi görseline dön' "Back to the mod's own image"); Deger = 'sil'; Secili = $false } }
    Menu-Ac $GorselDugme $ogeler { param($d) Custom-Gorsel-Degistir $script:GorselMod ([string]$d) }
})

# Şampiyon seçimindeyken hızlı menü; başka zaman Custom sayfası o şampiyonla açılır
$CustomNot.Add_MouseLeftButtonUp({
    if (-not (Basildi $this)) { return }
    $id = Custom-Sampiyon
    $var = (-not (Rose-Kipi)) -and (Ltk-Kurulu) -and $Ayar.custom -and $id -and (Custom-Gruplar).ContainsKey("$id")
    if ($var -and $script:SonFaz -eq 'ChampSelect') { Custom-Menu $CustomNot "$id" }
    elseif ($var) { Custom-Gorunum-Ac "$id" }
    else { Custom-Gorunum-Ac }
})
$AnahtarCustom.Add_Click({
    $yeni = [bool]$this.IsChecked
    if (Oyun-Acik) { $this.IsChecked = -not $yeni; Yaz (T 'Maçtayken custom açılıp kapatılamaz.' "Can't toggle customs mid-game.") $RenkTuruncu; return }
    if ((Rose-Kipi) -and (Rose-Mesgul-Faz)) { $this.IsChecked = -not $yeni; Yaz (T 'Seçimdeyken Rose açılıp kapatılmaz; maç bitince dene.' "Rose isn't toggled during champ select; try after the game.") $RenkTuruncu; return }
    $Ayar.custom = $yeni; Ayar-Kaydet
    Custom-Satir-Guncelle
    Kart-Bas $(if ($yeni) { 'custom' } else { 'customkapat' })
})
# "Rakiplerde de görünsün": açıkken seçtiğin her custom o şampiyonu oynayan herkeste görünür (modlar oyun dosyasının yerine geçer).
# Kapalıyken maçta yalnız senin şampiyonunun modu açık; diğer seçimler kayıtta durur, o şampiyona geçince açılır.
Cevir $RakipYazi 'Rakiplerde de görünsün' 'Show on enemies too'
Cevir $LtkKapatYazi 'Riot Plus kapanınca LTK de kapansın' 'Close LTK when Riot Plus closes'
Cevir $LtkKapatNot 'Maç sürüyorsa LTK kapatılmaz.' "LTK stays open if you're in a game."
function Rakip-Not-Guncelle {
    $RakipNot.Text = if ($Ayar.customRakip) { T "Seçtiğin custom'lar o şampiyonu oynayan herkeste görünür." 'Your customs show on anyone playing that champion.' }
                     else { T "Maçta yalnız senin şampiyonunun custom'ı açılır; seçimlerin silinmez." "In a game only your champion's custom is on; your picks are kept." }
}
$AnahtarRakip.IsChecked = [bool]$Ayar.customRakip
Rakip-Not-Guncelle
$AnahtarRakip.Add_Click({
    $yeni = [bool]$this.IsChecked
    if (Oyun-Acik) { $this.IsChecked = -not $yeni; Yaz (T 'Maçtayken değiştirilemez; maç bitince değiştir.' "Can't change this mid-game.") $RenkTuruncu; return }
    $Ayar.customRakip = $yeni; Ayar-Kaydet
    $script:CustomMacSon = 0
    if (-not $yeni) { $script:CustomDaralt = $true }
    Rakip-Not-Guncelle
    Yaz $(if ($yeni) { T "Custom'lar artık herkeste görünür." 'Customs now show on everyone.' } else { T "Custom'lar artık yalnız senin şampiyonunda; maçta kilitlediğin şampiyonunki açılır." "Customs are now yours only; the champion you lock in gets its custom." }) $RenkSoluk
    if ($Ayar.custom -and (Ltk-Kurulu)) { Kart-Bas 'custom' }
})
$AnahtarLtkKapat.IsChecked = [bool]$Ayar.ltkKapat
$AnahtarLtkKapat.Add_Click({
    $Ayar.ltkKapat = [bool]$this.IsChecked; Ayar-Kaydet
    Yaz $(if ($Ayar.ltkKapat) { T 'Riot Plus kapanınca LTK de kapanacak.' 'LTK will close with Riot Plus.' } else { T 'Riot Plus kapanınca LTK açık kalacak.' 'LTK will stay open after Riot Plus closes.' }) $RenkSoluk
})
$ModEkle.Add_Click({
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Title = T 'Custom skin dosyası seç' 'Pick custom skin files'
    $d.Filter = (T 'Mod dosyaları' 'Mod files') + ' (*.fantome, *.modpkg, *.zip)|*.fantome;*.modpkg;*.zip'
    $d.Multiselect = $true
    if ($d.ShowDialog($Pencere)) { $script:EklenecekDosyalar = @($d.FileNames); Kart-Bas 'modekle' }
})
$CustomGorunum.Add_DragOver({
    $_.Effects = if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { 'Copy' } else { 'None' }
    $_.Handled = $true
})
$CustomGorunum.Add_Drop({
    $dosyalar = @(@($_.Data.GetData([Windows.DataFormats]::FileDrop)) | Where-Object { "$_" -match '\.(fantome|modpkg|zip)$' })
    if (Rose-Kipi) { Yaz (T "Rose kipinde modlar Rose'un LoL içindeki menüsünden eklenir. Buradan eklemek için kaynağı LTK yap." "In Rose mode, add mods from Rose's menu inside LoL. Switch the source to LTK to add them here.") $RenkTuruncu }
    elseif ($dosyalar.Count) { $script:EklenecekDosyalar = $dosyalar; Kart-Bas 'modekle' }
    else { Yaz (T 'Yalnız .fantome, .modpkg ya da .zip dosyası alırım.' 'Only .fantome, .modpkg or .zip files.') $RenkTuruncu }
})
$LtkAc.Add_Click({ if (Ltk-Kurulu) { Start-Process -FilePath $LtkExe } })
Cevir $RoseAktar "Rose'a aktar" 'Copy to Rose'
Ipucu-Ver $RoseAktar "Buradaki modları Rose'un custom skin klasörüne kopyalar; Rose'la girdiğinde de seçebilirsin. Daha önce aktarılan yeniden kopyalanmaz." "Copies these mods into Rose's custom skin folder so you can pick them when playing with Rose too. Already copied ones are skipped."
$RoseAktar.Add_Click({ Kart-Bas 'roseaktar' })
# Kaynak seçici: iş zamanlayıcı kuyruğunda çalışır (Rose'u durdurmak / LTK'yı açmak beklemeli işler)
foreach ($k in $KaynakLtk, $KaynakRose) {
    $k.Add_MouseLeftButtonUp({
        if (-not (Basildi $this)) { return }
        if ("$($this.Tag)" -eq "$($Ayar.customKaynak)") { return }
        $script:KaynakIstek = "$($this.Tag)"
        Kart-Bas 'kaynak'
    })
}
Ipucu-Ver $KaynakLtk "Kendi eklediğin modlar (.fantome / .modpkg). Riot Plus hangi şampiyonda hangisinin açık olacağını LTK'ya yazar." "Mods you add yourself (.fantome / .modpkg). Riot Plus tells LTK which one is on for each champion."
Ipucu-Ver $KaynakRose "Rose: oyunun kendi skinleri, seçim LoL'ün içinden. İkisi aynı anda çalışmaz; ikisi de LTK Manager'ı kullanır." "Rose: the game's own skins, picked inside LoL. The two can't run together; both use LTK Manager."
$RoseDugme.Add_Click({
    switch ("$($this.Tag)") {
        'indir'  { Start-Process $RoseIndirUrl }
        'baslat' { if (-not $Ayar.custom) { $Ayar.custom = $true; Ayar-Kaydet; Custom-Satir-Guncelle }; Kart-Bas 'custom' }
        'durdur' { if (Rose-Mesgul-Faz) { Yaz (T 'Seçimde ya da maçtayken Rose durdurulmaz.' "Rose can't be stopped during champ select or a game.") $RenkTuruncu } else { $Ayar.custom = $false; Ayar-Kaydet; Custom-Satir-Guncelle; Kart-Bas 'customkapat' } }
    }
})
$LtkGuncelle.Add_MouseLeftButtonUp({ if (Basildi $this) { Kart-Bas 'ltkkur' } })
$GuncelleSerit.Add_MouseLeftButtonUp({ if (Basildi $this) { Kart-Bas 'ltkkur' } })

# ---- Tepsi ----
$Tepsi = New-Object Windows.Forms.NotifyIcon
$Tepsi.Icon = try { New-Object Drawing.Icon($IkonYolu, [Windows.Forms.SystemInformation]::SmallIconSize) } catch { [Drawing.SystemIcons]::Application }
$Tepsi.Text = $Baslik
$TepsiMenu = New-Object Windows.Forms.ContextMenuStrip
Cevir ($TepsiMenu.Items.Add('', $null, { Goster })) 'Aç' 'Open'
$TepsiSira = $TepsiMenu.Items.Add('', $null, { Kart-Bas $script:EylemIslem })
Cevir $TepsiSira 'Sıraya gir' 'Queue up'
Cevir ($TepsiMenu.Items.Add('', $null, { $Pencere.Close() })) 'Kapat' 'Quit'
$Tepsi.ContextMenuStrip = $TepsiMenu
$Tepsi.Add_MouseClick({ if ($_.Button -eq 'Left') { Goster } })
$Tepsi.Visible = -not $Sessiz   # her zaman görünür: sağ tık menüsü + küçültülmüşken bildirim balonları

# Küçültülmüşse geri getirir, öne alır (tepsi tıkı, kısayolun ikinci açılışı)
function Goster {
    if ($Sessiz) { return }
    if ($Pencere.WindowState -eq 'Minimized') { $Pencere.WindowState = 'Normal' }
    $Pencere.Show()
    [void]$Pencere.Activate()
    $Pencere.Topmost = $true; $Pencere.Topmost = $false
    $h = (New-Object Windows.Interop.WindowInteropHelper($Pencere)).Handle
    [void][LolPencere]::SetForegroundWindow($h)
}

# ---- Aşama takibi: kahraman, ana düğme ve portreler client'ın aşamasına göre değişir ----
$script:SonFaz = $null
$script:SiraDurum = $null
$script:SiraBaslangic = $null
$script:HazirYanit = $null
$script:SecimBilgi = $null
$script:SonSampiyon = 0
$script:LobiRol1 = ''
$script:LobiRol2 = ''

# Şampiyon seçimi oturumundan arayüzün ihtiyacı: benim şampiyonum, kilitli mi, rolüm, kalan süre, banlılar, alınanlar
function Secim-Bilgisi($s) {
    $ben = [int]$s.localPlayerCellId
    $benim = @($s.myTeam) | Where-Object { $_ -and [int]$_.cellId -eq $ben } | Select-Object -First 1
    $banli = @{}; $alinan = @{}; $kilitli = $false; $secim = 0; $pickVar = $false
    foreach ($id in @($s.bans.myTeamBans) + @($s.bans.theirTeamBans)) { if ([int]$id -gt 0) { $banli[[int]$id] = $true } }
    foreach ($grup in @($s.actions)) {
        foreach ($a in @($grup)) {
            if (-not $a) { continue }
            if ($a.type -eq 'ban' -and $a.completed -and [int]$a.championId -gt 0) { $banli[[int]$a.championId] = $true }
            if ($a.type -eq 'pick' -and [int]$a.actorCellId -eq $ben) {
                $pickVar = $true
                if ([int]$a.championId -gt 0) { $secim = [int]$a.championId }
                if ($a.completed) { $kilitli = $true }
            }
        }
    }
    foreach ($o in @($s.myTeam) + @($s.theirTeam)) { if ($o -and [int]$o.cellId -ne $ben -and [int]$o.championId -gt 0) { $alinan[[int]$o.championId] = $true } }
    if (-not $secim -and $benim) { $secim = [int]$benim.championId; if (-not $secim) { $secim = [int]$benim.championPickIntent } }
    # PickVar: senin pick sıran var mı (ARAM gibi şampiyonun atandığı modlarda yok; orada atanan şampiyon kesin sayılır)
    return @{ Benim = $secim; Kilitli = $kilitli; PickVar = $pickVar; Rol = (Rol-Anahtar $benim.assignedPosition); Kalan = [double]$s.timer.adjustedTimeLeftInPhase / 1000; Banli = $banli; Alinan = $alinan }
}

function Faz-Takip {
    $onceki = $script:SonFaz
    if (-not $Deneme -and -not (Surec 'LeagueClientUx')) { $script:SonFaz = $null; $lcu = $null }
    else { $lcu = Lcu-Bilgi; $script:SonFaz = if ($lcu) { Faz-Oku $lcu 1000 } else { $null } }
    $faz = $script:SonFaz
    if ($faz -eq 'Matchmaking' -and $onceki -ne 'Matchmaking') { $script:SiraBaslangic = [DateTime]::Now }
    $script:SiraDurum = $null; $script:HazirYanit = $null
    if ($lcu -and $faz -eq 'Matchmaking') {
        $gecen = if ($script:SiraBaslangic) { ([DateTime]::Now - $script:SiraBaslangic).TotalSeconds } else { 0 }
        $script:SiraDurum = @{ Sure = $gecen; Tahmini = 0 }
        $r = Lcu 'GET' '/lol-lobby/v2/lobby/matchmaking/search-state' $lcu $null 1000
        if ($r.Kod -eq '200') { try { $j = $r.Govde | ConvertFrom-Json; if ([double]$j.timeInQueue -gt 0) { $script:SiraDurum.Sure = [double]$j.timeInQueue }; $script:SiraDurum.Tahmini = [double]$j.estimatedQueueTime } catch {} }
    } elseif ($lcu -and $faz -eq 'ReadyCheck') {
        $r = Lcu 'GET' '/lol-matchmaking/v1/ready-check' $lcu $null 1000
        if ($r.Kod -eq '200') { try { $script:HazirYanit = "$(($r.Govde | ConvertFrom-Json).playerResponse)" } catch {} }
    } elseif ($lcu -and $faz -eq 'ChampSelect') {
        $r = Lcu 'GET' '/lol-champ-select/v1/session' $lcu $null 1000
        if ($r.Kod -eq '200') { try { $script:SecimBilgi = Secim-Bilgisi ($r.Govde | ConvertFrom-Json); if ($script:SecimBilgi.Benim -gt 0) { $script:SonSampiyon = $script:SecimBilgi.Benim } } catch {} }
    } elseif ($lcu -and $faz -eq 'Lobby' -and ($onceki -ne 'Lobby' -or $script:Tik % 5 -eq 0)) {
        $l = Lobi-Oku $lcu
        if ($l) { $script:LobiRol1 = "$($l.localMember.firstPositionPreference)"; $script:LobiRol2 = "$($l.localMember.secondPositionPreference)" }
    }
    if ($faz -ne 'ChampSelect') { $script:SecimBilgi = $null }
    if ($faz -ne $onceki -and $Deneme) { Durum-Guncelle }
    Gorunum-Guncelle
}

# ---- Dil değiştirme ----
function Dil-Sec($d) {
    if ($d -eq $script:Dil) { return }
    $script:Dil = $d
    $Ayar.dil = $d
    Ayar-Kaydet
    Dil-Uygula
    Yaz (T 'Türkçeye geçtim.' 'Switched to English.') $RenkSoluk
}

function Dil-Uygula {
    foreach ($c in $script:Ceviriler) { Metin-Ata $c.K (T $c.Tr $c.En) }
    foreach ($c in $script:Ipuclari) { $c.K.ToolTip = T $c.Tr $c.En }
    $script:Baslik = Baslik-Metni
    $Pencere.Title = $Baslik; $Tepsi.Text = $Baslik
    Dil-Boya
    Oneri-Doldur
    # Şampiyon kutularında kayıtlı adlar yeni dilde gösterilir (tanınmayan, kırmızı yazıya dokunulmaz)
    $script:OneriSeciliyor = $true
    foreach ($c in $script:Seciciler) {
        $id = Secici-Id $c
        if ($id -gt 0) { $ad = Sampiyon-Adi $id; if ($c.Text -ne $ad) { $c.Text = $ad } }
    }
    $script:OneriSeciliyor = $false
    $script:EylemModu = $null
    if ($script:KapatHazir) { Perde-Yazi }
    if ($CustomGorunum.Visibility -eq 'Visible') { Custom-Liste-Olustur }
    Rakip-Not-Guncelle
    Guncelle-Serit
    Gorunum-Guncelle
}

# ---- Klavye: 1-4 sorunlar, 5 ana düğme, Esc küçültür; maç açıkken hiçbiri çalışmaz ----
$Pencere.Add_PreviewKeyDown({
    if ([Windows.Input.Keyboard]::FocusedElement -is [Windows.Controls.TextBox]) { return }
    $k = [int]$_.Key
    $n = -1
    if ($k -ge 35 -and $k -le 39) { $n = $k - 35 }        # D1-D5
    elseif ($k -ge 75 -and $k -le 79) { $n = $k - 75 }    # NumPad1-5
    $esc = $_.Key -eq 'Escape'
    if ($n -lt 0 -and -not $esc) { return }
    $_.Handled = $true
    # Maçtayken kısayollar kapalı: oyunda basılan bir tuş yanlışlıkla buraya düşmesin
    if (-not $Deneme -and (Surec 'League of Legends')) {
        Yaz (T 'Maçtayken tuş kısayolları kapalı.' 'Shortcuts are off during a game.') $RenkSoluk
        return
    }
    if ($esc) { if ($script:Sekme -ne 'ana') { Sekme-Sec 'ana' } else { $Pencere.WindowState = 'Minimized' }; return }
    if ($Duzenleyici.Visibility -eq 'Visible' -or $CustomGorunum.Visibility -eq 'Visible') { return }
    if ($n -eq 4) { Kart-Bas $script:EylemIslem }
    elseif ($Sorunlar[$n].Islem -eq 'ac' -and (Ac-Sorulur)) { Ac-Menu $Sorunlar[$n].Satir }
    else { Kart-Bas $Sorunlar[$n].Islem }
})

# ---- Zamanlayıcı ----
$script:Tik = 0
$Zamanlayici = New-Object Windows.Threading.DispatcherTimer
$Zamanlayici.Interval = [TimeSpan]::FromSeconds(1)
$Zamanlayici.Add_Tick({
    $script:Tik++
    if ($GosterSinyali.WaitOne(0)) { Goster }
    if ($SiraSinyali.WaitOne(0)) { $script:BekleyenIslem = $script:EylemIslem }
    try { Ping-Tick } catch {}
    try { Indirme-Tick } catch {}
    try { Ltk-Surum-Tick } catch {}
    if ($script:Tik % 10800 -eq 0) { try { Ltk-Surum-Sor } catch {} }   # açık kaldıkça 3 saatte bir yeni LTK sorulur
    try { Skin-Adi-Tick } catch {}
    try { Ds-Tick } catch {}
    if (-not $Deneme) { try { Olay-Tick } catch {} }
    if ($script:Tik % 2 -eq 0) { try { Durum-Guncelle } catch {} }
    try { Faz-Takip } catch {}
    try { Custom-Mac-Tick } catch {}
    try { Oto-Tick } catch {
        $m = "$($_.Exception.Message)"
        if ($m -ne $script:OtoHata) { $script:OtoHata = $m; Yaz ((T 'Otomatikte bir sorun çıktı: ' 'Automation hit a snag: ') + $m) $RenkKirmizi }
    }
    if ($script:BekleyenIslem) { $bekleyen = $script:BekleyenIslem; $script:BekleyenIslem = $null; Calistir $bekleyen }
})

function Acilis {
    $script:Yukleniyor = $false
    Durum-Guncelle
    Gorunum-Guncelle
    if (-not $script:SampiyonTr.Count) { Yaz (T 'Şampiyon listesini indiremedim; internet gelince pencereyi yeniden aç.' "Couldn't download the champion list; reopen once you're online.") $RenkTuruncu }
    else { Yaz (T 'Hazırım.' 'Ready.') $RenkSoluk }
    if ($Islem -eq 'sira') { $script:BekleyenIslem = 'sira' }
    # Custom açıksa LTK tepside değilse açılır; LTK'nın yeni sürümü arka planda sorulur
    elseif ($Ayar.custom -and -not $Deneme -and (Ltk-Kurulu)) { $script:BekleyenIslem = 'customhazir' }
    Ltk-Surum-Sor
    $Zamanlayici.Start()
}
$Pencere.Add_ContentRendered({ Acilis })
$Pencere.Add_Closed({
    $script:Kapandi = $true
    $Zamanlayici.Stop(); $KapatSayac.Stop()
    $Tepsi.Visible = $false
    $Tepsi.Dispose()
    try { [void](Ltk-Kapanista-Durdur) } catch {}
})

# Pencereyi göstermeden kökü ölçüp resmini kaydeder (yalnız -Kare)
function Kare-Al($yol) {
    # Not: PowerShell değişken adlarında büyük/küçük harf ayırmaz; arayüzdeki $Kok ile çakışmasın diye $icerik
    $icerik = $Pencere.Content
    $icerik.Measure((New-Object Windows.Size(452, [double]::PositiveInfinity)))
    $icerik.Arrange((New-Object Windows.Rect(0, 0, 452, $icerik.DesiredSize.Height)))
    $icerik.UpdateLayout()
    $script:Kok.Clip = New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0, 0, $script:Kok.ActualWidth, $script:Kok.ActualHeight)), 12, 12)
    Hap-Tasi $false; Camlari-Hizala; $icerik.UpdateLayout()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap(452, [int][Math]::Ceiling($icerik.DesiredSize.Height), 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($icerik)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($yol); $enc.Save($fs); $fs.Close()
}

if ($Sessiz) {
    # Deneme: pencere hiç gösterilmez; zamanlayıcı ve işlemler pencere olmadan çalışır, süreç dışarıdan kapatılır
    Acilis
    if ($Kare) {
        $onek = ($Kare -replace '\.png$', '')
        # Resim alınırken görseller hazır olsun
        $Ayar.custom = $true   # yalnız resim için, kaydedilmez
        try { Ltk-Oku -Zorla } catch {}
        $kullanilan = @($Ayar.banListe) + @($Ayar.pickListe.Values | ForEach-Object { $_ }) + 145 + @((Custom-Gruplar).Keys | Where-Object { $_ -ne 'diger' } | ForEach-Object { [int]$_ })
        foreach ($id in ($kullanilan | Where-Object { $_ -gt 0 } | Select-Object -Unique)) { $kd = $script:SampiyonKod[[int]$id]; try { Gorsel-Hazirla 'ikon' $kd; Gorsel-Hazirla 'splash' $kd } catch {} }
        $script:GorselBellek = @{}; $script:KahramanKod = $null; foreach ($sl in $script:BanSlot + $script:OynaSlot) { $sl.Anahtar = '' }
        foreach ($c in $script:Seciciler) { Secici-Ikon $c (Secici-Id $c) }
        $script:PingGecmis.AddRange([int[]](6, 5, 7, 5, 6, 12, 5, 4, 6, 5, 5, 7, 6, 5, 18, 6, 5, 5, 6, 5))
        $script:SurecDurum = @{ Riot = $true; Lol = 'acik'; Mac = $false }
        Yaz (T 'LoL açıldı abi, iyi eğlenceler.' 'LoL is up, have fun.') $RenkYesil
        $script:SonFaz = 'Lobby'; Gorunum-Guncelle; Kare-Al "$onek-lobi.png"
        $script:SonFaz = 'Matchmaking'; $script:SiraDurum = @{ Sure = 83; Tahmini = 130 }; Yaz (T "Sıradasın: Dereceli tek/çift (Orman / Orta)." "You're in queue.") $RenkYesil; Gorunum-Guncelle; Kare-Al "$onek-sira.png"
        $script:SonFaz = 'ChampSelect'; $script:SecimBilgi = @{ Benim = 145; Kilitli = $true; Rol = 'bottom'; Kalan = 21; Banli = @{ 246 = $true }; Alinan = @{ 29 = $true } }
        Yaz (T "Kai'Sa kilitlendi. İyi oyunlar abi." "Locked in Kai'Sa.") $RenkYesil; Gorunum-Guncelle; Kare-Al "$onek-secim.png"
        $script:SonFaz = 'Lobby'; $script:SecimBilgi = $null; Gorunum-Guncelle
        Duzenle-Ac; Kare-Al "$onek-duzenle.png"; Duzenle-Kapat
        # Custom sayfası: skin splash'ları ve skin adları resimden önce hazır olsun
        foreach ($m in @($script:LtkKutuphane.Modlar)) { if ($m.Ana -and $m.Skinler -and $m.Skinler.Count -and -not ($m.Skinler -contains 0)) { try { Gorsel-Hazirla 'skin' "$($script:SampiyonKod[[int]$m.Ana])_$($m.Skinler[0])" } catch {} } }
        foreach ($k in @((Custom-Gruplar).Keys)) { if ($k -ne 'diger') { try { Gorsel-Hazirla 'splash' $script:SampiyonKod[[int]$k] } catch {} } }
        foreach ($kd in 'Talon', 'Shen') { foreach ($y in @(@('tr', 'tr_TR'), @('en', 'en_US'))) { $r = Istek 'GET' "https://ddragon.leagueoflegends.com/cdn/$($script:DdSurum)/data/$($y[1])/champion/$kd.json" $null $null 8000; if ($r.Kod -eq '200') { [void](Skin-Adi-Isle $kd $y[0] $r.Govde) } } }
        Custom-Gorunum-Ac '91'; Kare-Al "$onek-custom.png"
        Custom-Gorunum-Ac '98'; Kare-Al "$onek-custom-shen.png"; Custom-Gorunum-Kapat
        $script:KapatHazir = $true; $script:KapatBitis = [DateTime]::Now.AddSeconds(3.5)
        $KapatOrtu.Visibility = 'Visible'; $KapatOrtuIc.Width = $KapatSatir.ActualWidth; $KapatOrtu.Width = $KapatSatir.ActualWidth; Perde-Yazi
        Kare-Al "$onek-kapat.png"
        $script:KapatHazir = $false; $KapatOrtu.Visibility = 'Collapsed'
        # LTK güncelleme şeridi (sahte yeni sürüm; dil karesinde de görünür)
        $script:LtkSon = @{ Surum = [version]'9.9.9'; Url = ''; Sha = '' }; Guncelle-Serit; Kare-Al "$onek-guncelle.png"
        Dil-Sec $(if ($script:Dil -eq 'en') { 'tr' } else { 'en' }); Kare-Al "$onek-dil.png"
        $Kilit.ReleaseMutex()
        exit
    }
    [Windows.Threading.Dispatcher]::Run()
} else {
    [void]$Pencere.ShowDialog()
}
$Kilit.ReleaseMutex()
