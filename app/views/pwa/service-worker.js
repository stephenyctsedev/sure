// Bump CACHE_VERSION to force-clear all caches across clients (e.g. if asset
// path structure changes). Normal deploys do NOT need a bump — Rails content
// hashes handle staleness. Note: old fingerprinted entries in ASSET_CACHE
// accumulate between version bumps; the browser will evict them under storage
// pressure, but bump the version periodically to clean up proactively.
const CACHE_VERSION = 'v1';
const ASSET_CACHE = `assets-${CACHE_VERSION}`;
const OFFLINE_CACHE = `offline-${CACHE_VERSION}`;

const OFFLINE_ASSETS = [
  '/offline.html',
  '/logo-offline.svg'
];

// Install event - cache offline assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(OFFLINE_CACHE).then((cache) => {
      return cache.addAll(OFFLINE_ASSETS);
    }).then(() => self.skipWaiting())
  );
});

// Activate event - clean up caches from old versions
self.addEventListener('activate', (event) => {
  const currentCaches = [ASSET_CACHE, OFFLINE_CACHE];
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => !currentCaches.includes(name))
          .map((name) => caches.delete(name))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - three strategies: cache-first for assets, cache-first for
// offline assets, network-first with offline fallback for navigation
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Cache-first for fingerprinted Rails assets (/assets/*)
  if (url.pathname.startsWith('/assets/')) {
    event.respondWith(
      caches.open(ASSET_CACHE).then((cache) => {
        return cache.match(event.request).then((cached) => {
          if (cached) return cached;
          return fetch(event.request).then((response) => {
            // Only cache successful responses
            if (response.ok) {
              cache.put(event.request, response.clone());
            }
            return response;
          }).catch(() => new Response('', { status: 503, statusText: 'Offline' }));
        });
      })
    );
    return;
  }

  // Cache-first for offline assets (/offline.html, /logo-offline.svg)
  if (OFFLINE_ASSETS.some((asset) => url.pathname === asset)) {
    event.respondWith(
      caches.match(event.request).then((cached) => cached || fetch(event.request))
    );
    return;
  }

  // Navigation requests - network with offline fallback
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match('/offline.html');
      })
    );
  }
});
