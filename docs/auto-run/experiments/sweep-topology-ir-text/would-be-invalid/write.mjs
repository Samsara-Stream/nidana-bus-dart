// Writes the three invalid/ documents S146 asked for (an empty typeName, a
// dedup on a replay read, a claim listing one topic twice) in the form of the
// committed ones (docs/auto-run/experiments/topology-ir-fixtures/tool/
// write_invalid.mjs): valid/forms.json with exactly one rule of the schema
// broken, named after the rule. They are written here, not under invalid/,
// because packages/nidana_dart_contracts/test/json_reject_test.dart pins the
// exact list of invalid/ files (S153, run.sh section W). Usage:
//   node write.mjs {valid dir} {out dir}
// forms.json's one topology: 0 map, 1 withLatestFrom (a stage input, then a
// state read with dedup), 2 merge (a stage input, then an event read),
// 3 debounce, 4 write, 5 reduceInto; and one claim. Its reads are
// forms.event (event) and forms.state (state).
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const [validDir, outDir] = process.argv.slice(2);
const forms = () => JSON.parse(readFileSync(`${validDir}/forms.json`, 'utf8'));
const edges = (d) => d.topologies[0].transforms;

const cases = {
  // typeName's minLength. reads[0] is decoded first, so the decoder rejects
  // the empty typeName before it compares reads with the edges.
  topic_ref_empty_type_name: (d) => { d.topologies[0].reads[0].typeName = ''; },
  // A dedup on a read of a replay topic: merge's second input reads
  // forms.event as a replay topic, and reads lists that topic in canonical
  // order (name, then variant state, event, replay), so the dedup is the one
  // rule broken.
  dedup_on_replay_read: (d) => {
    const replay = { name: 'forms.event', variant: 'replay', typeName: 'int' };
    edges(d)[2].inputs[1] = { topic: replay, dedup: 'equality' };
    d.topologies[0].reads.splice(1, 0, replay);
  },
  // The claim's writes repeat a topic: uniqueItems.
  claim_repeat_topic: (d) => { d.claims[0].writes.push(d.claims[0].writes[0]); },
};

mkdirSync(outDir, { recursive: true });
for (const [name, edit] of Object.entries(cases)) {
  const doc = forms();
  edit(doc);
  writeFileSync(`${outDir}/${name}.json`, `${JSON.stringify(doc, null, 2)}\n`);
}
console.log(`wrote ${Object.keys(cases).length} would-be invalid documents`);
