import { makeServer } from './app.mjs';
import { DEFAULT_MODEL } from './ai.mjs';

try {
  const host = process.env.HOST || '127.0.0.1';
  const port = Number(process.env.PORT || 8788);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT must be a valid port number.');
  const server = makeServer({
    apiKey: process.env.GEMINI_API_KEY, clientToken: process.env.SAVOR_CLIENT_TOKEN,
    model: process.env.GEMINI_MODEL || DEFAULT_MODEL, limit: Number(process.env.SAVOR_REQUESTS_PER_HOUR || 20)
  });
  server.on('error', error => { console.error(`Could not start Savor: ${error.code || 'server error'}`); process.exitCode = 1; });
  server.listen(port, host, () => {
    console.log(`Savor API listening at http://${host}:${port}`);
    console.log(process.env.GEMINI_API_KEY ? 'Live AI is configured.' : 'Add GEMINI_API_KEY to .env and restart to enable live AI.');
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
} catch (error) {
  console.error(error.message); process.exitCode = 1;
}
