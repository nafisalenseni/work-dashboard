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
import"./chunk-b8731jc3.js";U.displayName="graphql";U.aliases=[];function U(K){K.languages.graphql={comment:/#.*/,description:{pattern:/(?:"""(?:[^"]|(?!""")")*"""|"(?:\\.|[^\\"\r\n])*")(?=\s*[a-z_])/i,greedy:!0,alias:"string",inside:{"language-markdown":{pattern:/(^"(?:"")?)(?!\1)[\s\S]+(?=\1$)/,lookbehind:!0,inside:K.languages.markdown}}},string:{pattern:/"""(?:[^"]|(?!""")")*"""|"(?:\\.|[^\\"\r\n])*"/,greedy:!0},number:/(?:\B-|\b)\d+(?:\.\d+)?(?:e[+-]?\d+)?\b/i,boolean:/\b(?:false|true)\b/,variable:/\$[a-z_]\w*/i,directive:{pattern:/@[a-z_]\w*/i,alias:"function"},"attr-name":{pattern:/\b[a-z_]\w*(?=\s*(?:\((?:[^()"]|"(?:\\.|[^\\"\r\n])*")*\))?:)/i,greedy:!0},"atom-input":{pattern:/\b[A-Z]\w*Input\b/,alias:"class-name"},scalar:/\b(?:Boolean|Float|ID|Int|String)\b/,constant:/\b[A-Z][A-Z_\d]*\b/,"class-name":{pattern:/(\b(?:enum|implements|interface|on|scalar|type|union)\s+|&\s*|:\s*|\[)[A-Z_]\w*/,lookbehind:!0},fragment:{pattern:/(\bfragment\s+|\.{3}\s*(?!on\b))[a-zA-Z_]\w*/,lookbehind:!0,alias:"function"},"definition-mutation":{pattern:/(\bmutation\s+)[a-zA-Z_]\w*/,lookbehind:!0,alias:"function"},"definition-query":{pattern:/(\bquery\s+)[a-zA-Z_]\w*/,lookbehind:!0,alias:"function"},keyword:/\b(?:directive|enum|extend|fragment|implements|input|interface|mutation|on|query|repeatable|scalar|schema|subscription|type|union)\b/,operator:/[!=|&]|\.{3}/,"property-query":/\w+(?=\s*\()/,object:/\w+(?=\s*\{)/,punctuation:/[!(){}\[\]:=,]/,property:/\w+/},K.hooks.add("after-tokenize",function(W){if(W.language!=="graphql")return;var G=W.tokens.filter(function(w){return typeof w!=="string"&&w.type!=="comment"&&w.type!=="scalar"}),z=0;function J(w){return G[z+w]}function X(w,D){D=D||0;for(var j=0;j<w.length;j++){var F=J(j+D);if(!F||F.type!==w[j])return!1}return!0}function Y(w,D){var j=1;for(var F=z;F<G.length;F++){var $=G[F],S=$.content;if($.type==="punctuation"&&typeof S==="string"){if(w.test(S))j++;else if(D.test(S)){if(j--,j===0)return F}}}return-1}function L(w,D){var j=w.alias;if(!j)w.alias=j=[];else if(!Array.isArray(j))w.alias=j=[j];j.push(D)}for(;z<G.length;){var Z=G[z++];if(Z.type==="keyword"&&Z.content==="mutation"){var M=[];if(X(["definition-mutation","punctuation"])&&J(1).content==="("){z+=2;var N=Y(/^\($/,/^\)$/);if(N===-1)continue;for(;z<N;z++){var O=J(0);if(O.type==="variable")L(O,"variable-input"),M.push(O.content)}z=N+1}if(X(["punctuation","property-query"])&&J(0).content==="{"){if(z++,L(J(0),"property-mutation"),M.length>0){var _=Y(/^\{$/,/^\}$/);if(_===-1)continue;for(var Q=z;Q<_;Q++){var R=G[Q];if(R.type==="variable"&&M.indexOf(R.content)>=0)L(R,"variable-input")}}}}}})}export{U as default};
