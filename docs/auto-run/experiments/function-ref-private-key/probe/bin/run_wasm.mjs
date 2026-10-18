import { readFile } from 'node:fs/promises';
import { compile } from './a.mjs';
globalThis.dartPrint = (s) => console.log(s);
const bytes = await readFile(new URL('./a.wasm', import.meta.url));
const app = await compile(bytes);
const instance = await app.instantiate({});
instance.invokeMain();
