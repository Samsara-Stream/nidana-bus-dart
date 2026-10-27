import { readFile } from 'node:fs/promises';
import { compile } from './main.mjs';
globalThis.dartPrint = (s) => console.log(s);
const bytes = await readFile(new URL('./main.wasm', import.meta.url));
const app = await compile(bytes);
const instance = await app.instantiate({});
instance.invokeMain();
