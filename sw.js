/* NUT · Service Worker (bundle v3)
   - HTML/navegación: NETWORK-FIRST → las actualizaciones llegan siempre; offline usa la copia en caché.
   - Íconos/estáticos: cache-first.
   - NUNCA cachea llamadas a Supabase (datos de salud siempre a la red). */
const CACHE='nut-shell-v3';
const SHELL=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',(e)=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',(e)=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',(e)=>{
  const req=e.request; if(req.method!=='GET')return;
  const url=new URL(req.url);
  if(url.hostname.includes('supabase'))return;                       // datos de salud: red directa
  if(url.hostname.includes('cdn.jsdelivr.net')){                     // lib externa: cache-first
    e.respondWith(caches.match(req).then(h=>h||fetch(req).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(req,c));return r;}).catch(()=>h)));return;
  }
  if(url.origin===self.location.origin){
    if(req.mode==='navigate' || req.destination==='document'){       // HTML: network-first
      e.respondWith(fetch(req).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(req,c));return r;}).catch(()=>caches.match(req).then(h=>h||caches.match('./index.html'))));return;
    }
    e.respondWith(caches.match(req).then(h=>h||fetch(req).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(req,c));return r;}).catch(()=>undefined)));  // estáticos: cache-first
  }
});
