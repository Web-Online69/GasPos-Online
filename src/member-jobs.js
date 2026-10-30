export const jobLabels={OWNER:'Owner',LOGISTIK:'Logistik',SALES_SOPIR:'Sales / Sopir',KEUANGAN:'Keuangan'};
export const staffJobs=['LOGISTIK','SALES_SOPIR','KEUANGAN'];
export function assignedJobs(member){return Array.isArray(member.assigned_roles)&&member.assigned_roles.length?member.assigned_roles:[member.role];}
export function jobChoices(selected=['LOGISTIK']){return '<fieldset class="job-role-choices"><legend>Tugas pengguna (boleh lebih dari satu)</legend>'+staffJobs.map(role=>'<label class="job-role-choice"><input type="checkbox" name="assigned-job" value="'+role+'" '+(selected.includes(role)?'checked':'')+'><span>'+jobLabels[role]+'</span></label>').join('')+'</fieldset>';}
export function selectedJobs(form){return [...form.querySelectorAll('input[name="assigned-job"]:checked')].map(x=>x.value).filter(x=>staffJobs.includes(x));}
export function activeJob(roles,current){return roles.includes(current)?current:roles[0];}
export function jobSwitcher(role,roles){return roles.length>1?'<label class="active-job-label">Tugas aktif<select id="active-job-switch" aria-label="Tugas aktif">'+roles.filter(r=>staffJobs.includes(r)).map(r=>'<option value="'+r+'" '+(r===role?'selected':'')+'>'+jobLabels[r]+'</option>').join('')+'</select><span id="active-job-message" role="status"></span></label>':'';}
