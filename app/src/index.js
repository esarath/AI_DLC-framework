'use strict';

const http = require('http');

const PORT = process.env.PORT || 8080;
const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';
const VERSION = process.env.APP_VERSION || '0.0.0-dev';

const server = http.createServer((req, res) => {
  if (req.url === '/healthz' || req.url === '/readyz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', env: ENVIRONMENT, version: VERSION }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`<!doctype html>
<html>
  <head><title>AI-DLC WebApp</title></head>
  <body style="font-family:sans-serif;text-align:center;margin-top:4rem">
    <h1>AI-DLC Framework</h1>
    <p>Environment: <strong>${ENVIRONMENT}</strong> &middot; Version: <strong>${VERSION}</strong></p>
    <p>Served from AKS via GitOps (ArgoCD)</p>
  </body>
</html>`);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, () => {
  console.log(`ai-dlc-webapp listening on :${PORT} (env=${ENVIRONMENT}, version=${VERSION})`);
});

module.exports = server;
