// Riot Plus "Sıraya gir" denemesi: sahte LoL client yerel API'si (lobi + sıra uçları) kurar,
// her senaryoda aracı penceresiz (-Sessiz -Islem sira) açar, istekleri ve günlük yazısını kontrol eder, kapatır.
// Kullanım: node sahte-sira.mjs          (DIL=en → İngilizce arayüzle)
// Gerçek client'a hiçbir şey gitmez: araç yalnız deneme\istemci\lockfile'daki sahte porta bağlanır.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const burasi = path.dirname(fileURLToPath(import.meta.url));
const klasor = path.join(burasi, 'istemci');
const betik = path.join(burasi, '..', 'lol-duzelt.ps1');
const PORT = 52999, SIFRE = 'deneme-sifre';
const DIL = process.env.DIL === 'en' ? 'en' : 'tr';

fs.mkdirSync(klasor, { recursive: true });
fs.writeFileSync(path.join(klasor, 'lockfile'), `LeagueClient:1:${PORT}:${SIFRE}:http`);

// ---- sahte client durumu ----
let faz, lobi, hatirla, aramaHatasi, dusukOncelik, kayit = [];
function sifirla() { faz = 'None'; lobi = null; hatirla = ['UNSELECTED', 'UNSELECTED']; aramaHatasi = null; dusukOncelik = 0; kayit = []; }
function lobiYap(queueId, lider = true) {
  return {
    gameConfig: { queueId, showPositionSelector: queueId !== 450, maxLobbySize: queueId === 420 ? 2 : 5 },
    localMember: { isLeader: lider, firstPositionPreference: hatirla[0], secondPositionPreference: hatirla[1] },
    members: [{}], canStartActivity: true,
  };
}

const sunucu = http.createServer((istek, cevap) => {
  let govde = '';
  istek.on('data', p => govde += p);
  istek.on('end', () => {
    const yol = istek.url, y = istek.method;
    const yaz = (kod, veri) => { cevap.writeHead(kod, { 'Content-Type': 'application/json' }); cevap.end(veri === undefined ? '' : JSON.stringify(veri)); };
    if (istek.headers.authorization !== 'Basic ' + Buffer.from('riot:' + SIFRE).toString('base64')) return yaz(401, { message: 'yetkisiz' });
    if (y !== 'GET') kayit.push(`${y} ${yol} ${govde}`.trim());

    if (yol === '/lol-gameflow/v1/gameflow-phase') return yaz(200, faz);
    if (yol === '/lol-lobby/v2/lobby' && y === 'GET') return lobi ? yaz(200, lobi) : yaz(404, { message: 'LOBBY_NOT_FOUND' });
    if (yol === '/lol-lobby/v2/lobby' && y === 'POST') {
      const q = JSON.parse(govde || '{}').queueId;
      lobi = lobiYap(q); faz = 'Lobby';
      return yaz(200, lobi);
    }
    if (yol === '/lol-lobby/v2/lobby/members/localMember/position-preferences' && y === 'PUT') {
      if (!lobi) return yaz(404, { message: 'LOBBY_NOT_FOUND' });
      const b = JSON.parse(govde || '{}');
      hatirla = [b.firstPreference, b.secondPreference];
      lobi.localMember.firstPositionPreference = b.firstPreference;
      lobi.localMember.secondPositionPreference = b.secondPreference;
      return yaz(201);
    }
    if (yol === '/lol-lobby/v2/lobby/matchmaking/search' && y === 'POST') {
      if (!lobi) return yaz(404, { message: 'LOBBY_NOT_FOUND' });
      if (!lobi.localMember.isLeader) return yaz(400, { message: 'NOT_LEADER' });
      const m = lobi.localMember;
      if (lobi.gameConfig.showPositionSelector && (m.firstPositionPreference === 'UNSELECTED' || (m.firstPositionPreference !== 'FILL' && m.secondPositionPreference === 'UNSELECTED')))
        return yaz(400, { message: 'INVALID_POSITION_PREFERENCES' });
      if (!aramaHatasi) faz = 'Matchmaking';
      return yaz(204);
    }
    if (yol === '/lol-lobby/v2/lobby/matchmaking/search' && y === 'DELETE') {
      if (faz !== 'Matchmaking') return yaz(400, { message: 'NOT_SEARCHING' });
      faz = 'Lobby'; return yaz(204);
    }
    if (yol === '/lol-lobby/v2/lobby/matchmaking/search-state') {
      return yaz(200, { searchState: faz === 'Matchmaking' ? 'Searching' : (aramaHatasi ? 'Error' : 'Invalid'),
        errors: aramaHatasi ? [aramaHatasi] : [], lowPriorityData: { penaltyTimeRemaining: dusukOncelik } });
    }
    yaz(404, { message: 'bilinmeyen: ' + yol });
  });
});

// ---- araç ----
function ayarYaz(ek) {
  fs.writeFileSync(path.join(klasor, 'ayarlar.json'), JSON.stringify({
    dil: DIL, kabul: false, ban: false, pick: false, kilitle: true, bekleSn: 0, sira: 420, rol1: '', rol2: 'FILL', ...ek,
  }, null, 2));
}
function aracAc(ekArg = ['-Islem', 'sira']) {
  const a = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', betik, '-DenemeKlasoru', klasor, '-Sessiz', ...ekArg]);
  a.cikti = '';
  a.stdout.on('data', d => { a.cikti += d.toString('utf8'); });
  a.stderr.on('data', d => { a.cikti += '[HATA] ' + d.toString('utf8'); });
  a.bitti = new Promise(r => a.on('exit', r));
  return a;
}
const uyu = ms => new Promise(r => setTimeout(r, ms));
async function bekleYazi(arac, desen, sure = 30000) {
  const son = Date.now() + sure;
  while (Date.now() < son) { if (desen.test(arac.cikti)) return true; await uyu(200); }
  return false;
}

const sonuclar = [];
function kontrol(ad, kosul, ayrinti) {
  sonuclar.push(!!kosul);
  console.log(`${kosul ? 'GEÇTİ' : 'KALDI'}  ${ad}`);
  if (!kosul) console.log('       ' + ayrinti.replace(/\n/g, '\n       '));
}
const L = (tr, en) => DIL === 'en' ? en : tr;

// Her senaryo: hazırlık, beklenen günlük yazısı, beklenen istekler
const senaryolar = [
  { ad: 'boşta → lobi 420 + roller Orta/Alt + sıra',
    hazirla: () => ayarYaz({ rol1: 'MIDDLE', rol2: 'BOTTOM' }),
    yazi: L(/Sıradasın: Dereceli tek\/çift \(Orta \/ Alt\)\./, /You're in queue: Ranked solo\/duo \(Mid \/ Bot\)\./),
    istek: k => k.includes('POST /lol-lobby/v2/lobby {"queueId":420}') && k.includes('PUT /lol-lobby/v2/lobby/members/localMember/position-preferences {"firstPreference":"MIDDLE","secondPreference":"BOTTOM"}') && k.includes('POST /lol-lobby/v2/lobby/matchmaking/search') && faz === 'Matchmaking' },
  { ad: 'sıradaysa sıradan çıkar',
    hazirla: () => { ayarYaz({}); faz = 'Matchmaking'; lobi = lobiYap(420); },
    yazi: L(/Sıradan çıktın\./, /Left the queue\./),
    istek: k => k.length === 1 && k[0] === 'DELETE /lol-lobby/v2/lobby/matchmaking/search' && faz === 'Lobby' },
  { ad: 'şampiyon seçimindeyse dokunmaz',
    hazirla: () => { ayarYaz({}); faz = 'ChampSelect'; },
    yazi: L(/sıraya giremem/, /can't queue/), istek: k => k.length === 0 },
  { ad: 'ARAM lobisinden 420\'ye geçer; rol seçili değilse sıraya girmez',
    hazirla: () => { ayarYaz({ rol1: '' }); faz = 'Lobby'; lobi = lobiYap(450); },
    yazi: L(/Rolün seçili değil/, /No role selected/),
    istek: k => k.includes('POST /lol-lobby/v2/lobby {"queueId":420}') && !k.some(x => x.includes('matchmaking/search')) },
  { ad: 'lider değilse dokunmaz',
    hazirla: () => { ayarYaz({ rol1: 'TOP', rol2: 'JUNGLE' }); faz = 'Lobby'; lobi = lobiYap(420, false); },
    yazi: L(/parti lideri/, /party leader/), istek: k => k.length === 0 },
  { ad: 'ARAM: rol göndermeden sıraya girer',
    hazirla: () => ayarYaz({ sira: 450, rol1: 'MIDDLE', rol2: 'TOP' }),
    yazi: L(/Sıradasın: ARAM\./, /You're in queue: ARAM\./),
    istek: k => k.includes('POST /lol-lobby/v2/lobby {"queueId":450}') && !k.some(x => x.includes('position-preferences')) && k.includes('POST /lol-lobby/v2/lobby/matchmaking/search') },
  { ad: '1. rol Fark etmez → 2. rol gönderilmez',
    hazirla: () => ayarYaz({ rol1: 'FILL', rol2: 'TOP' }),
    yazi: L(/Sıradasın: Dereceli tek\/çift \(Fark etmez\)\./, /You're in queue: Ranked solo\/duo \(Fill\)\./),
    istek: k => k.includes('PUT /lol-lobby/v2/lobby/members/localMember/position-preferences {"firstPreference":"FILL","secondPreference":"UNSELECTED"}') },
  { ad: "client'taki gibi: hatırlanan Orman/Üst ile girer, rol göndermez",
    hazirla: () => { ayarYaz({ rol1: '' }); hatirla = ['JUNGLE', 'TOP']; },
    yazi: L(/Sıradasın: Dereceli tek\/çift \(Orman \/ Üst\)\./, /You're in queue: Ranked solo\/duo \(Jungle \/ Top\)\./),
    istek: k => !k.some(x => x.includes('position-preferences')) && k.includes('POST /lol-lobby/v2/lobby/matchmaking/search') },
  { ad: 'sıra cezası okunur yazılır',
    hazirla: () => { ayarYaz({ rol1: 'MIDDLE', rol2: 'BOTTOM' }); aramaHatasi = { errorType: 'QUEUE_DODGER', penaltyTimeRemaining: 200 }; },
    yazi: L(/Sıraya giremedim: sıra cezası var, 3 dk 20 sn kaldı/, /Couldn't queue: queue penalty, 3 min 20 s left/),
    istek: k => k.includes('POST /lol-lobby/v2/lobby/matchmaking/search') && faz !== 'Matchmaking' },
  { ad: 'düşük öncelik süresi bildirilir',
    hazirla: () => { ayarYaz({ rol1: 'MIDDLE', rol2: 'BOTTOM' }); dusukOncelik = 300; },
    yazi: L(/Önce 5 dk 0 sn düşük öncelik beklemen var/, /First you'll wait 5 min 0 s in low priority/),
    istek: k => faz === 'Matchmaking' },
];

async function calistir() {
  for (const s of senaryolar) {
    sifirla(); s.hazirla();
    const a = aracAc();
    const yaziOk = await bekleYazi(a, s.yazi);
    await uyu(300);
    const istekOk = s.istek(kayit);
    a.kill(); await a.bitti;
    kontrol(s.ad, yaziOk && istekOk, `yazı ${yaziOk ? 'tamam' : 'YOK'}, istek ${istekOk ? 'tamam' : 'YANLIŞ'}\nistekler: ${kayit.join(' | ') || '(yok)'}\nçıktı:\n${a.cikti.trim()}`);
  }

  // İkinci açılış: araç zaten açıkken "-Islem sira" ile açılan ikinci kopya, açık olana sinyal yollayıp çıkar
  sifirla(); ayarYaz({ rol1: 'MIDDLE', rol2: 'BOTTOM' });
  const ilk = aracAc([]);
  const hazir = await bekleYazi(ilk, L(/Hazır/, /Ready/));
  const ikinci = aracAc();
  const ikinciCikti = await Promise.race([ikinci.bitti.then(() => true), uyu(15000).then(() => false)]);
  const ok = hazir && ikinciCikti && await bekleYazi(ilk, L(/Sıradasın/, /You're in queue/), 15000);
  kontrol('ikinci açılış sinyali: açık olan kopya sıraya girer, ikinci kopya kapanır', ok, `ilk hazır ${hazir}, ikinci çıktı ${ikinciCikti}\nistekler: ${kayit.join(' | ')}\nilk çıktı:\n${ilk.cikti.trim()}`);
  // Aynı kopyaya ikinci kez "sıraya gir": sıradayken sıradan çıkar
  await uyu(1500);
  const ucuncu = aracAc();
  await ucuncu.bitti;
  const cikti = await bekleYazi(ilk, L(/Sıradan çıktın/, /Left the queue/), 15000);
  ilk.kill(); if (!ikinciCikti) ikinci.kill(); await ilk.bitti;
  kontrol('sıradayken yeniden basınca sıradan çıkar', cikti && faz === 'Lobby', `faz ${faz}\nistekler: ${kayit.join(' | ')}\nilk çıktı:\n${ilk.cikti.trim()}`);

  const gecen = sonuclar.filter(Boolean).length;
  console.log(`\nSONUÇ (${DIL}): ${gecen}/${sonuclar.length} geçti`);
  sunucu.close(); process.exit(gecen === sonuclar.length ? 0 : 1);
}

sunucu.listen(PORT, '127.0.0.1', () => { console.log(`sahte LCU http://127.0.0.1:${PORT}, dil ${DIL}`); calistir(); });
