FROM node:22-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src ./src
RUN mkdir -p /data/media
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/server.js"]
