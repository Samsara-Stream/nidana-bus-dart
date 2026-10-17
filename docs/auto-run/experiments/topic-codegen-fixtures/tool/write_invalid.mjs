// Writes hsdd/contract/fixture/topic-codegen/invalid/: each file is
// valid/every-field.json with one schema rule broken, named after the rule.
// Usage (from the repository root): node <this file>
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';

const dir = 'hsdd/contract/fixture/topic-codegen';
const base = JSON.parse(readFileSync(`${dir}/valid/every-field.json`, 'utf8'));
const clone = () => structuredClone(base);
const auth = (d) => d.domains.auth;
const topic = (d, k) => d.domains.auth.topics[k];
const renameKey = (obj, from, to) =>
  Object.fromEntries(Object.entries(obj).map(([k, v]) => [k === from ? to : k, v]));

const cases = {
  'document-not-object': () => [],
  'document-unknown-key': (d) => ({ ...d, version: 1 }),
  'domains-missing': () => ({}),
  'domains-empty': () => ({ domains: {} }),
  'domain-key-uppercase': (d) => ({ domains: renameKey(d.domains, 'auth', 'Auth') }),
  'domain-key-two-segments': (d) => ({ domains: renameKey(d.domains, 'auth', 'auth.core') }),
  'domain-key-underscore': (d) => ({ domains: renameKey(d.domains, 'auth', 'auth_core') }),
  'domain-not-object': (d) => { d.domains.auth = 'platform-team'; return d; },
  'domain-unknown-key': (d) => { auth(d).team = 'platform-team'; return d; },
  'owner-missing': (d) => { delete auth(d).owner; return d; },
  'owner-blank': (d) => { auth(d).owner = '   '; return d; },
  'owner-multiline': (d) => { auth(d).owner = 'platform\nteam'; return d; },
  'owner-padded': (d) => { auth(d).owner = ' platform-team'; return d; },
  'owner-not-string': (d) => { auth(d).owner = 7; return d; },
  'dart-unknown-key': (d) => { auth(d).dart.prefix = 'auth'; return d; },
  'imports-not-array': (d) => { auth(d).dart.imports = 'package:example_app/auth/auth.dart'; return d; },
  'import-not-dart-file': (d) => { auth(d).dart.imports.push('package:example_app/auth'); return d; },
  'import-with-quote': (d) => { auth(d).dart.imports.push("package:example_app/it's.dart"); return d; },
  'import-with-space': (d) => { auth(d).dart.imports.push('package:example_app/a b.dart'); return d; },
  'import-duplicate': (d) => { auth(d).dart.imports.push('dart:typed_data'); return d; },
  'topics-missing': (d) => { delete auth(d).topics; return d; },
  'topics-empty': (d) => { auth(d).topics = {}; return d; },
  'topic-key-uppercase': (d) => { auth(d).topics = renameKey(auth(d).topics, 'login-event', 'loginEvent'); return d; },
  'topic-key-three-segments': (d) => { auth(d).topics = renameKey(auth(d).topics, 'token.refresh', 'token.refresh.done'); return d; },
  'topic-key-trailing-hyphen': (d) => { auth(d).topics = renameKey(auth(d).topics, 'login-event', 'login-'); return d; },
  'topic-key-leading-digit': (d) => { auth(d).topics = renameKey(auth(d).topics, 'attempts', '2fa'); return d; },
  'topic-not-object': (d) => { auth(d).topics.attempts = 'int'; return d; },
  'topic-unknown-key': (d) => { topic(d, 'login-event').sensitve = true; return d; },
  'type-missing': (d) => { delete topic(d, 'state').type; return d; },
  'type-blank': (d) => { topic(d, 'state').type = ''; return d; },
  'type-multiline': (d) => { topic(d, 'state').type = 'Map<String,\nint>'; return d; },
  'type-padded': (d) => { topic(d, 'state').type = 'AuthState '; return d; },
  'variant-missing': (d) => { delete topic(d, 'login-event').variant; return d; },
  'variant-unknown': (d) => { topic(d, 'login-event').variant = 'behavior'; return d; },
  'state-initial-missing': (d) => { delete topic(d, 'state').initial; return d; },
  'state-buffer-size': (d) => { topic(d, 'state')['buffer-size'] = 2; return d; },
  'initial-list': (d) => { topic(d, 'attempts').initial = []; return d; },
  'initial-object': (d) => { topic(d, 'attempts').initial = {}; return d; },
  'initial-blank-string': (d) => { topic(d, 'state').initial = ''; return d; },
  'initial-multiline-string': (d) => { topic(d, 'state').initial = 'AuthState\n.initializing()'; return d; },
  'event-initial': (d) => { topic(d, 'login-event').initial = 'null'; return d; },
  'event-dedup': (d) => { topic(d, 'login-event').dedup = 'none'; return d; },
  'event-buffer-size': (d) => { topic(d, 'login-event')['buffer-size'] = 1; return d; },
  'replay-buffer-size-missing': (d) => { delete topic(d, 'token.refresh')['buffer-size']; return d; },
  'replay-buffer-size-zero': (d) => { topic(d, 'token.refresh')['buffer-size'] = 0; return d; },
  'replay-buffer-size-not-integer': (d) => { topic(d, 'token.refresh')['buffer-size'] = 2.5; return d; },
  'replay-initial': (d) => { topic(d, 'token.refresh').initial = 'null'; return d; },
  'replay-dedup': (d) => { topic(d, 'token.refresh').dedup = 'equality'; return d; },
  'dedup-unknown': (d) => { topic(d, 'state').dedup = 'identity'; return d; },
  'sensitive-not-boolean': (d) => { topic(d, 'state').sensitive = 'yes'; return d; },
  'tracing-unknown': (d) => { topic(d, 'state').tracing = 'off'; return d; },
  'description-blank': (d) => { topic(d, 'state').description = '  \n '; return d; },
  'description-not-string': (d) => { topic(d, 'state').description = 3; return d; },
};

rmSync(`${dir}/invalid`, { recursive: true, force: true });
mkdirSync(`${dir}/invalid`, { recursive: true });
for (const [name, mutate] of Object.entries(cases)) {
  writeFileSync(`${dir}/invalid/${name}.json`, JSON.stringify(mutate(clone()), null, 2) + '\n');
}
console.log(`wrote ${Object.keys(cases).length} invalid documents`);
