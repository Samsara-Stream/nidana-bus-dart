// Writes the topology-ir@v1 invalid/ edge cases: each is a valid/ document
// with exactly one rule of the schema broken. Usage:
//   node tool/write_invalid.mjs {valid dir} {out dir}
// The base is forms.json, whose one topology has an edge of each form:
// 0 map, 1 withLatestFrom (a stage input, then a state read with dedup),
// 2 merge (a stage input, then an event read), 3 debounce, 4 write,
// 5 reduceInto; and one claim.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const [validDir, outDir] = process.argv.slice(2);
const load = (name) => JSON.parse(readFileSync(`${validDir}/${name}.json`, 'utf8'));
const forms = () => load('forms');
const edges = (d) => d.topologies[0].transforms;
const event = { name: 'x.y', variant: 'event', typeName: 'int' };

const cases = {
  format_missing: [forms(), (d) => { delete d.format; }],
  format_v2: [forms(), (d) => { d.format = 'topology-ir@v2'; }],
  unknown_top_level_key: [forms(), (d) => { d.generatedAt = '2026-10-17'; }],
  claims_missing: [forms(), (d) => { delete d.claims; }],
  topology_id_empty: [forms(), (d) => { d.topologies[0].topologyId = ''; }],
  scope_unknown: [forms(), (d) => { d.topologies[0].scope = 'session'; }],
  topic_variant_unknown: [forms(), (d) => { d.topologies[0].reads[0].variant = 'stream'; }],
  topic_ref_without_type_name: [forms(), (d) => { delete d.topologies[0].reads[0].typeName; }],
  topic_ref_extra_key: [forms(), (d) => { d.topologies[0].reads[0].sensitive = true; }],
  reads_repeat_topic: [forms(), (d) => { d.topologies[0].reads.push(d.topologies[0].reads[0]); }],
  topologies_repeat: [forms(), (d) => { d.topologies.push(d.topologies[0]); }],
  combinator_unknown: [forms(), (d) => { edges(d)[0].combinator = 'window'; }],
  write_with_transformer: [forms(), (d) => { edges(d)[4].transformer = { name: 'f' }; }],
  write_without_output: [forms(), (d) => { delete edges(d)[4].output; }],
  stage_with_output: [forms(), (d) => { edges(d)[0].output = event; }],
  map_without_transformer: [forms(), (d) => { delete edges(d)[0].transformer; }],
  map_with_two_inputs: [forms(), (d) => { edges(d)[0].inputs.push(edges(d)[0].inputs[0]); }],
  merge_without_inputs: [forms(), (d) => { edges(d)[2].inputs = []; }],
  merge_with_transformer: [forms(), (d) => { edges(d)[2].transformer = { name: 'f' }; }],
  with_latest_from_one_input: [forms(), (d) => { edges(d)[1].inputs = [edges(d)[1].inputs[0]]; }],
  with_latest_from_five_inputs: [forms(), (d) => {
    const i = edges(d)[1].inputs;
    edges(d)[1].inputs = [...i, i[0], i[1], i[0]];
  }],
  time_stage_without_duration: [forms(), (d) => { delete edges(d)[3].durationMicros; }],
  duration_negative: [forms(), (d) => { edges(d)[3].durationMicros = -1; }],
  duration_fractional: [forms(), (d) => { edges(d)[3].durationMicros = 1.5; }],
  retry_on_map: [forms(), (d) => { edges(d)[0].retry = { name: 'r' }; }],
  reduce_into_event_output: [forms(), (d) => { edges(d)[5].output = event; }],
  reduce_into_without_transformer: [forms(), (d) => { delete edges(d)[5].transformer; }],
  input_topic_and_edge: [forms(), (d) => { edges(d)[0].inputs[0].edge = 0; }],
  input_edge_negative: [forms(), (d) => { edges(d)[3].inputs = [{ edge: -1 }]; }],
  dedup_on_event_read: [forms(), (d) => { edges(d)[2].inputs[1].dedup = 'none'; }],
  dedup_unknown: [forms(), (d) => { edges(d)[1].inputs[1].dedup = 'always'; }],
  function_ref_empty_name: [forms(), (d) => { edges(d)[0].transformer = { name: '' }; }],
  function_ref_missing_name: [forms(), (d) => { edges(d)[0].transformer = {}; }],
  claim_topology_source: [forms(), (d) => { d.claims[0].source = 'topology:x'; }],
  claim_unknown_source: [forms(), (d) => { d.claims[0].source = 'unknown'; }],
  claim_event_topic: [forms(), (d) => { d.claims[0].writes = [event]; }],
  claim_without_writes: [forms(), (d) => { d.claims[0].writes = []; }],
  claim_scope_missing: [forms(), (d) => { delete d.claims[0].scope; }],
};

mkdirSync(outDir, { recursive: true });
for (const [name, [doc, edit]] of Object.entries(cases)) {
  edit(doc);
  writeFileSync(`${outDir}/${name}.json`, `${JSON.stringify(doc, null, 2)}\n`);
}
console.log(`wrote ${Object.keys(cases).length} invalid cases`);
