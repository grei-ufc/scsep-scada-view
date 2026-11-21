# vpn-local (gateway Modbus) como serviço. Antes se chamava "Ponte": a build do repositório do app (npm run docker:build -w @scada/bridge) ainda gera ponte-service.cjs; renomeie para vpn-local-service.cjs ao copiar.
FROM node:22-slim
WORKDIR /app
COPY vpn-local-service.cjs ./
RUN mkdir -p /data && chown node:node /data
ENV DADOS_DIR=/data
USER node
VOLUME /data
CMD ["node", "vpn-local-service.cjs"]
