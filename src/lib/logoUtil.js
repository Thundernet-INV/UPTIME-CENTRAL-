export function hostFromUrl(u){try{return new URL(u).hostname.replace(/^www\./,'')}catch{return''}}
export function norm(s=''){return s.toLowerCase().replace(/\s+/g,'').trim()}
const MAP={whatsapp:'/logos/whatsapp.svg',facebook:'/logos/facebook.svg',instagram:'/logos/instagram.svg',youtube:'/logos/youtube.svg',tiktok:'/logos/tiktok.svg',google:'/logos/google.svg',microsoft:'/logos/microsoft.svg',netflix:'/logos/netflix.svg',telegram:'/logos/telegram.svg',apple:'/logos/apple.svg',iptv:'/logos/iptv.svg'};
function matchBrand(n,h){const N=norm(n),H=norm(h);for(const k of Object.keys(MAP)){if(N.includes(k)||H.includes(k))return k}return null}
export function getLogoCandidates(m){const h=hostFromUrl(m?.info?.monitor_url||'');const b=matchBrand(m?.info?.monitor_name||'',h);const a=[];if(b)a.push(MAP[b]);if(h)a.push(`https://logo.clearbit.com/${h}`);if(h)a.push(`https://www.google.com/s2/favicons?domain=${h}&sz=64`);return a.filter((v,i,A)=>v&&A.indexOf(v)===i)}
export function initialsFor(m){const n=(m?.info?.monitor_name||'').trim();if(!n)return'?';const p=n.split(/\s+/);const i=(p[0][0]||'').toUpperCase()+(p[1]?.[0]||'').toUpperCase();return i||n[0].toUpperCase()}
