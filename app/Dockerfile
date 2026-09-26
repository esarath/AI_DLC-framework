# ---- build stage ----
FROM node:26-alpine AS deps
WORKDIR /app
COPY package.json ./
# No runtime deps today; layer kept so `npm ci --omit=dev` slots in cleanly later.

# ---- runtime stage ----
FROM node:26-alpine
ENV NODE_ENV=production
WORKDIR /app

RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/package.json ./
COPY src/ ./src/

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["node", "src/index.js"]
