// JobDun — Job Detail (theme + platform aware)

function JobDetailScreen({theme, platform, job, onBack, onAccept, onDecline}) {
  return <div style={{background:theme.background,minHeight:'100%',position:'relative',paddingBottom:120}}>
    {job.urgent && <div style={{height:3,background:theme.error}}/>}
    <div style={{padding:`${platform==='android'?40:56}px 20px 0`, display:'flex',alignItems:'center'}}>
      <IconBtn theme={theme} platform={platform} onClick={onBack}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </IconBtn>
    </div>

    <div style={{padding:'20px 20px 0'}}>
      {job.urgent && <div style={{marginBottom:10}}><Badge theme={theme} variant="urgent"/></div>}
      <H1 theme={theme}>{job.title}</H1>
      <div style={{display:'flex',alignItems:'center',gap:10,marginTop:14}}>
        <Avatar theme={theme} initials={job.builder.initials} size={32} radius={8}/>
        <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant}}>Posted by <span style={{color:theme.onSurface,fontWeight:600}}>{job.builder.name}</span></div>
      </div>
    </div>

    <div style={{margin:'20px 20px 0',padding:16,background:theme.surface,border:`1px solid ${theme.outline}`,borderRadius:14,
      display:'grid',gridTemplateColumns:'1fr 1fr',rowGap:14}}>
      {[
        {l:'Rate',v:job.rate,c:theme.onSurface},
        {l:'Start',v:job.start,c:theme.onSurface},
        {l:'Duration',v:job.duration,c:theme.onSurface},
        {l:'Distance',v:`${job.distance.toFixed(1)} km`,c:theme.secondary},
      ].map(m=> (
        <div key={m.l}>
          <div style={{fontFamily:FF.body,fontSize:10,fontWeight:600,letterSpacing:'0.08em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:2}}>{m.l}</div>
          <div style={{fontFamily:FF.display,fontWeight:700,fontSize:18,color:m.c,letterSpacing:'0.02em'}}>{m.v}</div>
        </div>
      ))}
    </div>

    <div style={{margin:'24px 20px 0'}}>
      <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:8}}>Description</div>
      <div style={{fontFamily:FF.body,fontSize:15,color:theme.onSurface,lineHeight:1.5}}>{job.desc}</div>
    </div>

    <div style={{margin:'24px 20px 0'}}>
      <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:8}}>Location</div>
      <div style={{height:120,borderRadius:10,background: theme.mode==='dark'?'linear-gradient(135deg,#1F262C 0%,#2A333B 100%)':'linear-gradient(135deg,#EAEEF2 0%,#D4D9DF 100%)',border:`1px solid ${theme.outline}`,position:'relative',overflow:'hidden'}}>
        <svg style={{position:'absolute',inset:0,width:'100%',height:'100%'}} viewBox="0 0 320 120" preserveAspectRatio="none">
          <path d="M0 70 L80 60 L160 80 L240 50 L320 70" stroke={theme.onSurfaceMuted} strokeWidth="1" fill="none" strokeDasharray="3 4"/>
          <path d="M0 90 L320 90" stroke={theme.onSurfaceMuted} strokeWidth="1" fill="none" strokeDasharray="3 4"/>
          <circle cx="160" cy="60" r="8" fill={theme.secondary}/>
          <circle cx="160" cy="60" r="14" fill={theme.secondary} opacity="0.18"/>
        </svg>
      </div>
      <div style={{fontFamily:FF.body,fontSize:13,color:theme.onSurfaceVariant,marginTop:8}}>{job.address}</div>
    </div>

    <div style={{margin:'24px 20px 0'}}>
      <div style={{fontFamily:FF.body,fontSize:11,fontWeight:600,letterSpacing:'0.12em',textTransform:'uppercase',color:theme.onSurfaceMuted,marginBottom:8}}>Builder</div>
      <Card theme={theme}>
        <div style={{display:'flex',alignItems:'center',gap:12}}>
          <Avatar theme={theme} initials={job.builder.initials}/>
          <div style={{flex:1}}>
            <div style={{fontFamily:FF.body,fontWeight:600,fontSize:15,color:theme.onSurface}}>{job.builder.name}</div>
            <div style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted,marginTop:2}}>{job.builder.jobs} jobs posted</div>
          </div>
          <div><span style={{fontFamily:FF.display,fontWeight:700,fontSize:18,color:theme.onSurface}}>{job.builder.rating.toFixed(1)}</span><span style={{fontFamily:FF.body,fontSize:11,color:theme.onSurfaceMuted}}>/5</span></div>
        </div>
      </Card>
    </div>

    <div style={{
      position:'absolute',bottom:0,left:0,right:0, padding:'16px 20px 20px',
      background:theme.background, borderTop:`1px solid ${theme.outline}`,
      display:'flex',gap:10,
    }}>
      <Btn theme={theme} variant="ghost" onClick={onDecline} style={{flex:1, borderRadius: platform==='android'?100:9}}>Decline</Btn>
      <Btn theme={theme} variant="action" onClick={onAccept} style={{flex:2, borderRadius: platform==='android'?100:9}}>Accept Job</Btn>
    </div>
  </div>;
}

window.JobDetailScreen = JobDetailScreen;
