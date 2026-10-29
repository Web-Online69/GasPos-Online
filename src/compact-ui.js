export function summarizeWorkQueue(jobs){return {total:jobs.reduce((n,j)=>n+(Number.isFinite(j.count)?Math.max(0,j.count):0),0),unavailable:jobs.some(j=>j.count===null),active:jobs.filter(j=>j.count===null||j.count>0)};}
export function shortReference(value,max=24){const s=String(value??'');if(s.length<=max)return s;return s.slice(0,max-9)+'…'+s.slice(-8);}
// Display only. Original identifiers remain in forms, attributes, stored records and prints.
export function compactTableReferences(table){
 for(const cell of table.querySelectorAll('tbody td')){
  if(cell.closest('details.compact-reference'))continue;
  const walk=document.createTreeWalker(cell,NodeFilter.SHOW_TEXT,{acceptNode(node){return node.parentElement.closest('button,details,svg')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT;}});
  const nodes=[];while(walk.nextNode())nodes.push(walk.currentNode);
  for(const node of nodes){const pattern=/[A-Za-z0-9][A-Za-z0-9_-]{24,}/g;const text=node.textContent;const matches=[...text.matchAll(pattern)];if(!matches.length)continue;
   const fragment=document.createDocumentFragment();let offset=0;
   for(const match of matches){fragment.append(document.createTextNode(text.slice(offset,match.index)));const details=document.createElement('details');details.className='compact-reference';details.dataset.full=match[0];const summary=document.createElement('summary');summary.textContent=shortReference(match[0]);summary.title='Lihat nomor lengkap';summary.setAttribute('aria-label','Lihat nomor lengkap '+match[0]);const full=document.createElement('span');full.className='full-reference';full.textContent=match[0];details.append(summary,full);fragment.append(details);offset=match.index+match[0].length;}
   fragment.append(document.createTextNode(text.slice(offset)));node.replaceWith(fragment);
  }
 }
}
