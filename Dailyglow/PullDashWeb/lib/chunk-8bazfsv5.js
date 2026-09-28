// Worker shim for libraries that check for document (Prism/refractor)
if (typeof document === 'undefined') {
  globalThis.document = {
    currentScript: null,
    querySelectorAll: () => [],
    querySelector: () => null,
    getElementById: () => null,
    getElementsByClassName: () => [],
    getElementsByTagName: () => [],
    createElement: () => ({
      setAttribute: () => {},
      getAttribute: () => null,
      appendChild: () => {},
      removeChild: () => {},
      classList: { add: () => {}, remove: () => {}, contains: () => false },
      style: {},
      innerHTML: '',
      textContent: '',
    }),
    createTextNode: () => ({ textContent: '' }),
    createDocumentFragment: () => ({ appendChild: () => {}, childNodes: [] }),
    head: { appendChild: () => {}, removeChild: () => {} },
    body: { appendChild: () => {}, removeChild: () => {} },
    addEventListener: () => {},
    removeEventListener: () => {},
  };
}
import{d as U}from"./chunk-0f4jjy6v.js";import{e as S}from"./chunk-rys2swmw.js";import"./chunk-gvb5b7qh.js";import"./chunk-b8731jc3.js";L.displayName="jsx";L.aliases=[];function L(I){I.register(S),I.register(U),function(D){var O=D.util.clone(D.languages.javascript),V=/(?:\s|\/\/.*(?!.)|\/\*(?:[^*]|\*(?!\/))\*\/)/.source,W=/(?:\{(?:\{(?:\{[^{}]*\}|[^{}])*\}|[^{}])*\})/.source,K=/(?:\{<S>*\.{3}(?:[^{}]|<BRACES>)*\})/.source;function H(q,z){return q=q.replace(/<S>/g,function(){return V}).replace(/<BRACES>/g,function(){return W}).replace(/<SPREAD>/g,function(){return K}),RegExp(q,z)}K=H(K).source,D.languages.jsx=D.languages.extend("markup",O),D.languages.jsx.tag.pattern=H(/<\/?(?:[\w.:-]+(?:<S>+(?:[\w.:$-]+(?:=(?:"(?:\\[\s\S]|[^\\"])*"|'(?:\\[\s\S]|[^\\'])*'|[^\s{'"/>=]+|<BRACES>))?|<SPREAD>))*<S>*\/?)?>/.source),D.languages.jsx.tag.inside.tag.pattern=/^<\/?[^\s>\/]*/,D.languages.jsx.tag.inside["attr-value"].pattern=/=(?!\{)(?:"(?:\\[\s\S]|[^\\"])*"|'(?:\\[\s\S]|[^\\'])*'|[^\s'">]+)/,D.languages.jsx.tag.inside.tag.inside["class-name"]=/^[A-Z]\w*(?:\.[A-Z]\w*)*$/,D.languages.jsx.tag.inside.comment=O.comment,D.languages.insertBefore("inside","attr-name",{spread:{pattern:H(/<SPREAD>/.source),inside:D.languages.jsx}},D.languages.jsx.tag),D.languages.insertBefore("inside","special-attr",{script:{pattern:H(/=<BRACES>/.source),alias:"language-javascript",inside:{"script-punctuation":{pattern:/^=(?=\{)/,alias:"punctuation"},rest:D.languages.jsx}}},D.languages.jsx.tag);var F=function(q){if(!q)return"";if(typeof q==="string")return q;if(typeof q.content==="string")return q.content;return q.content.map(F).join("")},Q=function(q){var z=[];for(var E=0;E<q.length;E++){var C=q[E],R=!1;if(typeof C!=="string")if(C.type==="tag"&&C.content[0]&&C.content[0].type==="tag")if(C.content[0].content[0].content==="</"){if(z.length>0&&z[z.length-1].tagName===F(C.content[0].content[1]))z.pop()}else if(C.content[C.content.length-1].content==="/>");else z.push({tagName:F(C.content[0].content[1]),openedBraces:0});else if(z.length>0&&C.type==="punctuation"&&C.content==="{")z[z.length-1].openedBraces++;else if(z.length>0&&z[z.length-1].openedBraces>0&&C.type==="punctuation"&&C.content==="}")z[z.length-1].openedBraces--;else R=!0;if(R||typeof C==="string"){if(z.length>0&&z[z.length-1].openedBraces===0){var G=F(C);if(E<q.length-1&&(typeof q[E+1]==="string"||q[E+1].type==="plain-text"))G+=F(q[E+1]),q.splice(E+1,1);if(E>0&&(typeof q[E-1]==="string"||q[E-1].type==="plain-text"))G=F(q[E-1])+G,q.splice(E-1,1),E--;q[E]=new D.Token("plain-text",G,null,G)}}if(C.content&&typeof C.content!=="string")Q(C.content)}};D.hooks.add("after-tokenize",function(q){if(q.language!=="jsx"&&q.language!=="tsx")return;Q(q.tokens)})}(I)}export{L as default};
export{L as c};
