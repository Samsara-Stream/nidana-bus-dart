// Cross-checks the topology-ir@v1 schema with a second validator (Ajv,
// draft 2020-12, strict mode): it compiles, every valid/ file validates and
// no invalid/ file does. Usage: node schema.mjs {schema} {fixture dir}
import { readdirSync, readFileSync } from 'node:fs';
import Ajv2020 from 'ajv/dist/2020.js';

const [schemaPath, dir] = process.argv.slice(2);
const ajv = new Ajv2020({ strict: true, allErrors: false });
const validate = ajv.compile(JSON.parse(readFileSync(schemaPath, 'utf8')));
let failures = 0;
for (const set of ['valid', 'invalid']) {
  for (const f of readdirSync(`${dir}/${set}`).filter((n) => n.endsWith('.json')).sort()) {
    const ok = validate(JSON.parse(readFileSync(`${dir}/${set}/${f}`, 'utf8'))) === (set === 'valid');
    if (!ok) failures++;
    console.log(`${ok ? 'PASS' : 'FAIL'} ${set}/${f}`);
  }
}
process.exit(failures ? 1 : 0);
