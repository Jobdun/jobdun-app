// JobDun Galvanised — components, theme-aware
// All colors come from `theme` (a Flutter ColorScheme-aligned object).

const { useState } = React;

function Eyebrow({theme, children, color}) {
  return <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color: color||theme.onSurfaceMuted}}>{children}</div>;
}
function Display({theme, children, style={}}) {
  return <h1 style={{fontFamily:FF.display,fontSize:40,fontWeight:700,lineHeight:1,letterSpacing:'0.02em',color:theme.onSurface,margin:0,...style}}>{children}</h1>;
}
function H1({theme, children, style={}}) {
  return <h2 style={{fontFamily:FF.display,fontSize:28,fontWeight:700,lineHeight:1,letterSpacing:'0.02em',color:theme.onSurface,margin:0,...style}}>{children}</h2>;
}

function Btn({theme, children, variant='primary', onClick, style={}, full=false}) {
  const v = {
    primary:{bg:theme.primary, c:theme.onPrimary, b:'transparent'},
    action: {bg:theme.secondary, c:theme.onSecondary, b:'transparent'},
    ghost:  {bg:theme.surface, c:theme.onSurfaceVariant, b:theme.outline, bw:1},
  }[variant];
  return <button onClick={onClick} style={{
    height:48, padding:'0 22px', borderRadius:9,
    background:v.bg, color:v.c, border:`${v.bw||0}px solid ${v.b}`,
    fontFamily:FF.body, fontSize:13, fontWeight:600, letterSpacing:'0.01em',
    cursor:'pointer', width: full?'100%':undefined,
    display:'inline-flex',alignItems:'center',justifyContent:'center',gap:8,
    ...style,
  }}>{children}</button>;
}

function Badge({theme, variant, children}) {
  const m = {
    verified:{bg:theme.successContainer, c:theme.onSuccessContainer, dot:theme.success, label:'Verified'},
    available:{bg:theme.infoContainer, c:theme.onInfoContainer, dot:theme.info, label:'Available Now'},
    urgent:{bg:theme.errorContainer, c:theme.onErrorContainer, dot:theme.error, label:'Urgent'},
    pending:{bg:theme.secondaryContainer, c:theme.onSecondaryContainer, dot:theme.secondary, label:'Booked'},
  }[variant];
  return <span style={{
    display:'inline-flex',alignItems:'center',gap:5,
    height:28, padding:'0 11px', borderRadius:5, background:m.bg, color:m.c,
    fontFamily:FF.body, fontSize:11, fontWeight:600, letterSpacing:'0.02em',
  }}>
    {m.dot && <span style={{width:6,height:6,borderRadius:'50%',background:m.dot}}/>}
    {children || m.label}
  </span>;
}

function Avatar({initials, bg, size=44, radius=10, theme}) {
  const fs = size>=64 ? 22 : size>=50 ? 16 : 14;
  return <div style={{
    width:size,height:size,borderRadius:radius,background: bg || theme.primary, color: theme.onPrimary,
    display:'flex',alignItems:'center',justifyContent:'center',
    fontFamily:FF.display,fontWeight:700,fontSize:fs,letterSpacing:'0.04em',flexShrink:0,
  }}>{initials}</div>;
}

function Chip({theme, label, active, onClick}) {
  return <button onClick={onClick} style={{
    height:30, padding:'0 14px', borderRadius:8,
    background: active?theme.primary:theme.surfaceVariant,
    color: active?theme.onPrimary:theme.onSurfaceVariant,
    border: active?'none':`1px solid ${theme.outline}`,
    fontFamily:FF.body, fontSize:11, fontWeight:600, whiteSpace:'nowrap', cursor:'pointer',
  }}>{label}</button>;
}

function Search({theme, placeholder='Search trades or skills…', value='', onChange}) {
  return <div style={{
    background:theme.surfaceVariant, border:`1px solid ${theme.outline}`, borderRadius:10,
    height:40, display:'flex',alignItems:'center', padding:'0 14px', gap:8,
  }}>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurfaceMuted} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
    <input value={value} onChange={e=>onChange&&onChange(e.target.value)} placeholder={placeholder} style={{
      border:'none',outline:'none',background:'transparent',flex:1,
      fontFamily:FF.body,fontSize:13,color:theme.onSurface,
    }}/>
  </div>;
}

function Card({theme, children, style={}, onClick, dim=false}) {
  return <div onClick={onClick} style={{
    background:theme.surface, border:`1px solid ${theme.outline}`, borderRadius:14, padding:16,
    opacity:dim?0.45:1, cursor:onClick?'pointer':'default', ...style,
  }}>{children}</div>;
}

// ──── Bottom nav ────
// On Android (Material 3 NavigationBar) the active "pill" wraps the icon.
// On iOS we use the same shape but without the pill — the icon recolors only.
function BottomNav({theme, platform='ios', active='home', onChange}) {
  const tabs = [
    {id:'home', label:'Home', icon:(c)=> <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>},
    {id:'jobs', label:'Jobs', icon:(c)=> <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>},
    {id:'chat', label:'Chat', icon:(c)=> <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>},
    {id:'profile', label:'Profile', icon:(c)=> <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>},
  ];
  return <div style={{
    background: theme.surface, borderTop:`1px solid ${theme.outline}`,
    height: platform==='android'?72:62,
    display:'flex', padding: platform==='android'?'8px 8px 12px':'0 8px 10px', alignItems:'center',
  }}>
    {tabs.map(tab=>{
      const on = tab.id===active;
      return <div key={tab.id} onClick={()=>onChange&&onChange(tab.id)} style={{
        flex:1, display:'flex',flexDirection:'column',alignItems:'center',gap:platform==='android'?2:4, padding:'6px 0',cursor:'pointer',
      }}>
        <div style={{
          background: on ? (platform==='android' ? theme.secondaryContainer : 'transparent') : 'transparent',
          borderRadius: platform==='android' ? 16 : 8,
          padding: platform==='android' ? '4px 18px' : '4px 10px',
        }}>
          {tab.icon(on ? (platform==='android' ? theme.onSecondaryContainer : theme.secondary) : theme.onSurfaceMuted)}
        </div>
        <div style={{fontFamily:FF.body,fontSize:10,fontWeight:600,color: on?theme.secondary:theme.onSurfaceMuted}}>{tab.label}</div>
      </div>;
    })}
  </div>;
}

// ──── Tradie card ────
function TradieCard({theme, tradie, onClick}) {
  const offline = !tradie.available;
  return <Card theme={theme} dim={offline} onClick={onClick} style={{marginBottom:9}}>
    <div style={{display:'flex',gap:12,alignItems:'flex-start'}}>
      <Avatar theme={theme} initials={tradie.initials} bg={tradie.avatarBg}/>
      <div style={{flex:1,minWidth:0}}>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:2}}>
          <div style={{fontFamily:FF.body,fontWeight:600,fontSize:16,color:theme.onSurface}}>{tradie.name}</div>
          <div style={{display:'flex',alignItems:'baseline',gap:2}}>
            <span style={{fontFamily:FF.display,fontWeight:700,fontSize:18,color:theme.onSurface,lineHeight:1}}>{tradie.rating.toFixed(1)}</span>
            <span style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted}}>/5</span>
          </div>
        </div>
        <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant}}>{tradie.trade} · {tradie.suburb}</div>
        <div style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted,marginTop:2}}>{tradie.jobs} jobs completed</div>
      </div>
    </div>
    <div style={{height:1,background:theme.outline,margin:'12px 0'}}/>
    <div style={{display:'flex',alignItems:'center',gap:8,fontFamily:FF.body,fontSize:11,fontWeight:600}}>
      <span style={{display:'inline-block',width:6,height:6,borderRadius:'50%',background: offline?theme.onSurfaceMuted:theme.success}}/>
      <span style={{color: offline?theme.onSurfaceMuted:theme.onSuccessContainer}}>{offline?'Offline':'Available'}</span>
      {!offline && tradie.verified && <>
        <span style={{color:theme.outline}}>·</span>
        <span style={{color:theme.onSuccessContainer}}>✓ Verified</span>
      </>}
      {!offline && <span style={{marginLeft:'auto',color:theme.secondary}}>{tradie.distance.toFixed(1)} km</span>}
    </div>
  </Card>;
}

// ──── Job card ────
function JobCard({theme, job, onClick}) {
  return <Card theme={theme} onClick={onClick} style={{marginBottom:9, padding:0, overflow:'hidden'}}>
    {job.urgent && <div style={{height:3,background:theme.error}}/>}
    <div style={{padding:16}}>
      {job.urgent && <div style={{marginBottom:8}}><Badge theme={theme} variant="urgent">Urgent</Badge></div>}
      <div style={{fontFamily:FF.display,fontWeight:700,fontSize:20,lineHeight:1.1,letterSpacing:'0.02em',color:theme.onSurface,marginBottom:4}}>{job.title}</div>
      <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant,lineHeight:1.5,
        display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden'}}>{job.desc}</div>
      <div style={{display:'flex',gap:16,paddingTop:12,marginTop:12,borderTop:`1px solid ${theme.outline}`}}>
        <div><div style={{fontFamily:FF.body,fontSize:10,fontWeight:500,color:theme.onSurfaceMuted,marginBottom:2}}>Rate</div><div style={{fontFamily:FF.display,fontWeight:700,fontSize:15,color:theme.onSurface}}>{job.rate}</div></div>
        <div><div style={{fontFamily:FF.body,fontSize:10,fontWeight:500,color:theme.onSurfaceMuted,marginBottom:2}}>Start</div><div style={{fontFamily:FF.display,fontWeight:700,fontSize:15,color:theme.onSurface}}>{job.start}</div></div>
        <div style={{marginLeft:'auto',textAlign:'right'}}><div style={{fontFamily:FF.body,fontSize:10,fontWeight:500,color:theme.onSurfaceMuted,marginBottom:2}}>Distance</div><div style={{fontFamily:FF.display,fontWeight:700,fontSize:15,color:theme.secondary}}>{job.distance.toFixed(1)} km</div></div>
      </div>
    </div>
  </Card>;
}

function SectionRow({theme, title, meta}) {
  return <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
    <div style={{fontFamily:FF.body,fontSize:16,fontWeight:600,color:theme.onSurface}}>{title}</div>
    {meta && <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,color:theme.success}}>{meta}</div>}
  </div>;
}

// Round icon button used in headers — platform-aware shape
function IconBtn({theme, platform='ios', children, onClick, badge=false}) {
  const isAndroid = platform==='android';
  return <button onClick={onClick} style={{
    width:isAndroid?40:34, height:isAndroid?40:34,
    borderRadius: isAndroid?20:9,
    background: isAndroid?'transparent':theme.surface,
    border: isAndroid?'none':`1px solid ${theme.outline}`,
    display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',position:'relative',
  }}>
    {children}
    {badge && <span style={{position:'absolute',top:isAndroid?9:6,right:isAndroid?9:6,width:7,height:7,borderRadius:'50%',background:theme.error,border:`1.5px solid ${isAndroid?theme.background:theme.surface}`}}/>}
  </button>;
}

Object.assign(window, {
  Eyebrow, Display, H1,
  Btn, Badge, Avatar, Chip, Search, Card,
  BottomNav, TradieCard, JobCard, SectionRow, IconBtn,
});
