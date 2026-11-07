import 'dart:convert';

/// The receiver's self-contained browser remote; no external assets, cookies,
/// tokens in URLs, HTML interpolation of user titles, or credential export.
/// [labels] words the page; they come from the app's own translations at
/// start time, so the served page carries the viewer's language.
String remoteControlHtml({Map<String, String> labels = const {}}) {
  final words = <String, String>{
    for (final key in [
      'remote_control_title',
      'remote_control_pair',
      'remote_control_code',
      'remote_control_link',
      'remote_control_send',
      'remote_control_unpair',
      'remote_control_idle',
      'remote_control_failed',
      'remote_control_paired',
      'remote_control_ok',
      'remote_control_text',
      'remote_control_text_hint',
      'play',
      'pause',
      'refresh',
      'previous',
      'next',
      'volume',
      'mute',
      'fullscreen',
      'danmaku',
      'back',
      'home',
    ])
      key: labels[key] ?? key,
  };
  final encoded = jsonEncode(words).replaceAll('<', r'\u003c');
  return '''
<!doctype html><html><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>PureLive</title>
<style>body{font:16px system-ui;background:#14161b;color:#f4f4f6;max-width:720px;margin:auto;padding:20px}input,button{font:inherit;border-radius:12px;padding:12px;border:1px solid #777;margin:4px;min-height:48px;box-sizing:border-box}input{max-width:95%}button{cursor:pointer;background:#303743;color:inherit}button:disabled{opacity:.4}#keys{display:grid;grid-template-columns:repeat(3,1fr)}#keys button{min-width:0}#state{overflow-wrap:anywhere}#status{min-height:24px}a{color:#b8d1ff;display:block;padding:10px;overflow-wrap:anywhere}</style>
<h1 id="title"></h1><div id="pair"><input id="code" inputmode="numeric" maxlength="6" autocomplete="off"><button id="connect"></button></div>
<p id="status" role="status"></p><div id="remote" hidden><p id="state"></p>
<div id="keys"></div><p><input id="link" type="text" maxlength="4096"><button id="send"></button></p>
<p><input id="text" maxlength="4096" autocomplete="off"><button id="typeText"></button></p>
<label id="volumeLabel" for="volume"></label><input id="volume" type="range" min="0" max="100" value="50">
<hr><p><button id="disconnect"></button></p></div>
<script>
const labels=$encoded;
const el=id=>document.getElementById(id);
let token=sessionStorage.getItem('purelive-remote-token')||'',target=null,inputId=null,busy=false,polling=null,commandVersion=0;
const keys=['previous','up','next','left','ok','right','play','down','pause','refresh','mute','fullscreen','danmaku','back','home'];
for(const [id,key]of Object.entries({title:'remote_control_title',connect:'remote_control_pair',send:'remote_control_send',disconnect:'remote_control_unpair',volumeLabel:'volume',typeText:'remote_control_text'}))el(id).textContent=labels[key];
el('code').placeholder=labels.remote_control_code;el('link').placeholder=labels.remote_control_link;el('text').placeholder=labels.remote_control_text_hint;
async function api(path,body){const r=await fetch('/api/'+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(token?{'Authorization':'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body),cache:'no-store',signal:AbortSignal.timeout(15000)});if(!r.ok){if(r.status===401){token='';sessionStorage.removeItem('purelive-remote-token');show();}throw Error(r.status)}return r.headers.get('content-type')?.includes('json')?await r.json():null;}
function show(){el('pair').hidden=!!token;el('remote').hidden=!token;}
async function status(force=false){if(!token)return;if(polling){if(!force)return;await polling.catch(()=>{});}const version=commandVersion;const work=(async()=>{try{const data=await api('status');if(version!==commandVersion||!token)return;target=data.targetId;const nextInput=data.state?.inputId;if(nextInput!==inputId)el('text').value='';inputId=nextInput;el('state').textContent=data.state?[data.state.nick,data.state.title].filter(Boolean).join(' · '):labels.remote_control_idle;const allowed=data.state?.commands||[];document.querySelectorAll('#keys button').forEach(b=>b.disabled=!target||!allowed.includes(b.dataset.command));el('typeText').disabled=!target||!Number.isInteger(inputId);el('text').disabled=!Number.isInteger(inputId);if(typeof data.state?.volume==='number'&&document.activeElement!==el('volume'))el('volume').value=Math.round(data.state.volume*100);}catch(e){el('status').textContent=labels.remote_control_failed;}})();polling=work;await work;if(polling===work)polling=null;}
async function command(name,value){if(busy||!target)return;busy=true;commandVersion++;const selected=target;try{await api('command',{targetId:selected,command:name,value});el('status').textContent=labels.remote_control_ok;}catch(e){el('status').textContent=labels.remote_control_failed;}finally{busy=false;await status(true);}}
for(const name of keys){const button=document.createElement('button');button.dataset.command=name;button.textContent=({up:'↑',down:'↓',left:'←',right:'→',ok:'OK'})[name]||labels[name]||name;button.onclick=()=>command(name);el('keys').append(button);}
el('connect').onclick=async()=>{try{const data=await api('pair',{code:el('code').value.trim()});token=data.token;sessionStorage.setItem('purelive-remote-token',token);el('code').value='';el('status').textContent=labels.remote_control_paired;show();await status(true);}catch(e){el('status').textContent=labels.remote_control_failed;}};
el('send').onclick=async()=>{if(busy)return;busy=true;commandVersion++;try{await api('link',{text:el('link').value.trim()});el('status').textContent=labels.remote_control_ok;el('link').value='';}catch(e){el('status').textContent=labels.remote_control_failed;}finally{busy=false;await status(true);}};
el('typeText').onclick=async()=>{if(busy||!target||!Number.isInteger(inputId))return;busy=true;commandVersion++;try{await api('text',{targetId:target,inputId,text:el('text').value});el('text').value='';el('status').textContent=labels.remote_control_ok;}catch(e){el('status').textContent=labels.remote_control_failed;}finally{busy=false;await status(true);}};
el('volume').onchange=()=>command('volume',Number(el('volume').value)/100);
el('disconnect').onclick=async()=>{try{await api('unpair',{});}finally{token='';target=null;inputId=null;sessionStorage.removeItem('purelive-remote-token');show();}};
show();status();setInterval(()=>status(),2000);
</script></html>''';
}
