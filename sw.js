const CACHE='scoutlab-sports-v081';
const CORE=['./','./index.html','./manifest.webmanifest','./broadcast_rights_database.json','./app-icon.svg','./app-icon-192.png','./app-icon-512.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('scoutlab-sports-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);
 if(url.origin!==location.origin||request.method!=='GET'||url.pathname.startsWith('/proxy')||url.pathname.startsWith('/update/'))return;
 if(request.mode==='navigate'){
   event.respondWith(fetch(request,{cache:'no-store'}).then(response=>{if(response.ok)caches.open(CACHE).then(cache=>cache.put('./index.html',response.clone()));return response}).catch(()=>caches.match('./index.html')));
   return;
 }
 event.respondWith(caches.match(request).then(cached=>cached||fetch(request).then(response=>{if(response.ok)caches.open(CACHE).then(cache=>cache.put(request,response.clone()));return response}).catch(()=>cached)));
});
