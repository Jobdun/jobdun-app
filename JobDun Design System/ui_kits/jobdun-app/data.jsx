// JobDun Galvanised — sample data for the UI kit prototype

const TRADIES = [
  {id:'mk', initials:'MK', name:'Marcus Kowalski', trade:'Electrician', suburb:'Fitzroy',
   rating:4.9, jobs:142, distance:3.2, available:true, verified:true,
   bio:'Licensed A-grade sparky, 12 years on Melbourne sites. Domestic + light commercial. Insured to $20M.',
   rate:'$95/hr', avatarBg:'#252D34'},
  {id:'sd', initials:'SD', name:'Sarah Dao', trade:'Plumber', suburb:'Brunswick',
   rating:4.8, jobs:88, distance:4.7, available:true, verified:true,
   bio:'Plumber + gas-fitter. Hot water specialist. Same-day urgent calls.',
   rate:'$110/hr', avatarBg:'#1A7AD4'},
  {id:'jt', initials:'JT', name:'James Tremblay', trade:'Carpenter', suburb:'Collingwood',
   rating:4.7, jobs:204, distance:5.1, available:true, verified:true,
   bio:'Frame-up to fit-out. Reno carpentry. Works with own crew of 2.',
   rate:'$85/hr', avatarBg:'#0D8A5A'},
  {id:'rb', initials:'RB', name:'Rachel Brennan', trade:'Tiler', suburb:'Northcote',
   rating:4.6, jobs:67, distance:6.8, available:false, verified:true,
   bio:'Wet-area specialist. Bathrooms, splashbacks, outdoor pavers.',
   rate:'$80/hr', avatarBg:'#5A6872'},
];

const JOBS = [
  {id:'j1', title:'Hot water system burst — Carlton',
   desc:'Tenant out of hot water since this morning. Need replacement of 250L electric tank ASAP. Existing tempering valve in place.',
   rate:'$95/hr', start:'Today', duration:'4 hrs', distance:1.4, urgent:true,
   trade:'Plumber', suburb:'Carlton', address:'18 Drummond St, Carlton',
   builder:{name:'Northside Property', initials:'NP', rating:4.7, jobs:38}},
  {id:'j2', title:'Bathroom retile — 8m²',
   desc:'Strip existing tiles, prep substrate, install supplied porcelain. Two-tone — wet wall + floor. Owner-occupied, weekday only.',
   rate:'$1,800 fixed', start:'12 May', duration:'2 days', distance:5.7, urgent:false,
   trade:'Tiler', suburb:'Thornbury', address:'42 High St, Thornbury',
   builder:{name:'Hayes Renovations', initials:'HR', rating:4.9, jobs:112}},
  {id:'j3', title:'Replace 6 downlights, kitchen',
   desc:'Existing wiring in place. Supply + install 6 IC-rated LED downlights. After-hours OK.',
   rate:'$420 fixed', start:'14 May', duration:'2 hrs', distance:2.9, urgent:false,
   trade:'Electrician', suburb:'Fitzroy', address:'7 Brunswick St, Fitzroy',
   builder:{name:'M. Vasiliev', initials:'MV', rating:4.5, jobs:14}},
];

window.TRADIES = TRADIES;
window.JOBS = JOBS;
