FROM node:22-bookworm-slim

WORKDIR /app

COPY server/package*.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY server/src ./src
COPY server/schema.sql ./schema.sql

RUN mkdir -p /data/media

ENV NODE_ENV=production

EXPOSE 3000

CMD ["node", "src/server.js"]
