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
import{e as w}from"./chunk-rys2swmw.js";import"./chunk-gvb5b7qh.js";import"./chunk-b8731jc3.js";q.displayName="typescript";q.aliases=["ts"];function q(u){u.register(w),function(k){k.languages.typescript=k.languages.extend("javascript",{"class-name":{pattern:/(\b(?:class|extends|implements|instanceof|interface|new|type)\s+)(?!keyof\b)(?!\s)[_$a-zA-Z\xA0-\uFFFF](?:(?!\s)[$\w\xA0-\uFFFF])*(?:\s*<(?:[^<>]|<(?:[^<>]|<[^<>]*>)*>)*>)?/,lookbehind:!0,greedy:!0,inside:null},builtin:/\b(?:Array|Function|Promise|any|boolean|console|never|number|string|symbol|unknown)\b/}),k.languages.typescript.keyword.push(/\b(?:abstract|declare|is|keyof|readonly|require)\b/,/\b(?:asserts|infer|interface|module|namespace|type)\b(?=\s*(?:[{_$a-zA-Z\xA0-\uFFFF]|$))/,/\btype\b(?=\s*(?:[\{*]|$))/),delete k.languages.typescript.parameter,delete k.languages.typescript["literal-property"];var l=k.languages.extend("typescript",{});delete l["class-name"],k.languages.typescript["class-name"].inside=l,k.languages.insertBefore("typescript","function",{decorator:{pattern:/@[$\w\xA0-\uFFFF]+/,inside:{at:{pattern:/^@/,alias:"operator"},function:/^[\s\S]+/}},"generic-function":{pattern:/#?(?!\s)[_$a-zA-Z\xA0-\uFFFF](?:(?!\s)[$\w\xA0-\uFFFF])*\s*<(?:[^<>]|<(?:[^<>]|<[^<>]*>)*>)*>(?=\s*\()/,greedy:!0,inside:{function:/^#?(?!\s)[_$a-zA-Z\xA0-\uFFFF](?:(?!\s)[$\w\xA0-\uFFFF])*/,generic:{pattern:/<[\s\S]+/,alias:"class-name",inside:l}}}}),k.languages.ts=k.languages.typescript}(u)}export{q as default};
export{q as a};
