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
import"./chunk-b8731jc3.js";g.displayName="ocaml";g.aliases=[];function g(j){j.languages.ocaml={comment:{pattern:/\(\*[\s\S]*?\*\)/,greedy:!0},char:{pattern:/'(?:[^\\\r\n']|\\(?:.|[ox]?[0-9a-f]{1,3}))'/i,greedy:!0},string:[{pattern:/"(?:\\(?:[\s\S]|\r\n)|[^\\\r\n"])*"/,greedy:!0},{pattern:/\{([a-z_]*)\|[\s\S]*?\|\1\}/,greedy:!0}],number:[/\b(?:0b[01][01_]*|0o[0-7][0-7_]*)\b/i,/\b0x[a-f0-9][a-f0-9_]*(?:\.[a-f0-9_]*)?(?:p[+-]?\d[\d_]*)?(?!\w)/i,/\b\d[\d_]*(?:\.[\d_]*)?(?:e[+-]?\d[\d_]*)?(?!\w)/i],directive:{pattern:/\B#\w+/,alias:"property"},label:{pattern:/\B~\w+/,alias:"property"},"type-variable":{pattern:/\B'\w+/,alias:"function"},variant:{pattern:/`\w+/,alias:"symbol"},keyword:/\b(?:as|assert|begin|class|constraint|do|done|downto|else|end|exception|external|for|fun|function|functor|if|in|include|inherit|initializer|lazy|let|match|method|module|mutable|new|nonrec|object|of|open|private|rec|sig|struct|then|to|try|type|val|value|virtual|when|where|while|with)\b/,boolean:/\b(?:false|true)\b/,"operator-like-punctuation":{pattern:/\[[<>|]|[>|]\]|\{<|>\}/,alias:"punctuation"},operator:/\.[.~]|:[=>]|[=<>@^|&+\-*\/$%!?~][!$%&*+\-.\/:<=>?@^|~]*|\b(?:and|asr|land|lor|lsl|lsr|lxor|mod|or)\b/,punctuation:/;;|::|[(){}\[\].,:;#]|\b_\b/}}export{g as default};
