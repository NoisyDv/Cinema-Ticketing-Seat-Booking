<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Cinema Ticketing & Seat Booking – ต้นแบบ UX/UI</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet">
<style>
:root{--bg:#f4f2fa;--card:#fff;--ink:#241f3d;--mute:#6b6585;--line:#ddd8ee;--std:#2a9d8f;--pre:#d9922b;--sel:#e0405a;--taken:#c9c4dc;--acc:#e0405a;--on:#fff}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#1d1833;--card:#2a2347;--ink:#f1eefb;--mute:#a59fc4;--line:#403869;--std:#3cc2b1;--pre:#f2b544;--sel:#ff5d73;--taken:#4a4270;--acc:#ff5d73}}
:root[data-theme="dark"]{--bg:#1d1833;--card:#2a2347;--ink:#f1eefb;--mute:#a59fc4;--line:#403869;--std:#3cc2b1;--pre:#f2b544;--sel:#ff5d73;--taken:#4a4270;--acc:#ff5d73}
:root{box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
html{scroll-padding-top:env(safe-area-inset-top,0px)}
*,*::before,*::after{box-sizing:inherit}
body{margin:0;background:var(--bg);color:var(--ink);font:400 16px/1.6 "IBM Plex Sans Thai",system-ui,sans-serif}
h1,h2,h3,.brand,button{font-family:Prompt,"IBM Plex Sans Thai",sans-serif}
h1{font-size:1.9rem;margin:.2em 0}h2{font-size:1.3rem;margin:0 0 .6em}h3{margin:0;font-size:1.05rem}
header{display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between;padding:14px 20px;border-bottom:1px solid var(--line)}
.brand{font-weight:700;font-size:1.15rem}
nav{display:flex;gap:6px}
nav button,.chip{border:1px solid var(--line);background:transparent;color:var(--ink);padding:7px 14px;border-radius:999px;cursor:pointer;font-size:.9rem}
nav button[aria-current=true],.chip[aria-pressed=true]{background:var(--ink);color:var(--bg);border-color:var(--ink)}
main{max-width:980px;margin:0 auto;padding:20px}
.steps{display:flex;gap:8px;margin:0 0 18px;padding:0;list-style:none;flex-wrap:wrap}
.steps li{padding:5px 12px;border-radius:999px;border:1px solid var(--line);color:var(--mute);font-size:.85rem}
.steps li.on{background:var(--acc);border-color:var(--acc);color:var(--on)}
.steps li.done{color:var(--ink)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px}
.poster{height:120px;border-radius:8px;margin-bottom:12px;display:flex;align-items:flex-end;padding:10px;color:#fff;font-family:Prompt;font-weight:700;font-size:1.6rem}
.meta{color:var(--mute);font-size:.88rem}
.btn{background:var(--acc);color:var(--on);border:0;padding:11px 20px;border-radius:10px;font-size:1rem;cursor:pointer;font-weight:500}
.btn:disabled{opacity:.4;cursor:not-allowed}
.btn.ghost{background:transparent;color:var(--ink);border:1px solid var(--line)}
:focus-visible{outline:3px solid var(--acc);outline-offset:2px}
.times{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0 22px}
.time{border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:10px;padding:8px 14px;cursor:pointer;text-align:left;font-family:inherit}
.time[aria-pressed=true]{border-color:var(--acc);box-shadow:0 0 0 2px var(--acc) inset}
.time small{display:block;color:var(--mute)}
.screen{height:8px;border-radius:50%/100%;background:linear-gradient(var(--mute),transparent);width:70%;margin:6px auto 4px;opacity:.7}
.cap{text-align:center;color:var(--mute);font-size:.8rem;margin-bottom:14px}
.map{overflow-x:auto;padding-bottom:6px}
.rows{display:grid;gap:6px;width:max-content;margin:0 auto}
.row{display:flex;gap:5px;align-items:center}
.rl{width:18px;color:var(--mute);font-size:.8rem}
.seat{width:26px;height:26px;border-radius:7px 7px 4px 4px;border:0;cursor:pointer;background:var(--std);padding:0;font-size:.62rem;color:#fff}
.seat.p{background:var(--pre)}
.seat.t{background:var(--taken);cursor:not-allowed;color:transparent}
.seat[aria-pressed=true]{background:var(--sel);transform:translateY(-2px);box-shadow:0 0 0 2px var(--ink)}
.gap{width:14px}
.legend{display:flex;flex-wrap:wrap;gap:14px;justify-content:center;margin:16px 0;font-size:.85rem;color:var(--mute)}
.legend i{display:inline-block;width:14px;height:14px;border-radius:4px;vertical-align:-2px;margin-right:5px}
.bar{position:sticky;bottom:0;display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px 16px;margin-top:14px}
.two{display:grid;grid-template-columns:1.2fr 1fr;gap:16px}
@media(max-width:720px){.two{grid-template-columns:1fr}}
label{display:block;font-size:.9rem;margin:12px 0 4px}
input,select{width:100%;padding:10px;border-radius:9px;border:1px solid var(--line);background:var(--bg);color:var(--ink);font:inherit}
.pay{display:flex;gap:8px}.pay .chip{flex:1;text-align:center}
.sum{display:flex;justify-content:space-between;padding:4px 0}
.sum.total{border-top:1px dashed var(--line);margin-top:8px;padding-top:10px;font-family:Prompt;font-weight:700;font-size:1.2rem}
.timer{font-family:Prompt;font-weight:700;color:var(--acc)}
.msg{font-size:.85rem;margin-top:6px}.err{color:var(--acc)}.ok{color:var(--std)}
.ticket{display:grid;grid-template-columns:1fr auto;background:var(--card);border:1px solid var(--line);border-radius:16px;overflow:hidden;max-width:620px;margin:0 auto 12px}
.ticket .l{padding:20px}.ticket .r{padding:20px;border-left:2px dashed var(--line);text-align:center;display:flex;flex-direction:column;justify-content:center;gap:4px}
.qr{width:84px;height:84px;background:repeating-conic-gradient(var(--ink) 0 25%,transparent 0 50%) 0 0/16px 16px;border-radius:6px;margin:0 auto}
table{width:100%;border-collapse:collapse}
th,td{text-align:left;padding:10px 8px;border-bottom:1px solid var(--line);font-size:.92rem}
.meter{height:8px;background:var(--line);border-radius:6px;min-width:90px}.meter b{display:block;height:100%;border-radius:6px;background:var(--std)}
.wrap{overflow-x:auto}
[hidden]{display:none!important}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
</head>
<body>
<header>
  <div class="brand">🎬 Cinema Ticketing</div>
  <nav aria-label="เมนูหลัก">
    <button id="nBook" aria-current="true">จองตั๋ว</button>
    <button id="nAdmin">รายงาน Box Office</button>
  </nav>
</header>
<main id="app"></main>

<script>
const GENRE_COL={Action:"#c2410c",Drama:"#7c3aed",Comedy:"#b45309",'Sci-Fi':"#0e7490",Horror:"#9f1239",Animation:"#15803d"};
const movies=[
 {id:1,t:"Movie 1",g:"Drama",d:91},{id:2,t:"Movie 2",g:"Comedy",d:92},{id:3,t:"Movie 3",g:"Sci-Fi",d:93},
 {id:4,t:"Movie 4",g:"Horror",d:94},{id:5,t:"Movie 5",g:"Animation",d:95},{id:6,t:"Movie 6",g:"Action",d:96},
 {id:7,t:"Movie 7",g:"Drama",d:97},{id:8,t:"Movie 8",g:"Comedy",d:98}];
const slots=[["10:30","Hall 3",80,180],["13:15","Hall 7",120,200],["16:00","Hall 12",120,220],["19:20","Hall 18",180,240]];
const promos={CINE10:{type:"percentage",v:10,label:"ลด 10%"},SAVE50:{type:"fixed",v:50,label:"ลด 50 บาท"}};
const baht=n=>"฿"+n.toLocaleString("th-TH");
const S={view:"movies",genre:"ทั้งหมด",movie:null,slot:null,seats:[],promo:null,method:"online",left:600,timer:null,booking:null};
const $=s=>document.querySelector(s), app=$("#app");

function steps(n){const L=["เลือกหนัง","เลือกรอบและที่นั่ง","ชำระเงิน","รับตั๋ว"];
 return `<ol class="steps" aria-label="ขั้นตอนการจอง">${L.map((x,i)=>`<li class="${i+1==n?'on':i+1<n?'done':''}" ${i+1==n?'aria-current="step"':''}>${i+1<n?'✓ ':''}${x}</li>`).join("")}</ol>`}

function movieView(){
 const gs=["ทั้งหมด",...Object.keys(GENRE_COL)], list=movies.filter(m=>S.genre=="ทั้งหมด"||m.g==S.genre);
 app.innerHTML=steps(1)+`<h1>วันนี้ดูอะไรดี</h1><p class="meta">เลือกหนังที่กำลังฉาย แล้วเลือกรอบและที่นั่งในหน้าถัดไป</p>
 <div class="times" role="group" aria-label="กรองตามประเภท">${gs.map(g=>`<button class="chip" aria-pressed="${g==S.genre}" data-g="${g}">${g}</button>`).join("")}</div>
 <div class="grid">${list.map(m=>`<article class="card"><div class="poster" style="background:${GENRE_COL[m.g]}">${m.t.replace("Movie ","#")}</div>
 <h3>${m.t}</h3><div class="meta">${m.g} • ${Math.floor(m.d/60)} ชม. ${m.d%60} นาที</div>
 <button class="btn" style="margin-top:12px;width:100%" data-m="${m.id}">ดูรอบฉาย</button></article>`).join("")||'<p class="meta">ไม่พบหนังในประเภทนี้ ลองเลือกประเภทอื่น</p>'}</div>`;
 app.querySelectorAll("[data-g]").forEach(b=>b.onclick=()=>{S.genre=b.dataset.g;movieView()});
 app.querySelectorAll("[data-m]").forEach(b=>b.onclick=()=>{S.movie=movies.find(m=>m.id==b.dataset.m);S.slot=0;S.seats=[];seatView()});
}

function takenSet(){const s=new Set(),h=S.movie.id*7+S.slot*13,cap=slots[S.slot][2];
 for(let i=1;i<=cap;i++)if((i*h+i*i)%100<28)s.add(i);return s}

function seatView(){
 const [tm,hall,cap,price]=slots[S.slot], taken=takenSet(), per=20, rows=Math.ceil(cap/per), pre=Math.floor(cap*.8);
 let map="";for(let r=0;r<rows;r++){let row=`<div class="row"><span class="rl">${String.fromCharCode(65+r)}</span>`;
  for(let c=1;c<=per;c++){const n=r*per+c;if(n>cap)break;const id=String.fromCharCode(65+r)+c,t=taken.has(n),p=n>pre,sel=S.seats.includes(id);
   row+=(c==11?'<span class="gap"></span>':'')+`<button class="seat ${p?'p':''} ${t?'t':''}" ${t?'disabled':''} aria-pressed="${sel}" aria-label="ที่นั่ง ${id} ${p?'พรีเมียม':'มาตรฐาน'}${t?' ไม่ว่าง':''}" data-s="${id}">${c}</button>`}
  map+=row+"</div>"}
 app.innerHTML=steps(2)+`<button class="btn ghost" id="back">← เลือกหนังอื่น</button>
 <h1>${S.movie.t}</h1><p class="meta">${S.movie.g} • ${S.movie.d} นาที</p>
 <h2>รอบฉายวันนี้</h2><div class="times" role="group" aria-label="รอบฉาย">${slots.map((s,i)=>`<button class="time" aria-pressed="${i==S.slot}" data-t="${i}"><b>${s[0]} น.</b><small>${s[1]} • ${baht(s[3])}/ที่นั่ง</small></button>`).join("")}</div>
 <h2>เลือกที่นั่ง (สูงสุด 3 ที่)</h2><div class="screen"></div><div class="cap">หน้าจอ</div>
 <div class="map"><div class="rows">${map}</div></div>
 <div class="legend"><span><i style="background:var(--std)"></i>มาตรฐาน</span><span><i style="background:var(--pre)"></i>พรีเมียม</span><span><i style="background:var(--sel)"></i>ที่คุณเลือก</span><span><i style="background:var(--taken)"></i>ไม่ว่าง</span></div>
 <div class="bar"><div><b>${S.seats.length?S.seats.join(", "):"ยังไม่ได้เลือกที่นั่ง"}</b><div class="meta" id="hint">${S.seats.length?baht(S.seats.length*price)+" • "+S.seats.length+" ที่นั่ง":"แตะที่นั่งว่างเพื่อเลือก"}</div></div>
 <button class="btn" id="next" ${S.seats.length?"":"disabled"}>ไปชำระเงิน</button></div>`;
 $("#back").onclick=()=>{S.view="movies";movieView()};
 app.querySelectorAll("[data-t]").forEach(b=>b.onclick=()=>{S.slot=+b.dataset.t;S.seats=[];seatView()});
 app.querySelectorAll(".seat:not(.t)").forEach(b=>b.onclick=()=>{const id=b.dataset.s,i=S.seats.indexOf(id);
  if(i>-1)S.seats.splice(i,1);else if(S.seats.length<3)S.seats.push(id);else{$("#hint").textContent="เลือกได้สูงสุด 3 ที่นั่งต่อการจอง";$("#hint").className="meta err";return}
  seatView();document.querySelector(`[data-s="${id}"]`)?.focus()});
 $("#next").onclick=()=>{S.left=600;S.promo=null;payView()};
}

function calc(){const p=slots[S.slot][3],sub=p*S.seats.length;let d=0;
 if(S.promo){d=S.promo.type=="percentage"?Math.round(sub*S.promo.v/100):Math.min(S.promo.v,sub)}return{sub,d,tot:sub-d}}

function payView(){
 const c=calc(), s=slots[S.slot];
 app.innerHTML=steps(3)+`<div class="two"><section class="card"><h2>ข้อมูลผู้จอง</h2>
 <label for="nm">ชื่อ-นามสกุล</label><input id="nm" value="Customer 1" autocomplete="name">
 <label for="em">อีเมล (ใช้ส่งตั๋ว)</label><input id="em" type="email" value="customer1@example.com" autocomplete="email">
 <label for="ph">เบอร์โทร</label><input id="ph" type="tel" value="0800000001" autocomplete="tel">
 <label for="pc">โค้ดส่วนลด</label><div style="display:flex;gap:8px"><input id="pc" placeholder="เช่น CINE10" value="${S.promo?S.promo.code:''}"><button class="btn ghost" id="ap" style="white-space:nowrap">ใช้โค้ด</button></div>
 <div class="msg" id="pm" role="status">${S.promo?`<span class="ok">ใช้โค้ด ${S.promo.code} แล้ว (${S.promo.label})</span>`:'ลองใช้ CINE10 หรือ SAVE50'}</div>
 <label>ช่องทางชำระเงิน</label><div class="pay" role="group">${[["online","ออนไลน์"],["card","บัตร"],["cash","เงินสดที่เคาน์เตอร์"]].map(m=>`<button class="chip" aria-pressed="${S.method==m[0]}" data-p="${m[0]}">${m[1]}</button>`).join("")}</div></section>
 <aside class="card"><h2>สรุปการจอง</h2><div><b>${S.movie.t}</b><div class="meta">${s[0]} น. • ${s[1]}</div><div class="meta">ที่นั่ง ${S.seats.join(", ")}</div></div><hr style="border:0;border-top:1px solid var(--line);margin:12px 0">
 <div class="sum"><span>ตั๋ว ${S.seats.length} ใบ × ${baht(s[3])}</span><span>${baht(c.sub)}</span></div>
 ${c.d?`<div class="sum ok"><span>ส่วนลด</span><span>−${baht(c.d)}</span></div>`:""}
 <div class="sum total"><span>ยอดชำระ</span><span>${baht(c.tot)}</span></div>
 <p class="meta">ที่นั่งถูกถือไว้ให้คุณอีก <span class="timer" id="tm"></span> นาที หลังจากนั้นระบบจะปล่อยที่นั่งให้คนอื่น</p>
 <button class="btn" style="width:100%" id="pay">ชำระเงิน ${baht(c.tot)}</button><button class="btn ghost" style="width:100%;margin-top:8px" id="bk">แก้ไขที่นั่ง</button></aside></div>`;
 const tick=()=>{const m=Math.floor(S.left/60),s2=String(S.left%60).padStart(2,"0");$("#tm").textContent=m+":"+s2;
  if(S.left<=0){clearInterval(S.timer);expiredView()}S.left--};
 clearInterval(S.timer);tick();S.timer=setInterval(tick,1000);
 $("#bk").onclick=()=>{clearInterval(S.timer);seatView()};
 app.querySelectorAll("[data-p]").forEach(b=>b.onclick=()=>{S.method=b.dataset.p;app.querySelectorAll("[data-p]").forEach(x=>x.setAttribute("aria-pressed",x==b))});
 $("#ap").onclick=()=>{const k=$("#pc").value.trim().toUpperCase(),p=promos[k];
  if(p){S.promo={...p,code:k};const keep=S.left;payView();S.left=keep}else{$("#pm").innerHTML='<span class="err">ไม่พบโค้ด "'+k.replace(/</g,"")+'" หรือหมดอายุแล้ว ตรวจตัวสะกดแล้วลองใหม่</span>'}};
 $("#pay").onclick=()=>{clearInterval(S.timer);S.booking="BK"+String(100000+Math.floor(Math.random()*899999));doneView()};
}

function expiredView(){app.innerHTML=steps(3)+`<section class="card" style="max-width:520px;margin:20px auto;text-align:center"><h2>หมดเวลาถือครองที่นั่ง</h2><p class="meta">ที่นั่ง ${S.seats.join(", ")} ถูกปล่อยกลับแล้ว คุณยังเลือกที่นั่งใหม่ได้ทันที</p><button class="btn" id="re">เลือกที่นั่งอีกครั้ง</button></section>`;S.seats=[];$("#re").onclick=seatView}

function doneView(){
 const c=calc(),s=slots[S.slot];
 app.innerHTML=steps(4)+`<h1 style="text-align:center">จองสำเร็จ</h1><p class="meta" style="text-align:center">รหัสการจอง ${S.booking} • ส่งตั๋วไปที่อีเมลแล้ว</p>`+
 S.seats.map(id=>`<article class="ticket"><div class="l"><h3>${S.movie.t}</h3><div class="meta">${s[0]} น. • ${s[1]}</div><div style="margin-top:10px;font-family:Prompt;font-size:1.6rem">ที่นั่ง ${id}</div><div class="meta">${baht(Math.round(c.tot/S.seats.length))} • ชำระแล้ว</div></div><div class="r"><div class="qr" role="img" aria-label="คิวอาร์โค้ดตั๋ว ${id}"></div><small class="meta">${S.booking}</small></div></article>`).join("")+
 `<p style="text-align:center"><button class="btn" id="again">จองเรื่องอื่นต่อ</button></p>`;
 $("#again").onclick=()=>{S.seats=[];S.view="movies";movieView()};
}

function adminView(){
 const rows=movies.map((m,i)=>{const sh=4+i%3,sold=60+i*37%190,cap=sh*110,rev=sold*215;return{m,sh,sold,rev,occ:Math.min(99,Math.round(sold*100/cap*3))}}).sort((a,b)=>b.rev-a.rev);
 const tot=rows.reduce((a,r)=>a+r.rev,0),ts=rows.reduce((a,r)=>a+r.sold,0);
 app.innerHTML=`<h1>รายงาน Box Office</h1><p class="meta">สรุปรายได้และอัตราการครองที่นั่งรายเรื่อง (ข้อมูลตัวอย่างจาก vw_BoxOfficeOccupancyReport)</p>
 <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(170px,1fr));margin:14px 0"><div class="card"><div class="meta">รายได้รวม</div><h2 style="margin:0">${baht(tot)}</h2></div><div class="card"><div class="meta">ตั๋วที่ขายได้</div><h2 style="margin:0">${ts.toLocaleString("th-TH")} ใบ</h2></div><div class="card"><div class="meta">เรื่องที่รายได้สูงสุด</div><h2 style="margin:0">${rows[0].m.t}</h2></div></div>
 <section class="card wrap"><table><thead><tr><th>หนัง</th><th>ประเภท</th><th>รอบฉาย</th><th>ตั๋วที่ขาย</th><th>รายได้</th><th>ที่นั่งถูกครอง</th></tr></thead><tbody>
 ${rows.map(r=>`<tr><td><b>${r.m.t}</b></td><td>${r.m.g}</td><td>${r.sh}</td><td>${r.sold}</td><td>${baht(r.rev)}</td><td><div style="display:flex;gap:8px;align-items:center"><div class="meter"><b style="width:${r.occ}%"></b></div>${r.occ}%</div></td></tr>`).join("")}</tbody></table></section>`;
}

function nav(v){clearInterval(S.timer);$("#nBook").setAttribute("aria-current",v=="book");$("#nAdmin").setAttribute("aria-current",v=="admin");v=="admin"?adminView():movieView()}
$("#nBook").onclick=()=>nav("book");$("#nAdmin").onclick=()=>nav("admin");
movieView();
</script>
</body>
</html>