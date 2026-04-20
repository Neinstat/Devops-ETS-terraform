FROM node:22-alpine

WORKDIR /app

COPY package.json .
RUN npm install --omit=dev

COPY index.js .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000

CMD ["node", "index.js"]