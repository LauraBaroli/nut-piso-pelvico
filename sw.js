/* NUT · Service Worker (bundle) — cachea el cascarón; NUNCA cachea datos de salud (Supabase). */
const CACHE='nut-shell-v2';
const SHELL=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',(e)=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',(e)=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',(e)=>{const req=e.request;if(req.method!=='GET')return;const url=new URL(req.url);
  if(url.hostname.includes('supabase'))return;                 // datos de salud: siempre a la red
  if(url.hostname.includes('cdn.jsdelivr.net')){e.respondWith(caches.match(req).then(h=>h||fetch(req).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(req,c));return r;}).catch(()=>h)));return;}
  if(url.origin===self.location.origin){e.respondWith(caches.match(req).then(h=>h||fetch(req).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(req,c));return r;}).catch(()=>req.mode==='navigate'?caches.match('./index.html'):undefined)));}
});
