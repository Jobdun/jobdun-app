// JobDun — Post a Job (theme + platform aware)
const { useState: useStatePJ } = React;

function PostJobScreen({theme, platform, onBack, onPosted}) {
  const [trade, setTrade] = useStatePJ('Electrician');
  const [title, setTitle] = useStatePJ('');
  const [desc, setDesc] = useStatePJ('');
  const [rate, setRate] = useStatePJ('');
  const [rateType, setRateType] = useStatePJ('Hourly');
  const [urgent, setUrgent] = useStatePJ(false);

  const inputStyle = {
    height:48, padding:'0 14px', width:'100%', boxSizing:'border-box',
    background:theme.surfaceVariant, border:`1px solid ${theme.outline}`, borderRadius:10,
    fontFamily:FF.body, fontSize:15, color:theme.onSurface, outline:'none',
  };
  const labelStyle = {fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:8};
  const arrowStroke = theme.onSurfaceVariant.replace('#','%23');

  return <div style={{background:theme.background,minHeight:'100%',position:'relative',paddingBottom:120}}>
    <div style={{padding:`${platform==='android'?40:56}px 20px 0`, display:'flex',alignItems:'center',gap:14}}>
      <IconBtn theme={theme} platform={platform} onClick={onBack}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </IconBtn>
    </div>

    <div style={{padding:'20px 20px 0'}}><H1 theme={theme}>POST A JOB</H1></div>

    <div style={{padding:'24px 20px 0',display:'flex',flexDirection:'column',gap:16}}>
      <div>
        <div style={labelStyle}>Trade</div>
        <select value={trade} onChange={e=>setTrade(e.target.value)} style={{...inputStyle, appearance:'none', backgroundImage:`url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'><path d='M1 1l5 5 5-5' stroke='${arrowStroke}' stroke-width='1.6' fill='none' stroke-linecap='round' stroke-linejoin='round'/></svg>")`,backgroundRepeat:'no-repeat',backgroundPosition:'right 14px center'}}>
          {['Electrician','Plumber','Carpenter','Tiler','Painter','Roofer'].map(o=> <option key={o}>{o}</option>)}
        </select>
      </div>

      <div>
        <div style={labelStyle}>Job title</div>
        <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="e.g. Replace 6 downlights" style={inputStyle}/>
      </div>

      <div>
        <div style={labelStyle}>Description</div>
        <textarea value={desc} onChange={e=>setDesc(e.target.value)} placeholder="What needs doing, access, supplied materials…" style={{...inputStyle,height:96,padding:'12px 14px',resize:'none',lineHeight:1.5}}/>
      </div>

      <div>
        <div style={labelStyle}>Site location</div>
        <div style={{...inputStyle,display:'flex',alignItems:'center',gap:8}}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={theme.secondary} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>
          <span style={{flex:1,color:theme.onSurface}}>42 High St, Thornbury VIC</span>
          <span style={{fontFamily:FF.body,fontSize:11,fontWeight:600,color:theme.secondary}}>Change</span>
        </div>
      </div>

      <div style={{display:'flex',gap:10}}>
        <div style={{flex:1}}>
          <div style={labelStyle}>Rate type</div>
          <div style={{display:'flex',background:theme.surfaceVariant,border:`1px solid ${theme.outline}`,borderRadius:10,padding:3,height:48}}>
            {['Hourly','Fixed'].map(rt=>(
              <button key={rt} onClick={()=>setRateType(rt)} style={{
                flex:1, border:'none', background: rateType===rt?theme.surface:'transparent',
                borderRadius:8, fontFamily:FF.body, fontSize:13, fontWeight:600,
                color: rateType===rt?theme.onSurface:theme.onSurfaceVariant, cursor:'pointer',
              }}>{rt}</button>
            ))}
          </div>
        </div>
        <div style={{flex:1}}>
          <div style={labelStyle}>{rateType==='Hourly'?'$ / hr':'Fixed $'}</div>
          <input value={rate} onChange={e=>setRate(e.target.value)} placeholder={rateType==='Hourly'?'95':'1800'} style={inputStyle}/>
        </div>
      </div>

      <div style={{
        padding:14, borderRadius:14, background: urgent?theme.errorContainer:theme.surface,
        border:`1px solid ${urgent?theme.error:theme.outline}`,
        display:'flex',alignItems:'center',gap:12,
      }}>
        <div style={{flex:1}}>
          <div style={{fontFamily:FF.body,fontWeight:600,fontSize:14,color:urgent?theme.onErrorContainer:theme.onSurface}}>Mark urgent</div>
          <div style={{fontFamily:FF.body,fontSize:12,color:urgent?theme.onErrorContainer:theme.onSurfaceVariant,marginTop:2,lineHeight:1.4}}>
            {urgent ? 'Tradies will be alerted immediately.' : 'Pinned to top of feeds. Use for site stoppages only.'}
          </div>
        </div>
        <button onClick={()=>setUrgent(!urgent)} aria-label="Toggle urgent" style={{
          width:46,height:26,borderRadius:13,border:'none',cursor:'pointer',padding:2,
          background: urgent?theme.error:theme.outline, transition:'background 150ms ease',
        }}>
          <div style={{
            width:22,height:22,borderRadius:'50%',background:'#fff',
            transform:urgent?'translateX(20px)':'translateX(0)',transition:'transform 150ms ease',
            boxShadow:'0 1px 2px rgba(0,0,0,0.2)',
          }}/>
        </button>
      </div>
    </div>

    <div style={{
      position:'absolute',bottom:0,left:0,right:0, padding:'16px 20px 20px',
      background:theme.background, borderTop:`1px solid ${theme.outline}`,
    }}>
      <Btn theme={theme} variant="primary" full onClick={onPosted} style={{borderRadius: platform==='android'?100:9}}>Post Job</Btn>
    </div>
  </div>;
}

window.PostJobScreen = PostJobScreen;
