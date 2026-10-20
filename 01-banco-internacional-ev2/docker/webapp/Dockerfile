# syntax=docker/dockerfile:1

# ============================================================
# Banco Internacional - imagen de la aplicacion web
#
# Build en dos etapas: la primera instala las dependencias, la
# segunda solo copia lo necesario. La imagen final corre como
# usuario sin privilegios.
#
# Build:  docker build -t banco-internacional-web .
# ============================================================

# ---------- Etapa 1: dependencias ----------
FROM node:22-alpine AS dependencias

WORKDIR /app

# Las dependencias se copian solas para aprovechar la cache de capas:
# solo se reinstalan cuando cambia package.json.
COPY package.json ./

# Instalacion limpia, solo dependencias de produccion.
RUN npm install --omit=dev --no-audit --no-fund

# ---------- Etapa 2: imagen final ----------
FROM node:22-alpine AS final

# Etiquetas de la imagen, utiles al inspeccionarla con docker inspect.
LABEL org.opencontainers.image.title="Banco Internacional Web" \
      org.opencontainers.image.description="Aplicacion web bancaria del proyecto EV-2" \
      org.opencontainers.image.authors="vis-hoo" \
      org.opencontainers.image.version="1.0.0"

ENV NODE_ENV=production \
    PORT=8088

WORKDIR /app

# Dependencias ya instaladas, traidas desde la etapa anterior.
COPY --from=dependencias /app/node_modules ./node_modules

# Codigo de la aplicacion.
COPY package.json ./
COPY src ./src

# El usuario node viene en la imagen base; se usa para no correr como root.
RUN chown -R node:node /app
USER node

EXPOSE 8088

# Verificacion interna del contenedor.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8088/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "src/server.js"]
