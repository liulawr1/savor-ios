import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { parseEnv } from 'node:util';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

export function setup(directory, importEnv) {
    const envPath = resolve(directory, '.env');
    if (!existsSync(envPath)) {
        const source = importEnv ? parseEnv(readFileSync(importEnv, 'utf8')) : {};
        const key = source.GEMINI_API_KEY || '';
        if (/[\r\n]/.test(key)) throw new Error('The imported Gemini key must be a single line.');
        writeFileSync(envPath, `GEMINI_API_KEY=${key}\nGEMINI_MODEL=gemini-3.6-flash\nSAVOR_CLIENT_TOKEN=${randomBytes(32).toString('hex')}\nHOST=127.0.0.1\nPORT=8788\nSAVOR_REQUESTS_PER_HOUR=20\nSAVOR_APP_URL=http://localhost:8788\n`, { flag: 'wx', mode: 0o600 });
    }
    const env = parseEnv(readFileSync(envPath, 'utf8'));
    if (!/^[a-f0-9]{64}$/.test(env.SAVOR_CLIENT_TOKEN || '')) throw new Error('SAVOR_CLIENT_TOKEN must be a 64-character hexadecimal token.');
    const url = new URL(env.SAVOR_APP_URL || 'http://localhost:8788');
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || !['', '/'].includes(url.pathname) || !/^[a-zA-Z0-9.:-]+$/.test(url.host)) throw new Error('Check SAVOR_APP_URL in .env.');
    const config = `// Local development pairing only. Never commit this file.\nSAVOR_SERVER_URL = ${url.origin.replace('://', ':/$()/')}\nSAVOR_CLIENT_TOKEN = ${env.SAVOR_CLIENT_TOKEN}\n`;
    writeFileSync(resolve(directory, '../Local.xcconfig'), config, { mode: 0o600 });
    chmodSync(envPath, 0o600); chmodSync(resolve(directory, '../Local.xcconfig'), 0o600);
    return { keyConfigured: Boolean(env.GEMINI_API_KEY) };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    try {
        const i = process.argv.indexOf('--import-env');
        const status = setup(fileURLToPath(new URL('.', import.meta.url)), i >= 0 ? resolve(process.argv[i+1]) : undefined);
        console.log(status.keyConfigured ? 'Gemini key is configured. Development pairing is ready.' : 'Add GEMINI_API_KEY to server/.env locally. Development pairing is ready.');
        console.log('Run npm start, then open Savor.xcodeproj and press Command-R. No app settings to enter.');
    } catch (error) { console.error('Setup failed. Check the local .env settings and file permissions.'); process.exitCode = 1; }
}
