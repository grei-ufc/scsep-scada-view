# Ponte (gateway Modbus) como serviço. O ponte-service.cjs é gerado por: npm run docker:build -w @scada/bridge
FROM node:22-slim
WORKDIR /app
COPY ponte-service.cjs ./
RUN mkdir -p /data && chown node:node /data
ENV DADOS_DIR=/data
USER node
VOLUME /data
CMD ["node", "ponte-service.cjs"]
