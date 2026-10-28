// Do not expose a second login form while a previous session is still being checked.
export async function restoreStartupSession(api,{showLoading,showLogin,enter}) {
 if(!api){showLogin('Koneksi Supabase belum dikonfigurasi.');return}
 showLoading();
 let response;
 try{response=await api.auth.getUser()}catch{showLogin('Tidak dapat memeriksa sesi. Silakan masuk kembali.');return}
 if(response.error||!response.data?.user){showLogin();return}
 await enter(response.data.user);
}
