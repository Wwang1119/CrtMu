FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install --omit=dev

COPY src ./src
COPY README.md ./README.md
COPY BLUEPRINT.md ./BLUEPRINT.md

RUN mkdir -p /app/data /app/uploads

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000

EXPOSE 3000

CMD ["npm", "start"]
