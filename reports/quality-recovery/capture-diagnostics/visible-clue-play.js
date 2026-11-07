// Real rendered controls only; no access to Dart state or covered mine data.
window.__tinyMedia = {status:'starting',actions:[]};
function deepQuery(selector){
  const roots=[document],found=[];
  for(let i=0;i<roots.length;i++){
    const root=roots[i];found.push(...root.querySelectorAll(selector));
    for(const el of root.querySelectorAll('*'))if(el.shadowRoot)roots.push(el.shadowRoot);
  }
  return found;
}
deepQuery('flt-semantics-placeholder').forEach(e=>e.click());
(async()=>{
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const neighbors=i=>{const out=[];for(let dr=-1;dr<=1;dr++)for(let dc=-1;dc<=1;dc++){
    if(!dr&&!dc)continue;const r=Math.floor(i/6)+dr,c=i%6+dc;
    if(r>=0&&r<6&&c>=0&&c<6)out.push(r*6+c);
  }return out;};
  function grid(){
    return deepQuery('[aria-label]').map(e=>({e,label:e.getAttribute('aria-label').trim(),r:e.getBoundingClientRect()}))
      .filter(x=>/^(Hidden tile|Flag|Empty|Flower|[1-8])$/.test(x.label)&&x.r.width>18&&Math.abs(x.r.width-x.r.height)<4)
      .sort((a,b)=>Math.abs(a.r.y-b.r.y)>5?a.r.y-b.r.y:a.r.x-b.r.x);
  }
  await sleep(900);
  let cells=grid();
  if(cells.length!==36){window.__tinyMedia={status:'no accessible grid',count:cells.length,labels:deepQuery('[aria-label]').slice(0,80).map(e=>({label:e.getAttribute('aria-label'),width:e.getBoundingClientRect().width,height:e.getBoundingClientRect().height}))};return;}
  cells[21].e.click();window.__tinyMedia.actions.push({action:'dig',index:21});
  await sleep(900);
  const marked=new Set();
  for(let step=0;step<64;step++){
    cells=grid();
    if(cells.some(c=>c.label==='Flower')){window.__tinyMedia.status='won';return;}
    if(cells.length!==36){window.__tinyMedia.status='grid changed';return;}
    const unknown=new Set(cells.map((c,i)=>c.label==='Hidden tile'&&!marked.has(i)?i:-1).filter(i=>i>=0));
    const constraints=[{cells:unknown,count:5-marked.size}];
    for(let i=0;i<36;i++){
      const c=cells[i];if(!/^(Empty|[1-8])$/.test(c.label))continue;
      const around=neighbors(i),u=new Set(around.filter(n=>unknown.has(n)));
      if(u.size)constraints.push({cells:u,count:(c.label==='Empty'?0:Number(c.label))-around.filter(n=>marked.has(n)).length});
    }
    const safe=new Set(),mines=new Set();
    function apply(set,count){if(!set.size)return;if(count===0)for(const i of set)safe.add(i);if(count===set.size)for(const i of set)mines.add(i);}
    for(const c of constraints)apply(c.cells,c.count);
    for(const a of constraints)for(const b of constraints){
      if(a.cells.size>=b.cells.size||![...a.cells].every(i=>b.cells.has(i)))continue;
      apply(new Set([...b.cells].filter(i=>!a.cells.has(i))),b.count-a.count);
    }
    const newMines=[...mines].filter(i=>!marked.has(i));newMines.forEach(i=>marked.add(i));
    const next=[...safe].find(i=>cells[i].label==='Hidden tile'&&!marked.has(i));
    if(next!==undefined){cells[next].e.click();window.__tinyMedia.actions.push({action:'dig',index:next});await sleep(850);}
    else if(newMines.length){await sleep(100);}
    else{window.__tinyMedia.status='no visible-clue move';return;}
  }
  window.__tinyMedia.status='bounded stop';
})().catch(e=>{window.__tinyMedia.status='error';window.__tinyMedia.error=String(e);});
