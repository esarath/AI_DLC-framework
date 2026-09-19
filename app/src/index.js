'use strict';

const http = require('http');

const PORT = process.env.PORT || 8080;
const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';
const VERSION = process.env.APP_VERSION || '0.0.0-dev';

const startedAt = Date.now();
let requestCount = 0;

const server = http.createServer((req, res) => {
  requestCount += 1;

  // Prometheus text exposition format — scraped by Azure Managed Prometheus
  // (pod annotations prometheus.io/* in k8s/base/deployment.yaml)
  if (req.url === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4; charset=utf-8' });
    res.end([
      '# HELP http_requests_total Total HTTP requests served',
      '# TYPE http_requests_total counter',
      `http_requests_total{app="webapp",env="${ENVIRONMENT}"} ${requestCount}`,
      '# HELP app_uptime_seconds Seconds since process start',
      '# TYPE app_uptime_seconds gauge',
      `app_uptime_seconds{app="webapp",env="${ENVIRONMENT}"} ${Math.floor((Date.now() - startedAt) / 1000)}`,
      '',
    ].join('\n'));
    return;
  }

  if (req.url === '/healthz' || req.url === '/readyz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', env: ENVIRONMENT, version: VERSION }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`<!doctype html>
<html>
  <head><title>Sample WebApp</title></head>
  <body style="font-family:sans-serif;text-align:center;margin-top:4rem">
    <h1>Sample WebApp</h1>
    <p>Environment: <strong>${ENVIRONMENT}</strong> &middot; Version: <strong>${VERSION}</strong></p>
    <p>Deployed to AKS via GitOps (ArgoCD), delivered with the<br/>
       AI-Driven Development Life Cycle (AI-DLC) methodology</p>
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
