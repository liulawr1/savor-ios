import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, statSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseEnv } from 'node:util';
import { setup } from '../setup.mjs';
test('setup imports only Gemini key, creates independent pairing and keeps it out of tracked config', t => {
 const root = mkdtempSync(join(tmpdir(), 'savor-setup-')); t.after(() => rmSync(root,{recursive:true,force:true}));
 const server = join(root, 'server'); mkdirSync(server);
 const source = join(root, 'source.env'); writeFileSync(source, 'GEMINI_API_KEY=test-gemini-secret\nMEND_CLIENT_TOKEN=other-app-token\n');
 assert.equal(setup(server,source).keyConfigured,true);
 const env = parseEnv(readFileSync(join(server,'.env'),'utf8')); assert.equal(env.GEMINI_API_KEY,'test-gemini-secret'); assert.match(env.SAVOR_CLIENT_TOKEN,/^[a-f0-9]{64}$/); assert.equal(env.MEND_CLIENT_TOKEN,undefined);
 const config = readFileSync(join(root,'Local.xcconfig'),'utf8'); assert.ok(!config.includes('test-gemini-secret')); assert.ok(config.includes(env.SAVOR_CLIENT_TOKEN));
 assert.equal(statSync(join(root,'Local.xcconfig')).mode & 0o777,0o600);
 setup(server); assert.equal(parseEnv(readFileSync(join(server,'.env'),'utf8')).SAVOR_CLIENT_TOKEN,env.SAVOR_CLIENT_TOKEN);
});
