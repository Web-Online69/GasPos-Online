// Native fetch only: avoid npm import resolution during Edge Function startup.
// Service credentials remain in the server runtime and are never returned.
type HandlerOptions = {
  url: string;
  serviceRoleKey: string;
  fetchImpl?: typeof fetch;
};
type Member = { user_id: string; role: string; active: boolean };
type AuthUser = { id: string; email?: string; user_metadata?: { username?: string } };
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};
const staffRoles = ['LOGISTIK', 'SALES_SOPIR', 'KEUANGAN'];
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
class SafeError extends Error {
  status: number;
  constructor(message: string, status = 400) { super(message); this.status = status; }
}
export function createHandler({ url, serviceRoleKey, fetchImpl = fetch }: HandlerOptions) {
  const base = url?.replace(/\/$/, '');
  const send = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: cors });
  const adminHeaders = { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}`, 'Content-Type': 'application/json' };
  async function backend(path: string, init: RequestInit = {}, message = 'Layanan akun tidak tersedia') {
    const response = await fetchImpl(base + path, { ...init, headers: { ...adminHeaders, ...init.headers } });
    // Backend errors can contain request values. Never propagate their raw body.
    if (!response.ok) throw new SafeError(message, 502);
    if (response.status === 204) return null;
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  async function member(userId: string): Promise<Member | null> {
    const rows = await backend('/rest/v1/gas_members?select=user_id,role,active&user_id=eq.' + encodeURIComponent(userId));
    if (!Array.isArray(rows)) throw new SafeError('Data akun tidak tersedia', 502);
    return rows.length === 1 ? rows[0] : null;
  }
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
    if (req.method !== 'POST') return send({ error: 'Method not allowed' }, 405);
    try {
      if (!base || !serviceRoleKey) throw new SafeError('Konfigurasi layanan akun belum lengkap', 503);
      const authorization = req.headers.get('Authorization') || '';
      if (!/^Bearer\s+\S+$/i.test(authorization)) throw new SafeError('Login diperlukan', 401);
      const response = await fetchImpl(base + '/auth/v1/user', { headers: { apikey: serviceRoleKey, Authorization: authorization } });
      if (!response.ok) throw new SafeError('Token tidak sah', 401);
      const caller = await response.json();
      if (!caller?.id || !uuidPattern.test(caller.id)) throw new SafeError('Token tidak sah', 401);
      const owner = await member(caller.id);
      if (owner?.role !== 'OWNER' || owner.active !== true) throw new SafeError('Hanya Owner aktif berwenang', 403);
      let body;
      try { body = await req.json(); } catch { throw new SafeError('Permintaan JSON tidak valid'); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new SafeError('Permintaan tidak valid');
      if (body.action === 'list') {
        const members: Member[] = [];
        for (let offset = 0; offset < 100000; offset += 1000) {
          const rows = await backend('/rest/v1/gas_members?select=user_id,role,active&order=role,user_id&limit=1000&offset=' + offset);
          if (!Array.isArray(rows)) throw new SafeError('Data akun tidak tersedia', 502);
          members.push(...rows);
          if (rows.length < 1000) break;
          if (offset === 99000) throw new SafeError('Daftar akun terlalu besar', 502);
        }
        const users: AuthUser[] = [];
        for (let page = 1; page <= 100; page++) {
          const payload = await backend('/auth/v1/admin/users?page=' + page + '&per_page=100');
          if (!Array.isArray(payload?.users)) throw new SafeError('Daftar akun tidak tersedia', 502);
          users.push(...payload.users);
          if (payload.users.length < 100) break;
          if (page === 100) throw new SafeError('Daftar akun terlalu besar', 502);
        }
        const byId = new Map(users.map(user => [user.id, user]));
        return send({ users: members.map(row => {
          const user = byId.get(row.user_id);
          return { user_id: row.user_id, role: row.role, active: row.active,
            username: user?.user_metadata?.username || user?.email || row.user_id.slice(0, 8) };
        }) });
      }
      if (body.action === 'create') {
        const username = typeof body.username === 'string' ? body.username.trim().toLowerCase() : '';
        const password = typeof body.password === 'string' ? body.password : '';
        if (!/^[a-z][a-z0-9_.-]{2,29}$/.test(username) || username === 'owner') throw new SafeError('ID pengguna tidak valid atau dicadangkan');
        if (password.length < 8 || password.length > 72 || new TextEncoder().encode(password).length > 72) throw new SafeError('Password harus 8–72 karakter dan maksimal 72 byte');
        if (!staffRoles.includes(body.role)) throw new SafeError('Peran tidak valid');
        const created = await backend('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({
          email: username + '@users.gaspos.local', password, email_confirm: true, user_metadata: { username },
        }) }, 'Akun tidak dapat dibuat. ID mungkin sudah digunakan atau password tidak memenuhi ketentuan');
        const uid = created?.id;
        if (typeof uid !== 'string' || !uuidPattern.test(uid)) throw new SafeError('Layanan akun tidak mengembalikan ID valid', 502);
        try {
          await backend('/rest/v1/gas_members', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ user_id: uid, role: body.role, active: true }) }, 'Gagal menyimpan hak akses akun');
        } catch {
          try { await backend('/auth/v1/admin/users/' + uid, { method: 'DELETE' }); }
          catch { throw new SafeError('Gagal menyimpan hak akses; akun tanpa keanggotaan perlu dibersihkan administrator', 502); }
          throw new SafeError('Gagal menyimpan hak akses. Akun baru dibatalkan', 502);
        }
        return send({ ok: true, username });
      }
      if (body.action === 'edit') {
        if (typeof body.user_id !== 'string' || !uuidPattern.test(body.user_id)) throw new SafeError('ID akun tidak valid');
        const target = await member(body.user_id);
        if (!target || !staffRoles.includes(target.role)) throw new SafeError('Akun Owner tidak dapat diedit melalui menu petugas', 403);
        const role = body.role;
        if (!staffRoles.includes(role)) throw new SafeError('Peran tidak valid');
        const password = body.password;
        if (password !== undefined && (typeof password !== 'string' || password.length < 8 || password.length > 72 || new TextEncoder().encode(password).length > 72)) throw new SafeError('Password baru harus 8–72 karakter, maksimal 72 byte');
        if (role !== target.role) {
          const changed = await backend('/rest/v1/gas_members?user_id=eq.' + encodeURIComponent(body.user_id) + '&role=in.(LOGISTIK,SALES_SOPIR,KEUANGAN)', {
            method: 'PATCH', headers: { Prefer: 'return=representation' }, body: JSON.stringify({ role }),
          }, 'Gagal mengubah peran');
          if (!Array.isArray(changed) || changed.length !== 1) throw new SafeError('Peran tidak berubah', 409);
        }
        if (password !== undefined) {
          try {
            await backend('/auth/v1/admin/users/' + body.user_id, { method: 'PUT', body: JSON.stringify({ password }) }, 'Gagal mengganti password');
          } catch (error) {
            if (role !== target.role) {
              try { await backend('/rest/v1/gas_members?user_id=eq.' + encodeURIComponent(body.user_id), {
                method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ role: target.role }),
              }); } catch { throw new SafeError('Password gagal diganti. Peran perlu diperiksa ulang oleh Owner', 502); }
            }
            throw error;
          }
        }
        return send({ ok: true });
      }
      if (body.action === 'delete') {
        if (typeof body.user_id !== 'string' || !uuidPattern.test(body.user_id)) throw new SafeError('ID akun tidak valid');
        if (body.user_id === caller.id) throw new SafeError('Akun yang sedang login tidak dapat dihapus', 403);
        const target = await member(body.user_id);
        if (!target || !staffRoles.includes(target.role)) throw new SafeError('Hanya akun petugas yang dapat dihapus', 403);
        // Keep identity and audit trail for every user who has ever handled a transaction.
        const references = [
          ['gas_documents', 'created_by'], ['gas_documents', 'approved_by'],
          ['gas_logistics_requests', 'created_by'], ['gas_logistics_requests', 'reviewed_by'],
          ['gas_operating_expenses', 'created_by'], ['gas_empty_returns', 'created_by'],
          ['gas_purchase_returns', 'created_by'], ['gas_supplier_refunds', 'created_by'],
          ['gas_trip_stops', 'created_by'], ['gas_trip_stops', 'corrected_by'],
          ['gas_trip_stop_audit', 'changed_by'], ['gas_trips', 'returned_by'], ['gas_trips', 'driver_user_id'],
          ['gas_inventory_opening_costs', 'created_by'],
        ];
        for (const [table, column] of references) {
          const rows = await backend('/rest/v1/' + table + '?select=' + column + '&' + column + '=eq.' + encodeURIComponent(body.user_id) + '&limit=1');
          if (!Array.isArray(rows)) throw new SafeError('Pemeriksaan riwayat tidak tersedia', 502);
          if (rows.length) throw new SafeError('Akun memiliki riwayat transaksi. Nonaktifkan saja agar audit tetap utuh', 409);
        }
        // Prevent new work while deleting. If Auth deletion fails, the user remains disabled.
        await backend('/rest/v1/gas_members?user_id=eq.' + encodeURIComponent(body.user_id), {
          method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ active: false }),
        }, 'Gagal mengamankan akun');
        await backend('/auth/v1/admin/users/' + body.user_id, { method: 'DELETE' }, 'Gagal menghapus akun di Auth');
        await backend('/rest/v1/gas_members?user_id=eq.' + encodeURIComponent(body.user_id), {
          method: 'DELETE', headers: { Prefer: 'return=minimal' },
        }, 'Akun Auth terhapus, tetapi keanggotaan perlu dibersihkan');
        return send({ ok: true });
      }
      if (body.action === 'set_active') {
        if (typeof body.user_id !== 'string' || !uuidPattern.test(body.user_id) || typeof body.active !== 'boolean') throw new SafeError('ID akun atau status tidak valid');
        const target = await member(body.user_id);
        if (!target || !staffRoles.includes(target.role)) throw new SafeError('Tidak boleh mengubah Owner atau akun tidak ditemukan', 403);
        const changed = await backend('/rest/v1/gas_members?user_id=eq.' + encodeURIComponent(body.user_id) + '&role=in.(LOGISTIK,SALES_SOPIR,KEUANGAN)', {
          method: 'PATCH', headers: { Prefer: 'return=representation' }, body: JSON.stringify({ active: body.active }),
        }, 'Gagal mengubah status akun');
        if (!Array.isArray(changed) || changed.length !== 1) throw new SafeError('Status akun tidak berubah', 409);
        return send({ ok: true });
      }
      throw new SafeError('Aksi tidak dikenali');
    } catch (error) {
      return error instanceof SafeError ? send({ error: error.message }, error.status) : send({ error: 'Layanan akun tidak tersedia. Coba kembali' }, 502);
    }
  };
}
if (typeof Deno !== 'undefined') {
  Deno.serve(createHandler({ url: Deno.env.get('SUPABASE_URL') || '', serviceRoleKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '' }));
}
