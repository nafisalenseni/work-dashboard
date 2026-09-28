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
import"./chunk-b8731jc3.js";D.displayName="lisp";D.aliases=["elisp","emacs","emacs-lisp"];function D(H){(function(w){function E(C){return RegExp(/(\()/.source+"(?:"+C+")"+/(?=[\s\)])/.source)}function F(C){return RegExp(/([\s([])/.source+"(?:"+C+")"+/(?=[\s)])/.source)}var h=/(?!\d)[-+*/~!@$%^=<>{}\w]+/.source,I="&"+h,q="(\\()",J="(?=\\))",G="(?=\\s)",x=/(?:[^()]|\((?:[^()]|\((?:[^()]|\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))*\))*\))*/.source,j={heading:{pattern:/;;;.*/,alias:["comment","title"]},comment:/;.*/,string:{pattern:/"(?:[^"\\]|\\.)*"/,greedy:!0,inside:{argument:/[-A-Z]+(?=[.,\s])/,symbol:RegExp("`"+h+"'")}},"quoted-symbol":{pattern:RegExp("#?'"+h),alias:["variable","symbol"]},"lisp-property":{pattern:RegExp(":"+h),alias:"property"},splice:{pattern:RegExp(",@?"+h),alias:["symbol","variable"]},keyword:[{pattern:RegExp(q+"(?:and|(?:cl-)?letf|cl-loop|cond|cons|error|if|(?:lexical-)?let\\*?|message|not|null|or|provide|require|setq|unless|use-package|when|while)"+G),lookbehind:!0},{pattern:RegExp(q+"(?:append|by|collect|concat|do|finally|for|in|return)"+G),lookbehind:!0}],declare:{pattern:E(/declare/.source),lookbehind:!0,alias:"keyword"},interactive:{pattern:E(/interactive/.source),lookbehind:!0,alias:"keyword"},boolean:{pattern:F(/nil|t/.source),lookbehind:!0},number:{pattern:F(/[-+]?\d+(?:\.\d*)?/.source),lookbehind:!0},defvar:{pattern:RegExp(q+"def(?:const|custom|group|var)\\s+"+h),lookbehind:!0,inside:{keyword:/^def[a-z]+/,variable:RegExp(h)}},defun:{pattern:RegExp(q+/(?:cl-)?(?:defmacro|defun\*?)\s+/.source+h+/\s+\(/.source+x+/\)/.source),lookbehind:!0,greedy:!0,inside:{keyword:/^(?:cl-)?def\S+/,arguments:null,function:{pattern:RegExp("(^\\s)"+h),lookbehind:!0},punctuation:/[()]/}},lambda:{pattern:RegExp(q+"lambda\\s+\\(\\s*(?:&?"+h+"(?:\\s+&?"+h+")*\\s*)?\\)"),lookbehind:!0,greedy:!0,inside:{keyword:/^lambda/,arguments:null,punctuation:/[()]/}},car:{pattern:RegExp(q+h),lookbehind:!0},punctuation:[/(?:['`,]?\(|[)\[\]])/,{pattern:/(\s)\.(?=\s)/,lookbehind:!0}]},z={"lisp-marker":RegExp(I),varform:{pattern:RegExp(/\(/.source+h+/\s+(?=\S)/.source+x+/\)/.source),inside:j},argument:{pattern:RegExp(/(^|[\s(])/.source+h),lookbehind:!0,alias:"variable"},rest:j},A="\\S+(?:\\s+\\S+)*",B={pattern:RegExp(q+x+J),lookbehind:!0,inside:{"rest-vars":{pattern:RegExp("&(?:body|rest)\\s+"+A),inside:z},"other-marker-vars":{pattern:RegExp("&(?:aux|optional)\\s+"+A),inside:z},keys:{pattern:RegExp("&key\\s+"+A+"(?:\\s+&allow-other-keys)?"),inside:z},argument:{pattern:RegExp(h),alias:"variable"},punctuation:/[()]/}};j.lambda.inside.arguments=B,j.defun.inside.arguments=w.util.clone(B),j.defun.inside.arguments.inside.sublist=B,w.languages.lisp=j,w.languages.elisp=j,w.languages.emacs=j,w.languages["emacs-lisp"]=j})(H)}export{D as default};
