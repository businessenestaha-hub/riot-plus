// Riot Plus (eski LoL Düzelt) otomatiklerini gerçek maç olmadan denemek için sahte LoL client yerel API'si (LCU).
// Kullanım: node sahte-lcu.mjs  → deneme\istemci\ altına lockfile + ayarlar.json yazar, senaryoyu oynatır, sonucu basar.
// Araç ayrıca şöyle açılmalı: powershell -File ..\lol-duzelt.ps1 -DenemeKlasoru <bu klasör>\istemci
// ARAC=1 ise aracı kendisi penceresiz (-Sessiz) açar ve sonunda kapatır; DIL=en ise arayüz İngilizce.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const klasor = path.join(path.dirname(fileURLToPath(import.meta.url)), 'istemci');
const PORT = 52999, SIFRE = 'deneme-sifre';
const BEKLE_ILK = Number(process.env.BEKLE_ILK || 6000);

fs.mkdirSync(klasor, { recursive: true });
fs.writeFileSync(path.join(klasor, 'lockfile'), `LeagueClient:1:${PORT}:${SIFRE}:http`);
fs.writeFileSync(path.join(klasor, 'ayarlar.json'), JSON.stringify({
  dil: process.env.DIL || 'tr', kabul: true, ban: true, banListe: [238, 157, 777], pick: true, kilitle: true, bekleSn: 0,
  pickListe: { top: [0, 0, 0], jungle: [0, 0, 0], middle: [103, 134, 61], bottom: [0, 0, 0], utility: [0, 0, 0], genel: [99, 0, 0] },
}, null, 2));

let faz = 'None', hazir = null, oturum = null, secilebilir = null;
const kayit = [], sonPatch = {}, bosKilit = [];

function oturumYap({ ben, rol, aksiyonlar, niyetler = {}, banlar = { myTeamBans: [], theirTeamBans: [] } }) {
  const takim = (bas) => [0, 1, 2, 3, 4].map(i => ({
    cellId: bas + i, championId: 0, championPickIntent: niyetler[bas + i] || 0,
    assignedPosition: bas === 0 && bas + i === ben ? rol : (bas === 0 ? ['top', 'jungle', 'middle', 'bottom', 'utility'][i] : ''),
  }));
  return { localPlayerCellId: ben, myTeam: takim(0), theirTeam: takim(5), actions: aksiyonlar, bans: banlar,
    timer: { phase: 'PLANNING', adjustedTimeLeftInPhase: 30000 } };
}
const aksiyon = (id, actorCellId, type, ek = {}) => ({ id, actorCellId, type, championId: 0, completed: false, isInProgress: false, isAllyAction: actorCellId < 5, ...ek });
const tumAksiyonlar = () => oturum.actions.flat();

const sunucu = http.createServer((istek, cevap) => {
  let govde = '';
  istek.on('data', p => govde += p);
  istek.on('end', () => {
    const yol = istek.url;
    const yaz = (kod, veri) => { cevap.writeHead(kod, { 'Content-Type': 'application/json' }); cevap.end(veri === undefined ? '' : JSON.stringify(veri)); };
    if (istek.headers.authorization !== 'Basic ' + Buffer.from('riot:' + SIFRE).toString('base64')) return yaz(401, { message: 'yetkisiz' });
    if (istek.method !== 'GET') kayit.push({ zaman: Date.now(), yontem: istek.method, yol, govde });

    if (yol === '/lol-gameflow/v1/gameflow-phase') return yaz(200, faz);
    if (yol === '/lol-matchmaking/v1/ready-check') return hazir ? yaz(200, hazir) : yaz(404, { message: 'yok' });
    if (yol === '/lol-matchmaking/v1/ready-check/accept' && istek.method === 'POST') { if (hazir) hazir.playerResponse = 'Accepted'; return yaz(204); }
    if (yol === '/lol-champ-select/v1/session') return oturum ? yaz(200, oturum) : yaz(404, { message: 'yok' });
    if (yol === '/lol-champ-select/v1/pickable-champion-ids') return yaz(200, secilebilir || [103, 134, 61, 99, 22, 157, 238, 777]);
    // Gerçek client ban aşaması dışında [-1] döndürüyor (3 Kas 2026 maçta görüldü); araç buna güvenmemeli
    if (yol === '/lol-champ-select/v1/bannable-champion-ids') return yaz(200, [-1]);
    // Kilit ayrı uçtan: gerçek client PATCH'teki "completed"i yok sayıyor (3 Kas 2026 maçta görüldü).
    // 5 Kas 2026 gerçek maç logu: PATCH'ten hemen sonra (≈60 ms) gelen /complete "lockIn championId: 0" olarak gidiyor
    // ve sessizce boşa düşüyor (2xx döner, aksiyon tamamlanmaz). Planlamada (PLANNING) ban seçimi/kilidi de yok sayılır.
    const mc = yol.match(/^\/lol-champ-select\/v1\/session\/actions\/(\d+)\/complete$/);
    if (mc && istek.method === 'POST' && oturum) {
      const a = tumAksiyonlar().find(x => x.id === Number(mc[1]));
      if (!a || a.actorCellId !== oturum.localPlayerCellId) return yaz(404, { message: 'aksiyon yok' });
      if (!a.isInProgress) return yaz(500, { message: 'sıran değil' });
      if (oturum.timer.phase === 'PLANNING') { bosKilit.push(a.id); return yaz(204); }
      if (Date.now() - (sonPatch[a.id] || 0) < 500) { bosKilit.push(a.id); return yaz(204); }   // lockIn 0
      if (!(a.championId > 0)) { bosKilit.push(a.id); return yaz(204); }
      a.completed = true; a.isInProgress = false;
      return yaz(204);
    }
    const m = yol.match(/^\/lol-champ-select\/v1\/session\/actions\/(\d+)$/);
    if (m && istek.method === 'PATCH' && oturum) {
      const a = tumAksiyonlar().find(x => x.id === Number(m[1]));
      if (!a || a.actorCellId !== oturum.localPlayerCellId) return yaz(404, { message: 'aksiyon yok' });
      const b = JSON.parse(govde || '{}');
      if (a.type === 'ban' && oturum.timer.phase === 'PLANNING') return yaz(204);   // planlamada ban seçimi yok sayılır
      if (b.championId !== undefined) {
        a.championId = b.championId;
        sonPatch[a.id] = Date.now();
        if (a.type === 'pick' && !a.isInProgress) oturum.myTeam.find(o => o.cellId === a.actorCellId).championPickIntent = b.championId;
      }
      return yaz(204);   // "completed" bilerek yok sayılır (gerçek client gibi)
    }
    yaz(404, { message: 'bilinmeyen: ' + yol });
  });
});

const uyu = ms => new Promise(r => setTimeout(r, ms));
const sonuclar = [];
function kontrol(ad, kosul, ayrinti = '') { sonuclar.push({ ad, tamam: !!kosul }); console.log(`${kosul ? 'GEÇTİ ' : 'KALDI '} ${ad}${ayrinti ? '  — ' + ayrinti : ''}`); }
function yeniKayit(bas) { return kayit.filter(k => k.zaman >= bas); }
const ozet = l => l.map(k => `${k.yontem} ${k.yol} ${k.govde}`).join(' | ') || '(istek yok)';
// Kilitleme: POST .../complete gitti ve aksiyon gerçekten o şampiyonla tamamlandı mı (seçim PATCH'i önceden ya da niyetten)
const kilitlendi = (t, id, sampiyon) => yeniKayit(t).some(k => k.yontem === 'POST' && k.yol.endsWith(`/actions/${id}/complete`))
  && tumAksiyonlar().some(a => a.id === id && a.completed && a.championId === sampiyon);

async function senaryo() {
  await uyu(BEKLE_ILK);   // aracın açılmasını bekle

  // 1) Maç bulundu → kabul
  let t = Date.now(); faz = 'ReadyCheck'; hazir = { state: 'InProgress', playerResponse: 'None', timer: 3 };
  await uyu(3000);
  kontrol('1 maç bulundu → otomatik kabul', yeniKayit(t).some(k => k.yol.endsWith('/ready-check/accept')) && hazir.playerResponse === 'Accepted', ozet(yeniKayit(t)));

  // 2) Sen reddettiysen dokunmaz
  t = Date.now(); hazir = { state: 'InProgress', playerResponse: 'Declined', timer: 5 };
  await uyu(2500);
  kontrol('2 reddedilmiş maça dokunmaz', yeniKayit(t).length === 0, ozet(yeniKayit(t)));
  faz = 'Matchmaking'; hazir = null; await uyu(1500);

  // 3) Dereceli taslak: planlama → niyet (Orta listesi: Ahri). Gerçek client'taki gibi ban aksiyonu planlamada da "isInProgress".
  const banlar = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(c => aksiyon(1 + c, c, 'ban', { isInProgress: true }));
  oturum = oturumYap({ ben: 2, rol: 'middle', niyetler: { 0: 238 }, aksiyonlar: [banlar, [aksiyon(11, 0, 'pick')], [aksiyon(12, 5, 'pick'), aksiyon(13, 6, 'pick')], [aksiyon(14, 1, 'pick'), aksiyon(15, 2, 'pick')]] });
  t = Date.now(); faz = 'ChampSelect';
  await uyu(3500);
  kontrol('3 planlamada niyet: Ahri', yeniKayit(t).some(k => k.yol.endsWith('/actions/15') && k.govde === '{"championId":103}'), ozet(yeniKayit(t)));
  kontrol('3b planlamada ban denenmez (client yok sayıyor)', !yeniKayit(t).some(k => /\/actions\/3(\/complete)?$/.test(k.yol)), ozet(yeniKayit(t)));

  // 4) Ban aşaması: Zed'i takım arkadaşı istiyor → Yasuo banlanmalı; seçim ve kilit ayrı turda (boş kilit yok)
  t = Date.now(); oturum.timer.phase = 'BAN_PICK'; const bos4 = bosKilit.length;
  await uyu(4000);
  kontrol('4 ban: arkadaşın istediği Zed atlanır, Yasuo banlanır', kilitlendi(t, 3, 157) && yeniKayit(t).some(k => k.yol.endsWith('/actions/3') && k.govde === '{"championId":157}'), ozet(yeniKayit(t)));
  kontrol('4b kilit seçimle aynı anda gitmez (boş "lockIn 0" yok)', bosKilit.length === bos4, `boş kilit: ${bosKilit.length - bos4}`);

  // 5) Rakip Ahri'yi banladı → niyet Syndra'ya geçmeli
  banlar.forEach(a => { if (!a.completed) { a.completed = true; a.isInProgress = false; a.championId = a.actorCellId === 6 ? 103 : 0; } });
  oturum.bans = { myTeamBans: [157], theirTeamBans: [103] };
  t = Date.now();
  await uyu(3000);
  kontrol('5 seçilen niyet banlanınca sıradakine (Syndra) geçer', yeniKayit(t).some(k => k.yol.endsWith('/actions/15') && k.govde === '{"championId":134}'), ozet(yeniKayit(t)));

  // 6) Sıra bende → Syndra kilitlenmeli
  t = Date.now(); tumAksiyonlar().find(a => a.id === 15).isInProgress = true;
  await uyu(3000);
  kontrol('6 sıra gelince Syndra kilitlenir', kilitlendi(t, 15, 134), ozet(yeniKayit(t)));

  // 7) Maç → yeni seçim (kör seçim, rol yok); kullanıcı kendisi Ashe'nin üzerine gelmiş → Ashe kilitlenmeli
  faz = 'InProgress'; oturum = null; await uyu(2500);
  oturum = oturumYap({ ben: 0, rol: '', aksiyonlar: [[0, 1, 2, 3, 4].map(c => aksiyon(21 + c, c, 'pick', { isInProgress: true, championId: c === 0 ? 22 : 0 }))] });
  oturum.timer.phase = 'BAN_PICK';
  t = Date.now(); faz = 'ChampSelect';
  await uyu(3000);
  kontrol('7 kör seçimde senin seçtiğin (Ashe) kilitlenir', kilitlendi(t, 21, 22), ozet(yeniKayit(t)));

  // 8) Yeni kör seçim; Rolsüz listesi (Lux) senin elinde yok → hiçbir şey yapılmamalı
  faz = 'Lobby'; oturum = null; await uyu(2500);
  secilebilir = [103, 134, 61, 22];
  oturum = oturumYap({ ben: 0, rol: '', aksiyonlar: [[0, 1, 2, 3, 4].map(c => aksiyon(31 + c, c, 'pick', { isInProgress: true }))] });
  oturum.timer.phase = 'BAN_PICK';
  t = Date.now(); faz = 'ChampSelect';
  await uyu(3000);
  kontrol('8 listedeki şampiyon sende yoksa seçmez', yeniKayit(t).length === 0, ozet(yeniKayit(t)));

  // 9) Aynı durumda Lux açılırsa (yeni seçim) Lux kilitlenir
  faz = 'Lobby'; oturum = null; secilebilir = null; await uyu(2500);
  oturum = oturumYap({ ben: 0, rol: '', aksiyonlar: [[0, 1, 2, 3, 4].map(c => aksiyon(41 + c, c, 'pick', { isInProgress: true }))] });
  oturum.timer.phase = 'BAN_PICK';
  t = Date.now(); faz = 'ChampSelect';
  await uyu(3000);
  kontrol('9 kör seçimde Rolsüz listesi (Lux) kilitlenir', kilitlendi(t, 41, 99), ozet(yeniKayit(t)));

  faz = 'None'; oturum = null;
  const gecen = sonuclar.filter(s => s.tamam).length;
  console.log(`\nSONUÇ: ${gecen}/${sonuclar.length} geçti`);
  if (arac) arac.kill();
  sunucu.close(); process.exit(gecen === sonuclar.length ? 0 : 1);
}

let arac = null;
sunucu.listen(PORT, '127.0.0.1', () => {
  console.log(`sahte LCU http://127.0.0.1:${PORT}, klasör ${klasor}`);
  if (process.env.ARAC) {
    arac = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', process.env.ARAC_YOL || path.join(path.dirname(klasor), '..', 'lol-duzelt.ps1'), '-DenemeKlasoru', klasor, '-Sessiz']);
    arac.stdout.on('data', d => process.stdout.write('  [araç] ' + d.toString('utf8')));
    arac.stderr.on('data', d => process.stdout.write('  [araç HATA] ' + d.toString('utf8')));
  }
  senaryo();
});
