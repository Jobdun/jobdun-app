// JobDun — Chat (theme + platform aware)
const { useState: useStateCH } = React;

function ChatScreen({theme, platform, tradie, onBack}) {
  const [msg, setMsg] = useStateCH('');
  const [messages, setMessages] = useStateCH([
    {from:'them', text:'Got your invite for the downlights job. Can do tomorrow 8am.', time:'14:02'},
    {from:'me', text:'Top. Side gate code is 4172. Owner will be on site.', time:'14:04'},
    {from:'them', text:'Sweet. Ill bring the IC-rated GU10s — confirm 4000K?', time:'14:05'},
  ]);

  const send = () => {
    if (!msg.trim()) return;
    setMessages([...messages, {from:'me', text:msg.trim(), time:'14:12'}]);
    setMsg('');
  };

  return <div style={{background:theme.background,minHeight:'100%',display:'flex',flexDirection:'column'}}>
    <div style={{padding:`${platform==='android'?40:56}px 20px 16px`, display:'flex',alignItems:'center',gap:12, borderBottom:`1px solid ${theme.outline}`,background:theme.surface}}>
      <IconBtn theme={theme} platform={platform} onClick={onBack}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </IconBtn>
      <Avatar theme={theme} initials={tradie.initials} bg={tradie.avatarBg} size={36} radius={9}/>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontFamily:FF.body,fontWeight:600,fontSize:15,color:theme.onSurface}}>{tradie.name}</div>
        <div style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceVariant}}>{tradie.trade} · Available now</div>
      </div>
      <button aria-label="Call" style={{
        width:34,height:34,borderRadius: platform==='android'?17:9, background:theme.secondaryContainer,border:'none',
        display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',
      }}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={theme.secondary} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
      </button>
    </div>

    <div style={{flex:1,overflowY:'auto',padding:'16px 20px',display:'flex',flexDirection:'column',gap:8}}>
      <div style={{textAlign:'center',fontFamily:FF.body,fontSize:11,fontWeight:500,color:theme.onSurfaceMuted,margin:'4px 0 12px'}}>Today</div>
      {messages.map((m,i)=>(
        <div key={i} style={{alignSelf: m.from==='me'?'flex-end':'flex-start', maxWidth:'78%'}}>
          <div style={{
            padding:'10px 14px', borderRadius:14,
            background: m.from==='me' ? theme.primary : theme.surfaceVariant,
            color: m.from==='me' ? theme.onPrimary : theme.onSurface,
            fontFamily:FF.body, fontSize:14, lineHeight:1.4,
            borderTopRightRadius: m.from==='me'?4:14,
            borderTopLeftRadius: m.from==='me'?14:4,
          }}>{m.text}</div>
          <div style={{fontFamily:FF.body,fontSize:10,fontWeight:500,color:theme.onSurfaceMuted,
            textAlign: m.from==='me'?'right':'left', marginTop:3, padding:'0 6px'}}>{m.time}</div>
        </div>
      ))}
    </div>

    <div style={{padding:'10px 20px 20px', borderTop:`1px solid ${theme.outline}`, background:theme.surface,
      display:'flex',gap:8,alignItems:'center'}}>
      <button aria-label="Attach" style={{
        width:40,height:40,borderRadius: platform==='android'?20:10, background:theme.surfaceVariant,border:'none',cursor:'pointer',
        display:'flex',alignItems:'center',justifyContent:'center',
      }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={theme.onSurfaceVariant} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>
      </button>
      <input value={msg} onChange={e=>setMsg(e.target.value)} onKeyDown={e=>e.key==='Enter'&&send()} placeholder="Message…" style={{
        flex:1, height:40, padding:'0 14px', borderRadius: platform==='android'?20:10,
        background:theme.surfaceVariant, border:`1px solid ${theme.outline}`,
        fontFamily:FF.body, fontSize:14, color:theme.onSurface, outline:'none',
      }}/>
      <button onClick={send} aria-label="Send" style={{
        width:40,height:40,borderRadius: platform==='android'?20:10, background:theme.secondary,border:'none',cursor:'pointer',
        display:'flex',alignItems:'center',justifyContent:'center',
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSecondary} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>
      </button>
    </div>
  </div>;
}

window.ChatScreen = ChatScreen;
