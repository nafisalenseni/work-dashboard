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
import"./chunk-b8731jc3.js";c.displayName="elm";c.aliases=[];function c(f){f.languages.elm={comment:/--.*|\{-[\s\S]*?-\}/,char:{pattern:/'(?:[^\\'\r\n]|\\(?:[abfnrtv\\']|\d+|x[0-9a-fA-F]+|u\{[0-9a-fA-F]+\}))'/,greedy:!0},string:[{pattern:/"""[\s\S]*?"""/,greedy:!0},{pattern:/"(?:[^\\"\r\n]|\\.)*"/,greedy:!0}],"import-statement":{pattern:/(^[\t ]*)import\s+[A-Z]\w*(?:\.[A-Z]\w*)*(?:\s+as\s+(?:[A-Z]\w*)(?:\.[A-Z]\w*)*)?(?:\s+exposing\s+)?/m,lookbehind:!0,inside:{keyword:/\b(?:as|exposing|import)\b/}},keyword:/\b(?:alias|as|case|else|exposing|if|in|infixl|infixr|let|module|of|then|type)\b/,builtin:/\b(?:abs|acos|always|asin|atan|atan2|ceiling|clamp|compare|cos|curry|degrees|e|flip|floor|fromPolar|identity|isInfinite|isNaN|logBase|max|min|negate|never|not|pi|radians|rem|round|sin|sqrt|tan|toFloat|toPolar|toString|truncate|turns|uncurry|xor)\b/,number:/\b(?:\d+(?:\.\d+)?(?:e[+-]?\d+)?|0x[0-9a-f]+)\b/i,operator:/\s\.\s|[+\-/*=.$<>:&|^?%#@~!]{2,}|[+\-/*=$<>:&|^?%#@~!]/,hvariable:/\b(?:[A-Z]\w*\.)*[a-z]\w*\b/,constant:/\b(?:[A-Z]\w*\.)*[A-Z]\w*\b/,punctuation:/[{}[\]|(),.:]/}}export{c as default};
