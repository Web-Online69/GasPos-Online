// GASPOS is online-only: no fetch interception and no cached login, API, or transaction data.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
