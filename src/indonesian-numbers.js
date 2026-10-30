const formatter=new Intl.NumberFormat('id-ID',{maximumFractionDigits:20});
export function formatNumberId(value){const n=typeof value==='number'?value:Number(value);return Number.isFinite(n)?formatter.format(n):String(value??'');}
export function parseNumberId(value){
 const text=String(value??'').trim();if(!text)return 0;
 if(!/^-?(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d*)?$/.test(text))return NaN;
 return Number(text.replaceAll('.','').replace(',','.'));
}
export function formatNumberDraft(value){
 const text=String(value??'');if(!/^-?[\d.]*(?:,\d*)?$/.test(text))return text;
 const [whole,fraction]=text.replaceAll('.','').split(',');if(!whole||whole==='-')return text;
 const negative=whole.startsWith('-'),digits=whole.replace(/^-/,'').replace(/^0+(?=\d)/,'');
 return (negative?'-':'')+digits.replace(/\B(?=(\d{3})+(?!\d))/g,'.')+(fraction!==undefined?','+fraction:'');
}
export function numberConstraintError(value,{min='',max='',step='1'}={}){
 if(!Number.isFinite(value))return 'Gunakan angka Indonesia, misalnya 1.000.000 atau 1.000,50.';
 if(min!==''&&value<Number(min))return 'Nilai minimal '+formatNumberId(min)+'.';
 if(max!==''&&value>Number(max))return 'Nilai maksimal '+formatNumberId(max)+'.';
 if(step!=='any'){
  const increment=Number(step||1),base=Number(min||0);if(increment>0){const units=(value-base)/increment;if(Math.abs(units-Math.round(units))>1e-7)return increment===1?'Isi bilangan bulat tanpa desimal.':'Gunakan kelipatan '+formatNumberId(increment)+'.';}
 }
 return '';
}
export function readNumber(input){if(!input)return 0;return input.dataset.numberLocale==='id'?parseNumberId(input.value):Number(input.value);}
function validate(input){
 const error=input.value===''?'':numberConstraintError(readNumber(input),{min:input.getAttribute('min')??'',max:input.getAttribute('max')??'',step:input.getAttribute('step')||'1'});
 input.setCustomValidity(error);return !error;
}
function prepare(input){
 if(input.dataset.numberLocale==='id')return;
 const raw=input.value;input.dataset.numberLocale='id';input.type='text';
 input.inputMode=(input.getAttribute('step')||'1').includes('.')?'decimal':'numeric';input.spellcheck=false;input.classList.add('number-id');
 input.value=raw===''?'':formatNumberId(Number(raw));validate(input);
}
export function setFieldValue(input,value){
 if(!input)return value;
 if(input.type==='number'||input.dataset.numberLocale==='id'){prepare(input);input.value=value===''||value===null||value===undefined?'':formatNumberId(value);validate(input);}
 else input.value=value;
 return value;
}
export function installIndonesianNumbers(root){
 const selector='input[type="number"],input[data-number-locale="id"]';
 const scan=node=>{if(node.nodeType!==1)return;if(node.matches(selector))prepare(node);node.querySelectorAll(selector).forEach(prepare);};
 const formCheck=form=>{let valid=true;form.querySelectorAll(selector).forEach(input=>{prepare(input);if(!validate(input))valid=false;});return valid;};
 const inputHandler=event=>{const input=event.target;if(!input.matches?.(selector))return;prepare(input);
  const raw=input.value,caret=input.selectionStart,logical=raw.slice(0,caret??raw.length).replaceAll('.','').length;
  const formatted=formatNumberDraft(raw);if(raw!==formatted){input.value=formatted;let count=0,index=0;for(;index<formatted.length&&count<logical;index++)if(formatted[index]!=='.')count++;input.setSelectionRange(index,index);}
  validate(input);
 };
 const blurHandler=event=>{const input=event.target;if(input.matches?.(selector)&&input.value!==''&&validate(input))input.value=formatNumberId(readNumber(input));};
 const submitHandler=event=>{if(event.target.tagName==='FORM'&&!formCheck(event.target)){event.preventDefault();event.stopImmediatePropagation();event.target.reportValidity();}};
 const refreshValidity=event=>{const form=event.target.closest?.('form');if(form)formCheck(form);};
 root.addEventListener('input',inputHandler,true);root.addEventListener('blur',blurHandler,true);root.addEventListener('submit',submitHandler,true);
 root.addEventListener('pointerdown',refreshValidity,true);root.addEventListener('keydown',refreshValidity,true);
 root.addEventListener('reset',event=>setTimeout(()=>event.target.querySelectorAll(selector).forEach(input=>{prepare(input);if(input.value===input.defaultValue)input.value=input.value===''?'':formatNumberId(Number(input.value));validate(input);}),0),true);
 const observer=new MutationObserver(changes=>{for(const m of changes){if(m.type==='attributes'){if(m.target.matches(selector)){prepare(m.target);validate(m.target);}}else m.addedNodes.forEach(scan);}});
 observer.observe(root,{childList:true,subtree:true,attributes:true,attributeFilter:['min','max','step','value']});scan(root);
 return ()=>observer.disconnect();
}
