const expiredMessage = 'Sesi Owner sudah berakhir. Silakan masuk kembali sebagai Owner, lalu ulangi perubahan. Password baru belum tersimpan.';

// Refresh a stale session once. Account mutations are retried only after a 401,
// which means authentication was rejected before the operation was authorized.
export function createMemberRequest(api, {onSessionExpired = () => {}} = {}) {
  const failure = message => ({data:null, error:{message}});
  async function expired() {
    // Local scope preserves other Owner sessions on other devices.
    try { await api.auth.signOut({scope:'local'}); } catch {}
    onSessionExpired(expiredMessage);
    return failure(expiredMessage);
  }
  return async function memberRequest(options) {
    try {
      const sessionResult = await api.auth.getSession();
      let session = sessionResult.data?.session;
      if (sessionResult.error || !session?.access_token) return await expired();
      let result = await api.functions.invoke('gaspos-invite-member', {
        ...options, headers:{...options?.headers, Authorization:'Bearer '+session.access_token},
      });
      if (result.error?.context?.status === 401) {
        const refreshed = await api.auth.refreshSession();
        session = refreshed.data?.session;
        if (refreshed.error || !session?.access_token) return await expired();
        result = await api.functions.invoke('gaspos-invite-member', {
          ...options, headers:{...options?.headers, Authorization:'Bearer '+session.access_token},
        });
        if (result.error?.context?.status === 401) return await expired();
      }
      if (!result.error) return result;
      let payload;
      try { payload = await result.error.context?.clone().json(); } catch {}
      const status = result.error.context?.status;
      if (status === 403) return failure(payload?.error || 'Akun ini tidak memiliki izin Owner aktif.');
      const message = typeof payload?.error === 'string' ? payload.error
        : typeof result.data?.error === 'string' ? result.data.error
        : status ? 'Perubahan belum tersimpan. Layanan akun menolak permintaan ('+status+'). Silakan coba kembali.'
        : 'Tidak dapat terhubung ke layanan akun. Periksa koneksi, lalu coba kembali.';
      return {data:payload || result.data, error:{message}};
    } catch {
      return failure('Perubahan belum tersimpan. Periksa koneksi dan coba kembali.');
    }
  };
}
