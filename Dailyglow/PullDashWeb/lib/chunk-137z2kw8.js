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
import{a as w}from"./chunk-hzxpx6z1.js";import{c as v}from"./chunk-8bazfsv5.js";import"./chunk-0f4jjy6v.js";import"./chunk-rys2swmw.js";import"./chunk-gvb5b7qh.js";import"./chunk-b8731jc3.js";q.displayName="tsx";q.aliases=[];function q(l){l.register(v),l.register(w),function(d){var z=d.util.clone(d.languages.typescript);d.languages.tsx=d.languages.extend("jsx",z),delete d.languages.tsx.parameter,delete d.languages.tsx["literal-property"];var k=d.languages.tsx.tag;k.pattern=RegExp(/(^|[^\w$]|(?=<\/))/.source+"(?:"+k.pattern.source+")",k.pattern.flags),k.lookbehind=!0}(l)}export{q as default};
