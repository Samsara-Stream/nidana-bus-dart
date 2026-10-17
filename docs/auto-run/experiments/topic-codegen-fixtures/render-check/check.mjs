// Cross-checks for topic-codegen@v1 from project-local npm packages:
// (1) Ajv validates the schema's valid/ and invalid/ cases as marked;
// (2) the topology-graph.html golden, loaded in jsdom, holds in its
// <pre class="mermaid"> exactly the Mermaid text of topology-ir@v1's
// render/checkout.mmd golden, and Mermaid's parser accepts it.
// Usage: node check.mjs {fixture dir} {schema} {topology-ir render dir}
import { readdirSync, readFileSync } from 'node:fs';
import Ajv2020 from 'ajv/dist/2020.js';
import { JSDOM } from 'jsdom';

const [dir, schemaPath, renderDir] = process.argv.slice(2);
let failures = 0;
const report = (ok, text) => { if (!ok) failures++; console.log(`${ok ? 'PASS' : 'FAIL'} ${text}`); };

const ajv = new Ajv2020({ allErrors: true, strict: true });
const validate = ajv.compile(JSON.parse(readFileSync(schemaPath, 'utf8')));
for (const [sub, want] of [['valid', true], ['invalid', false]]) {
  let n = 0, ok = 0;
  for (const f of readdirSync(`${dir}/${sub}`).sort()) {
    n++;
    const got = validate(JSON.parse(readFileSync(`${dir}/${sub}/${f}`, 'utf8')));
    if (got === want) ok++; else console.log(`FAIL ajv ${sub}/${f}: ${got ? 'valid' : 'invalid'}`);
  }
  report(ok === n, `ajv ${sub}/: ${ok} of ${n} as marked`);
}

const html = readFileSync(`${dir}/expected/topology-graph.html`, 'utf8');
const dom = new JSDOM(html);
const pre = dom.window.document.querySelector('pre.mermaid');
const text = pre.textContent;
const golden = readFileSync(`${renderDir}/checkout.mmd`, 'utf8');
report(text === golden, 'html <pre class="mermaid"> text equals topology-ir render/checkout.mmd');
const script = dom.window.document.querySelector('script[type="module"]').textContent;
report(/mermaid@11\.12\.0\/dist\/mermaid\.esm\.min\.mjs/.test(script), 'html loads Mermaid 11.12.0 as an ES module');

globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.DOMParser = dom.window.DOMParser;
globalThis.Element = dom.window.Element;
const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false });
try {
  const r = await mermaid.parse(text);
  report(true, `mermaid parses the embedded diagram: ${r.diagramType}`);
} catch (e) {
  report(false, `mermaid parse: ${String(e.message || e).split('\n')[0]}`);
}
process.exit(failures ? 1 : 0);
