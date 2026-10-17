// Parses every render/*.mmd golden with Mermaid's own parser (under jsdom)
// and lays out every render/*.dot golden with Graphviz (wasm). A golden that
// does not parse prints FAIL. Usage: node check.mjs {render dir}
import { readdirSync, readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.DOMParser = dom.window.DOMParser;
globalThis.Element = dom.window.Element;

const { default: mermaid } = await import('mermaid');
const { Graphviz } = await import('@hpcc-js/wasm-graphviz');
mermaid.initialize({ startOnLoad: false });
const graphviz = await Graphviz.load();

const dir = process.argv[2];
let failures = 0;
for (const f of readdirSync(dir).sort()) {
  const text = readFileSync(`${dir}/${f}`, 'utf8');
  try {
    if (f.endsWith('.mmd')) {
      const r = await mermaid.parse(text);
      console.log(`PASS ${f} mermaid ${r.diagramType}`);
    } else if (f.endsWith('.dot')) {
      const svg = graphviz.dot(text, 'svg');
      const nodes = (svg.match(/class="node"/g) || []).length;
      const clusters = (svg.match(/class="cluster"/g) || []).length;
      console.log(`PASS ${f} graphviz ${graphviz.version()} nodes=${nodes} clusters=${clusters}`);
    }
  } catch (e) {
    failures++;
    console.log(`FAIL ${f}: ${String(e.message || e).split('\n')[0]}`);
  }
}
process.exit(failures ? 1 : 0);
