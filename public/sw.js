// Online application: do not intercept or cache authentication, API calls, or transactions.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
