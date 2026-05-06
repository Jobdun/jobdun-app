// JobDun — Tradie Profile (theme + platform aware)

function TradieProfileScreen({theme, platform, tradie, onBack, onInvite}) {
  return <div style={{background:theme.background,minHeight:'100%',position:'relative',paddingBottom:120}}>
    <div style={{padding:`${platform==='android'?44:60}px 20px 0`, display:'flex',justifyContent:'space-between',alignItems:'center'}}>
      <IconBtn theme={theme} platform={platform} onClick={onBack}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </IconBtn>
      <IconBtn theme={theme} platform={platform}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg>
      </IconBtn>
    </div>

    <div style={{padding:'20px 20px 0',display:'flex',alignItems:'center',gap:16}}>
      <Avatar theme={theme} initials={tradie.initials} bg={tradie.avatarBg} size={72} radius={12}/>
      <div style={{flex:1}}>
        <div style={{fontFamily:FF.display,fontWeight:700,fontSize:24,letterSpacing:'0.02em',color:theme.onSurface,lineHeight:1.05}}>{tradie.name}</div>
        <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant,marginTop:4}}>{tradie.trade} · {tradie.suburb}</div>
        <div style={{display:'flex',alignItems:'baseline',gap:8,marginTop:6}}>
          <span style={{fontFamily:FF.display,fontWeight:700,fontSize:24,color:theme.onSurface,lineHeight:1}}>{tradie.rating.toFixed(1)}</span>
          <span style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted}}>/5 · {tradie.jobs} jobs</span>
        </div>
      </div>
    </div>

    <div style={{margin:'20px 20px 0',display:'flex',gap:8}}>
      {[{l:'Licence'},{l:'Insurance'},{l:'ID'}].map(item=>(
        <div key={item.l} style={{
          flex:1, padding:'10px 8px', borderRadius:10,
          background: theme.successContainer,
          border:`1px solid ${theme.success}`,
          textAlign:'center',
        }}>
          <div style={{fontFamily:FF.body,fontSize:10,fontWeight:600,letterSpacing:'0.08em',textTransform:'uppercase',color:theme.onSuccessContainer}}>{item.l}</div>
          <div style={{fontFamily:FF.body,fontSize:13,fontWeight:600,color:theme.onSuccessContainer,marginTop:2}}>✓ Verified</div>
        </div>
      ))}
    </div>

    <div style={{margin:'14px 20px 0',display:'flex',gap:8,alignItems:'center'}}>
      <Badge theme={theme} variant={tradie.available?'available':'pending'}>{tradie.available?'Available Now':'Booked'}</Badge>
      <span style={{fontFamily:FF.body,fontSize:11,fontWeight:600,color:theme.secondary,marginLeft:'auto'}}>{tradie.distance.toFixed(1)} km away</span>
    </div>

    <div style={{margin:'24px 20px 0'}}>
      <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:8}}>About</div>
      <div style={{fontFamily:FF.body,fontSize:15,color:theme.onSurface,lineHeight:1.5}}>{tradie.bio}</div>
      <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant,marginTop:10}}>Standard rate · <span style={{color:theme.onSurface,fontWeight:600,fontFamily:FF.display}}>{tradie.rate}</span></div>
    </div>

    <div style={{margin:'24px 20px 0'}}>
      <SectionRow theme={theme} title="Reviews" meta="See all →"/>
      {[
        {who:'Hayes Renovations',rating:5,date:'2 weeks ago',body:'Showed on time, clean work, fair quote. Will rebook.'},
        {who:'Northside Property',rating:5,date:'1 month ago',body:'Sorted a switchboard fault same-day. Saved a tenant.'},
      ].map((r,i)=>(
        <Card theme={theme} key={i} style={{marginBottom:9}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}>
            <div style={{fontFamily:FF.body,fontWeight:600,fontSize:14,color:theme.onSurface}}>{r.who}</div>
            <div><span style={{fontFamily:FF.display,fontWeight:700,fontSize:15,color:theme.onSurface}}>{r.rating}.0</span><span style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted}}>/5</span></div>
          </div>
          <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant,marginTop:4}}>{r.body}</div>
          <div style={{fontFamily:FF.body,fontSize:11,fontWeight:500,color:theme.onSurfaceMuted,marginTop:6}}>{r.date}</div>
        </Card>
      ))}
    </div>

    <div style={{
      position:'absolute',bottom:0,left:0,right:0, padding:'16px 20px 20px',
      background:theme.background, borderTop:`1px solid ${theme.outline}`,
    }}>
      {/* Android-style FAB-shaped CTA via radius bump */}
      <Btn theme={theme} variant="primary" full onClick={onInvite} style={{borderRadius: platform==='android'?100:9}}>Invite to Job</Btn>
    </div>
  </div>;
}

window.TradieProfileScreen = TradieProfileScreen;
