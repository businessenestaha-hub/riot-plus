// PersistedSettings.json'a Game.cfg ayarı ekler/günceller, biçimi bozmadan.
// node ayar-ekle.mjs <dosya> <bölüm> <ad> <değer> [--dene]
import fs from 'node:fs';
const [dosya, bolum, ad, deger] = process.argv.slice(2);
const dene = process.argv.includes('--dene');
const ham = fs.readFileSync(dosya, 'utf8');
const j = JSON.parse(ham);
const yeniden = JSON.stringify(j, null, 4);
const sonSatir = ham.endsWith('\n') ? '\n' : '';
if (yeniden + sonSatir !== ham) { console.log('UYARI: biçim birebir korunamıyor, durdum'); process.exit(1); }
const s = j.files.find((f) => f.name === 'Game.cfg')?.sections.find((x) => x.name === bolum);
if (!s) { console.log('bölüm yok: ' + bolum); process.exit(1); }
const var_ = s.settings.find((x) => x.name === ad);
if (var_) { console.log(`zaten var: ${ad}=${var_.value} -> ${deger}`); var_.value = deger; }
else {
  let i = s.settings.findIndex((x) => x.name.localeCompare(ad, 'en') > 0);
  if (i < 0) i = s.settings.length;
  s.settings.splice(i, 0, { name: ad, value: deger });
  console.log(`eklendi: ${ad}=${deger} (${bolum} içinde ${i}. sıraya, önceki: ${s.settings[i - 1]?.name}, sonraki: ${s.settings[i + 1]?.name})`);
}
if (dene) { console.log('deneme modu, yazılmadı'); process.exit(0); }
fs.writeFileSync(dosya, JSON.stringify(j, null, 4) + sonSatir, 'utf8');
JSON.parse(fs.readFileSync(dosya, 'utf8'));
console.log('yazıldı ve JSON geçerli');
