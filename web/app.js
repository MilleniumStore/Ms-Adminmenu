const $=s=>document.querySelector(s), app=$('#app'), content=$('#content');
const state={page:'dashboard',data:null,selected:null,pending:new Map(),query:'',loading:{},history:{players:[],ping:[]}};
const pages=[
  ['dashboard','◇','Dashboard'],['players','♙','Players'],['reports','◌','Reports'],
  ['punishments','⊘','Punishments'],['vehicles','▱','Vehicles'],['world','◎','World'],
  ['economy','◫','Economy'],['server','⌁','Server'],['audit','≡','Audit Log']
];
const post=(event,data={})=>fetch(`https://${GetParentResourceName()}/${event}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const time=s=>{s=Number(s)||0;const h=Math.floor(s/3600),m=Math.floor(s%3600/60);return `${h}h ${m}m`};
let announcementTimer;
let staffWarningTimer;

function toast(message,kind='info'){post('notify',{message,kind,title:'Admin System',duration:4500}).catch(()=>{})}
function showAnnouncement(message){
  const banner=$('#announcement');
  $('#announcement-message').textContent=message;
  banner.classList.remove('show');
  void banner.offsetWidth;
  banner.classList.add('show');
  clearTimeout(announcementTimer);
  announcementTimer=setTimeout(()=>banner.classList.remove('show'),8000);
}
function showStaffWarning(message){
  const screen=$('#staff-warning');
  $('#staff-warning-message').textContent=message;
  screen.classList.remove('show');
  void screen.offsetWidth;
  screen.classList.add('show');
  clearTimeout(staffWarningTimer);
  staffWarningTimer=setTimeout(()=>screen.classList.remove('show'),3000);
}
function nav(){ $('#nav').innerHTML=pages.map(([id,icon,label])=>`<button data-page="${id}" class="${state.page===id?'active':''}"><span>${icon}</span>${label}</button>`).join('');
  $('#nav').querySelectorAll('button').forEach(b=>b.onclick=()=>{state.page=b.dataset.page;state.selected=null;render()})}
function points(values,width=560,height=92){
  const safe=values.length>1?values:[...(values.length?values:[0]),...(values.length?values:[0])];
  const min=Math.min(...safe),max=Math.max(...safe),range=Math.max(max-min,1);
  return safe.map((v,i)=>`${(i/(safe.length-1))*width},${height-((v-min)/range)*(height-18)-9}`).join(' ');
}
function remember(d){
  state.history.players.push(Number(d.players)||0);state.history.ping.push(Number(d.averagePing)||0);
  if(state.history.players.length>24){state.history.players.shift();state.history.ping.shift()}
}
function metric(label,value,sub='Live',tone=''){return `<div class="card metric ${tone}"><div class="metric-head"><p>${label}</p><span>LIVE</span></div><strong>${value}</strong><small>${sub}</small></div>`}
function title(eye,name){$('#breadcrumb').textContent=eye;$('#title').textContent=name}
function render(){
  nav(); const d=state.data;if(!d)return;
  if(state.page==='dashboard')return dashboard();
  if(state.page==='players')return players();
  if(state.page==='reports')return reportPage();
  return modulePage();
}
function dashboard(){
  title('OVERVIEW','Command Dashboard');const d=state.data.dashboard;
  const playerPct=Math.min(100,Math.round((d.players/Math.max(d.maxPlayers,1))*100));
  content.innerHTML=`<div class="metrics">${metric('Players online',`${d.players} / ${d.maxPlayers}`,`${playerPct}% capacity`)}${metric('Staff online',d.staff,'On active duty')}${metric('Active reports',d.reports,d.reports?'Requires attention':'Queue clear',d.reports?'warn':'')}${metric('Average ping',`${d.averagePing} ms`,d.averagePing<80?'Healthy latency':'Elevated latency',d.averagePing>=80?'warn':'')}</div>
  <div class="grid dashboard-grid"><section class="card runtime-card"><div class="section-title"><div><p>SERVER HEALTH</p><h2>Runtime overview</h2></div><span class="tag">Operational</span></div>
  <div class="activity"><div class="activity-row"><i></i><span>Framework bridge</span><small>${esc(d.framework)}</small></div><div class="activity-row"><i></i><span>Database adapter</span><small>${esc(d.database)}</small></div><div class="activity-row"><i></i><span>Resources running</span><small>${d.resources}</small></div><div class="activity-row"><i></i><span>Server uptime</span><small>${time(d.uptime)}</small></div></div></section>
  <section class="card"><div class="section-title"><div><p>OPERATIONS</p><h2>Quick actions</h2></div></div><div class="quick-grid">
  <button class="action-button" data-quick="announce"><b>↗</b>Announcement<span>Message all players</span></button><button class="action-button" data-pagego="players"><b>⌕</b>Find player<span>Open player directory</span></button><button class="action-button" data-pagego="reports"><b>◌</b>Report queue<span>Review active cases</span></button><button class="action-button" data-quick="duty"><b>◉</b>Duty status<span>Toggle availability</span></button></div></section>
  <section class="card performance-card"><div class="section-title"><div><p>LIVE TELEMETRY</p><h2>Population & latency</h2></div><div class="legend"><span><i class="players"></i>Players</span><span><i class="latency"></i>Ping</span></div></div>
  <div class="chart"><svg viewBox="0 0 560 100" preserveAspectRatio="none" aria-label="Live server telemetry"><g class="grid-lines"><line x1="0" y1="20" x2="560" y2="20"/><line x1="0" y1="50" x2="560" y2="50"/><line x1="0" y1="80" x2="560" y2="80"/></g><polyline class="latency-line" points="${points(state.history.ping)}"/><polyline class="players-line" points="${points(state.history.players)}"/></svg></div>
  <div class="telemetry-footer"><span>Updates on refresh</span><span>${state.history.players.length} samples this session</span></div></section></div>`;
  content.querySelectorAll('[data-pagego]').forEach(b=>b.onclick=()=>{state.page=b.dataset.pagego;render()});
  content.querySelector('[data-quick=announce]').onclick=()=>formModal('Server announcement','Send a message to every connected player',[['message','Message','textarea']],v=>action('announce',v));
  content.querySelector('[data-quick=duty]').onclick=()=>action('duty',{});
}
function players(){
  title('MANAGEMENT','Player Directory');const list=state.data.players.filter(p=>(`${p.id} ${p.name} ${p.rockstar} ${p.job}`).toLowerCase().includes(state.query.toLowerCase()));
  if(state.selected===null&&list.length)state.selected=list[0].id;
  const selected=state.data.players.find(p=>p.id===state.selected);
  const roster=`<section class="card player-browser"><div class="toolbar"><input id="player-search" class="input" placeholder="Search ID or player name..." value="${esc(state.query)}"></div><div class="player-count"><span>${list.length} Players</span><span>${state.data.players.length} online</span></div><div class="player-list">${list.map(p=>`<button class="player-row ${state.selected===p.id?'selected':''}" data-id="${p.id}"><span class="player-avatar">${esc((p.name||'?')[0])}</span><span><b>${esc(p.name)}${p.id===state.data.players[0]?.id?' (You)':''}</b><small>${esc(p.rockstar)} · ${p.ping}ms</small></span><em>#${p.id}</em></button>`).join('')||'<div class="empty">No players found.</div>'}</div></section>`;
  const detail=selected?`<section class="player-detail">
    <div class="player-hero"><div class="hero-avatar">${esc((selected.name||'?')[0])}</div><div><h2>${esc(selected.name)}</h2><p>Server ID: ${selected.id} · Ping: ${selected.ping} ms · ${esc(selected.rockstar)}</p></div><div class="hero-badges"><span class="tag">ONLINE</span>${selected.duty?'<span class="tag">STAFF DUTY</span>':''}</div></div>
    <div class="info-grid">
      <article class="card info-card"><h3>Character Information <span>♟</span></h3><div class="info-line"><span>Name</span><b>${esc(selected.name)}</b></div><div class="info-line"><span>Character ID</span><b>#${selected.id}</b></div><div class="info-line"><span>Job</span><b>${esc(selected.job)} ${esc(selected.grade)}</b></div><div class="info-line"><span>Status</span><b>Online</b></div></article>
      <article class="card info-card"><h3>Accounts <span style="color:var(--accent)">$</span></h3><div class="balance"><span>bank</span><b>$${Number(selected.bank).toLocaleString()}</b></div><div class="balance"><span>cash</span><b>$${Number(selected.cash).toLocaleString()}</b></div><div class="balance"><span>ping</span><b>${selected.ping} ms</b></div></article>
      <article class="card info-card"><h3>Notes <span style="color:var(--accent)">✎</span></h3><p class="notes">No notes recorded for this player.</p></article>
    </div>
    <div class="action-strip"><button class="secondary" data-a="message">✉ Message</button><button class="warn" data-a="warn">⚠ Warn</button><button class="secondary" data-a="heal">✚ Heal</button><button class="kick" data-a="kick">↪ Kick</button><button class="ban" data-a="ban">⊘ Ban</button></div>
    <div class="action-groups">
      <div class="action-row"><button class="secondary" data-a="teleport">⌖ Teleport</button><button class="secondary" data-a="bring">⇢ Bring</button><button class="secondary" data-a="spectate">◉ Spectate</button><button class="secondary" data-a="freeze">❄ Freeze</button><button class="secondary" data-a="revive">✚ Revive</button></div>
      <div class="action-row"><button class="secondary" data-a="item">▣ Inventory</button><button class="secondary" data-a="vehicle_give">＋ Give Vehicle</button><button class="secondary" data-a="money">$ Transactions</button><button class="secondary" data-a="setjob">▾ Set Job</button><button class="secondary" data-a="kill">☠ Kill</button></div>
    </div>
  </section>`:'<section class="card empty-detail"><div class="empty">Select a player to view details and actions.</div></section>';
  content.innerHTML=`<div class="players-layout">${roster}${detail}</div>`;
  $('#player-search').oninput=e=>{state.query=e.target.value;players()};
  content.querySelectorAll('.player-row').forEach(r=>r.onclick=()=>{state.selected=Number(r.dataset.id);players()});
  content.querySelectorAll('[data-a]').forEach(b=>b.onclick=()=>playerAction(b.dataset.a,selected));
}
function playerAction(kind,p){
  const base={target:p.id};
  if(['teleport','bring','spectate','freeze','heal','revive','kill'].includes(kind))return confirmModal(`${kind[0].toUpperCase()+kind.slice(1)} ${p.name}?`,'This action is recorded in the audit log.',()=>action(kind,base));
  if(kind==='message')return formModal('Private admin message',`Send a message to ${p.name}.`,[['message','Message','textarea']],v=>action(kind,{...base,...v}));
  if(kind==='money')return formModal('Adjust player balance','All amounts are validated by the server.',[['operation','Operation','select',['add','remove']],['account','Account','select',['cash','bank']],['amount','Amount','number'],['reason','Reason','textarea']],v=>action(kind,{...base,...v}));
  if(kind==='item')return formModal('Inventory management','Uses the configured server inventory provider.',[['operation','Operation','select',['add','remove']],['item','Item name','text'],['amount','Amount','number'],['reason','Reason','textarea']],v=>action(kind,{...base,...v}));
  if(kind==='setjob')return formModal('Set player job','Job and grade are validated by the active framework.',[['job','Job name','text'],['grade','Grade','number'],['reason','Reason','textarea']],v=>action(kind,{...base,...v}));
  if(kind==='vehicle_give')return formModal('Give player a vehicle','Spawns the requested networked vehicle at the player.',[['model','Vehicle model','text']],v=>action(kind,{...base,...v}));
  if(kind==='ban')return formModal('Ban player','A reason and optional evidence are stored permanently.',[['duration','Duration','select',[['3600','1 hour'],['86400','1 day'],['604800','7 days'],['2592000','30 days'],['0','Permanent']]],['reason','Reason','textarea'],['evidence','Evidence URL / reference','text']],v=>action(kind,{...base,...v}));
  formModal(`${kind==='warn'?'Warn':'Kick'} player`,`This action affects ${p.name}.`,[['reason','Reason','textarea']],v=>action(kind,{...base,...v}));
}
function reportPage(){
  title('CASE CENTRE','Player Reports');const reports=Object.values(state.data.reports||{});
  content.innerHTML=`<div class="table-wrap"><table><thead><tr><th>Case</th><th>Player</th><th>Category</th><th>Message</th><th>Claimed by</th><th>Status</th><th></th></tr></thead><tbody>${reports.map(r=>`<tr><td>#${r.id}</td><td>${esc(r.player)} [${r.source}]</td><td>${esc(r.category)}</td><td>${esc(r.message)}</td><td>${esc(r.claimedBy||'Unassigned')}</td><td><span class="tag ${r.status==='closed'?'off':''}">${esc(r.status)}</span></td><td>${r.status==='open'?`<button class="secondary" data-claim="${r.id}">Claim</button>`:`${r.status!=='closed'?`<button class="secondary" data-close="${r.id}">Resolve</button>`:''}`}</td></tr>`).join('')}</tbody></table>${reports.length?'':'<div class="empty">The report queue is clear.</div>'}</div>`;
  content.querySelectorAll('[data-claim]').forEach(b=>b.onclick=()=>action('report',{id:b.dataset.claim,operation:'claim'}));
  content.querySelectorAll('[data-close]').forEach(b=>b.onclick=()=>formModal('Resolve report','Record the outcome for the audit trail.',[['reason','Resolution','textarea']],v=>action('report',{id:b.dataset.close,operation:'close',...v})));
}
function modulePage(){
  const info={
    punishments:['COMPLIANCE','Punishment History','Punishment records are stored in SQL. Online warnings and bans are available from the Player Directory.'],
    vehicles:['OPERATIONS','Vehicle Management','Vehicle controls require a selected network entity. This integration is disabled until an entity selection provider is configured.'],
    world:['ENVIRONMENT','World Controls','World-wide destructive controls are intentionally unavailable in this release configuration.'],
    economy:['FINANCE','Economy Management','Validated player balance actions are available from the Player Directory.'],
    server:['INFRASTRUCTURE','Server Management',state.data.config.features.resourceManagement?'Allowed resource controls are enabled.':'Resource management is disabled by default in config.lua.'],
    audit:['SECURITY','Audit Log','Audit records are written to millennium_audit. Connect a database-backed audit query policy before exposing sensitive records to NUI.']
  }[state.page]; title(info[0],info[1]);
  if(state.page==='punishments'){
    if(!state.data.punishments&&!state.loading.punishments){state.loading.punishments=true;action('load_punishments',{})}
    const rows=state.data.punishments||[];
    content.innerHTML=`<div class="toolbar"><button class="secondary" data-reload="punishments">↻ Refresh history</button><span class="tag">${rows.length} RECORDS</span></div><div class="table-wrap"><table><thead><tr><th>ID</th><th>Player</th><th>Type</th><th>Reason</th><th>Staff</th><th>Expires</th><th>Status</th><th></th></tr></thead><tbody>${rows.map(r=>`<tr><td>#${r.id}</td><td>${esc(r.target_name||r.target_identifier)}</td><td>${esc(r.type)}</td><td>${esc(r.reason)}</td><td>${esc(r.staff_name)}</td><td>${esc(r.expires_at||'Permanent')}</td><td><span class="tag ${Number(r.active)===1?'':'off'}">${Number(r.active)===1?'ACTIVE':'REVOKED'}</span></td><td>${Number(r.active)===1?`<button class="danger" data-revoke="${r.id}">Revoke</button>`:''}</td></tr>`).join('')}</tbody></table>${rows.length?'':`<div class="empty">${state.loading.punishments?'Loading punishment history…':'No punishment records found.'}</div>`}</div>`;
    content.querySelector('[data-reload]').onclick=()=>{state.data.punishments=null;state.loading.punishments=false;modulePage()};
    content.querySelectorAll('[data-revoke]').forEach(b=>b.onclick=()=>formModal('Revoke punishment','This restores access when revoking an active ban.',[['reason','Revocation reason','textarea']],v=>action('punishment_revoke',{id:b.dataset.revoke,...v})));
    return;
  }
  if(state.page==='audit'){
    if(!state.data.audit&&!state.loading.audit){state.loading.audit=true;action('load_audit',{})}
    const rows=state.data.audit||[];
    content.innerHTML=`<div class="toolbar"><button class="secondary" data-reload="audit">↻ Refresh audit log</button><span class="tag">${rows.length} EVENTS</span></div><div class="table-wrap"><table><thead><tr><th>ID</th><th>Timestamp</th><th>Staff</th><th>Action</th><th>Target</th><th>Reason / Detail</th><th>Coordinates</th></tr></thead><tbody>${rows.map(r=>`<tr><td>#${r.id}</td><td>${esc(r.created_at)}</td><td>${esc(r.staff_name)}</td><td><span class="tag">${esc(r.action)}</span></td><td>${esc(r.target_name||'—')}</td><td>${esc(r.reason||'—')}</td><td>${esc(r.coordinates||'—')}</td></tr>`).join('')}</tbody></table>${rows.length?'':`<div class="empty">${state.loading.audit?'Loading audit events…':'No audit events found.'}</div>`}</div>`;
    content.querySelector('[data-reload]').onclick=()=>{state.data.audit=null;state.loading.audit=false;modulePage()};
    return;
  }
  if(state.page==='server'){
    if(!state.data.resources&&!state.loading.resources){state.loading.resources=true;action('resource_list',{})}
    const rows=state.data.resources||[], d=state.data.dashboard;
    content.innerHTML=`<div class="metrics">${metric('Resources',d.resources,'Server resources')}${metric('Framework',esc(d.framework),'Active bridge')}${metric('Database',esc(d.database),'Persistence driver')}${metric('Uptime',time(d.uptime),'Current session')}</div><div class="toolbar" style="margin-top:8px"><button class="secondary" data-reload="resources">↻ Refresh resources</button><button class="primary" data-server-announce>Server announcement</button></div><div class="table-wrap"><table><thead><tr><th>Resource</th><th>State</th><th>Policy</th><th>Controls</th></tr></thead><tbody>${rows.map(r=>`<tr><td>${esc(r.name)}</td><td><span class="tag ${r.state==='started'?'':'off'}">${esc(r.state)}</span></td><td>${r.allowed?'Allowlisted':'Read only'}</td><td>${r.allowed?`<button class="secondary" data-resource="${esc(r.name)}" data-op="${r.state==='started'?'restart':'start'}">${r.state==='started'?'Restart':'Start'}</button> <button class="danger" data-resource="${esc(r.name)}" data-op="stop">Stop</button>`:'—'}</td></tr>`).join('')}</tbody></table>${rows.length?'':`<div class="empty">${state.loading.resources?'Loading server resources…':'No resources returned.'}</div>`}</div>`;
    content.querySelector('[data-reload]').onclick=()=>{state.data.resources=null;state.loading.resources=false;modulePage()};
    content.querySelector('[data-server-announce]').onclick=()=>formModal('Server announcement','Broadcast to every connected player.',[['message','Message','textarea']],v=>action('announce',v));
    content.querySelectorAll('[data-resource]').forEach(b=>b.onclick=()=>confirmModal(`${b.dataset.op} ${b.dataset.resource}?`,'Only allowlisted resources can be controlled.',()=>action('resource_control',{resource:b.dataset.resource,operation:b.dataset.op})));
    return;
  }
  if(state.page==='vehicles'){
    content.innerHTML=`<section class="card"><div class="section-title"><div><p>VEHICLE TOOLKIT</p><h2>Live vehicle controls</h2></div><span class="tag">CONNECTED</span></div><div class="quick-grid"><button class="action-button" data-tool="spawn"><b>＋</b> Spawn vehicle<span>Create a networked vehicle by model</span></button><button class="action-button" data-tool="repair"><b>⌁</b> Repair vehicle<span>Repair the current or nearest vehicle</span></button><button class="danger" data-tool="delete">Delete current / nearest vehicle</button></div></section>`;
    content.querySelector('[data-tool=spawn]').onclick=()=>formModal('Spawn vehicle','Enter a valid GTA vehicle model.',[['model','Vehicle model','text']],v=>action('vehicle_spawn',v));
    content.querySelector('[data-tool=repair]').onclick=()=>action('vehicle_repair',{});
    content.querySelector('[data-tool=delete]').onclick=()=>confirmModal('Delete vehicle?','The current or nearest vehicle will be removed.',()=>action('vehicle_delete',{}));
    return;
  }
  if(state.page==='world'){
    content.innerHTML=`<section class="card"><div class="section-title"><div><p>STAFF MOVEMENT</p><h2>World tools</h2></div><span class="tag">SECURE</span></div><div class="quick-grid"><button class="action-button" data-tool="noclip"><b>◇</b> Toggle noclip<span>W/S move · Space up · Ctrl down · Shift boost</span></button></div></section>`;
    content.querySelector('[data-tool=noclip]').onclick=()=>action('noclip',{});
    return;
  }
  if(state.page==='economy'){
    state.page='players';render();return;
  }
  content.innerHTML=`<section class="card"><div class="section-title"><div><p>INTEGRATION STATUS</p><h2>${info[1]}</h2></div><span class="tag off">Restricted</span></div><div class="empty">${esc(info[2])}</div></section>`
}
function action(name,payload){
  post('action',{action:name,payload}).then(r=>r.json()).then(r=>state.pending.set(r.requestId,name)).catch(()=>toast('NUI bridge unavailable','error'));
}
function confirmModal(heading,copy,onConfirm){modal(`<h2>${esc(heading)}</h2><p>${esc(copy)}</p><div class="modal-actions"><button class="secondary" data-cancel>Cancel</button><button class="primary" data-confirm>Confirm</button></div>`,root=>{root.querySelector('[data-cancel]').onclick=closeModal;root.querySelector('[data-confirm]').onclick=()=>{closeModal();onConfirm()}})}
function formModal(heading,copy,fields,onSubmit){
  const html=fields.map(([key,label,type,opts])=>`<label>${esc(label)}</label>${type==='textarea'?`<textarea class="input" name="${key}" required></textarea>`:type==='select'?`<select class="input" name="${key}">${opts.map(o=>{const x=Array.isArray(o)?o:[o,o];return `<option value="${x[0]}">${esc(x[1])}</option>`}).join('')}</select>`:`<input class="input" name="${key}" type="${type}" required>`}`).join('');
  modal(`<h2>${esc(heading)}</h2><p>${esc(copy)}</p><form class="form">${html}<div class="modal-actions"><button type="button" class="secondary" data-cancel>Cancel</button><button class="primary">Confirm action</button></div></form>`,root=>{root.querySelector('[data-cancel]').onclick=closeModal;root.querySelector('form').onsubmit=e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target));closeModal();onSubmit(v)}})
}
function modal(html,ready){$('#modal-root').innerHTML=`<div class="modal-backdrop"><div class="modal">${html}</div></div>`;ready($('#modal-root'))}
function closeModal(){$('#modal-root').innerHTML=''}
function commandPalette(){
  const commands=[...pages.map(p=>[p[2],()=>{state.page=p[0];render()}]),['Toggle staff duty',()=>action('duty',{})],['Refresh live data',refresh]];
  modal(`<h2>Command palette</h2><p>Jump to a page or run a common action.</p><input id="command-search" class="input" autofocus placeholder="Type a command…"><div class="command-list">${commands.map((c,i)=>`<div class="command" data-i="${i}"><span>${c[0]}</span><small>Open</small></div>`).join('')}</div>`,root=>{root.querySelectorAll('.command').forEach(e=>e.onclick=()=>{closeModal();commands[e.dataset.i][1]()})})
}
function refresh(){action('refresh',{})}
window.addEventListener('message',e=>{
  const m=e.data;
  if(m.type==='open'){state.data=m.payload;remember(m.payload.dashboard);document.documentElement.style.setProperty('--accent',m.payload.config.accent);$('#role').textContent=m.payload.role;$('#server-name').textContent=m.payload.config.serverName;setDuty(m.payload.duty);app.classList.add('visible');app.setAttribute('aria-hidden','false');render()}
  if(m.type==='close'){app.classList.remove('visible')}
  if(m.type==='toast')toast(m.message,m.kind);
  if(m.type==='announcement')showAnnouncement(m.message);
  if(m.type==='staffWarning')showStaffWarning(m.message);
  if(m.type==='dutyState')setDuty(m.active===true);
  if(m.type==='response'){if(m.ok){if(m.payload?.dashboard){state.data.dashboard=m.payload.dashboard;remember(m.payload.dashboard)}if(m.payload?.players)state.data.players=m.payload.players;if(m.payload?.reports)state.data.reports=m.payload.reports;if(m.payload?.punishments){state.data.punishments=m.payload.punishments;state.loading.punishments=false}if(m.payload?.audit){state.data.audit=m.payload.audit;state.loading.audit=false}if(m.payload?.resources){state.data.resources=m.payload.resources;state.loading.resources=false}if(m.payload?.resourceChanged){state.data.resources=null;state.loading.resources=false}if(typeof m.payload?.duty==='boolean')setDuty(m.payload.duty);toast('Action completed','success');render()}else{state.loading={};toast(m.error||'Action failed','error')}}
});
function setDuty(v){$('#duty-label').textContent=v?'On duty':'Off duty';$('.status-dot').classList.toggle('live',v)}
$('#close').onclick=()=>{post('close');app.classList.remove('visible')};$('#refresh').onclick=refresh;$('#duty').onclick=()=>action('duty',{});$('#search-button').onclick=commandPalette;
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&$('#modal-root').innerHTML)closeModal();else if(e.key==='Escape'&&app.classList.contains('visible'))$('#close').click();if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();commandPalette()}});
