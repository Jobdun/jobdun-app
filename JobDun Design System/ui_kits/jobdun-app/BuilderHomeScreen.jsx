// JobDun — Builder Home (theme + platform aware)
const { useState: useStateBH } = React;

function BuilderHomeScreen({ theme, platform, onOpenTradie, onPostJob }) {
  const [activeChip, setActiveChip] = useStateBH('All');
  const [query, setQuery] = useStateBH('');
  const chips = ['All','Electrician','Plumber','Carpenter','Tiler'];

  const filtered = window.TRADIES.filter(t=>{
    if (activeChip !== 'All' && t.trade !== activeChip) return false;
    if (query && !t.name.toLowerCase().includes(query.toLowerCase()) && !t.trade.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });
  const available = filtered.filter(t=>t.available);
  const offline = filtered.filter(t=>!t.available);

  return <div style={{padding:'0 20px',background:theme.background,minHeight:'100%',paddingBottom:32}}>
    <div style={{paddingTop:platform==='android'?44:60, display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:20}}>
      <div>
        <Eyebrow theme={theme}>Builder · Hayes Renovations</Eyebrow>
        <Display theme={theme} style={{marginTop:6}}>FIND A TRADIE</Display>
        <div style={{display:'flex',alignItems:'center',gap:4,marginTop:8,fontFamily:FF.body,fontSize:11,fontWeight:600,color:theme.secondary}}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={theme.secondary} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>
          FITZROY, VIC
        </div>
      </div>
      <IconBtn theme={theme} platform={platform} onClick={onPostJob} badge={true}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={theme.onSurface} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>
      </IconBtn>
    </div>

    <div style={{marginBottom:14}}><Search theme={theme} value={query} onChange={setQuery}/></div>

    <div style={{display:'flex',gap:8,overflowX:'auto',marginBottom:24,paddingBottom:2}}>
      {chips.map(c=> <Chip theme={theme} key={c} label={c} active={activeChip===c} onClick={()=>setActiveChip(c)}/>)}
    </div>

    <SectionRow theme={theme} title="Nearby" meta={`${available.length} available now`}/>
    {available.map(t=> <TradieCard theme={theme} key={t.id} tradie={t} onClick={()=>onOpenTradie(t)}/>)}

    {offline.length>0 && <>
      <div style={{height:16}}/>
      <SectionRow theme={theme} title="Offline today"/>
      {offline.map(t=> <TradieCard theme={theme} key={t.id} tradie={t}/>)}
    </>}
  </div>;
}

window.BuilderHomeScreen = BuilderHomeScreen;
