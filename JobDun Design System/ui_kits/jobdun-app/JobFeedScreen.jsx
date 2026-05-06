// JobDun — Tradie Job Feed (theme + platform aware)
const { useState: useStateJF } = React;

function JobFeedScreen({theme, platform, onOpenJob}) {
  const [activeChip, setActiveChip] = useStateJF('All');
  const chips = ['All','Urgent','Today','This week'];

  const filtered = window.JOBS.filter(j=>{
    if (activeChip==='Urgent' && !j.urgent) return false;
    if (activeChip==='Today' && j.start!=='Today') return false;
    return true;
  }).sort((a,b)=> (b.urgent?1:0)-(a.urgent?1:0));

  return <div style={{padding:'0 20px',background:theme.background,minHeight:'100%',paddingBottom:32}}>
    <div style={{paddingTop:platform==='android'?44:60, display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:20}}>
      <div>
        <Eyebrow theme={theme}>Tradie · Marcus Kowalski</Eyebrow>
        <Display theme={theme} style={{marginTop:6}}>JOBS NEARBY</Display>
        <div style={{display:'flex',alignItems:'center',gap:4,marginTop:8,fontFamily:FF.body,fontSize:11,fontWeight:600,color:theme.secondary}}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={theme.secondary} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>
          FITZROY, VIC · 10 KM
        </div>
      </div>
      <IconBtn theme={theme} platform={platform}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="4" y1="6" x2="20" y2="6"/><line x1="7" y1="12" x2="17" y2="12"/><line x1="10" y1="18" x2="14" y2="18"/></svg>
      </IconBtn>
    </div>

    <div style={{display:'flex',gap:8,overflowX:'auto',marginBottom:20,paddingBottom:2}}>
      {chips.map(c=> <Chip theme={theme} key={c} label={c} active={activeChip===c} onClick={()=>setActiveChip(c)}/>)}
    </div>

    <SectionRow theme={theme} title={`${filtered.length} jobs match`} meta={filtered.filter(j=>j.urgent).length>0?`${filtered.filter(j=>j.urgent).length} urgent`:null}/>
    {filtered.map(j=> <JobCard theme={theme} key={j.id} job={j} onClick={()=>onOpenJob(j)}/>)}
  </div>;
}

window.JobFeedScreen = JobFeedScreen;
