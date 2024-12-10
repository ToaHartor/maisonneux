FROM node:22-alpine3.20

RUN apk add unzip curl 

RUN addgroup --gid 2000 asphyxia && \
    adduser --ingroup asphyxia --uid 2000 --no-create-home --disabled-password --gecos "" asphyxia

RUN mkdir -p /server/ \
    && curl -LO https://github.com/asphyxia-core/asphyxia-core.github.io/releases/download/v1.50/asphyxia-core-linux-x64.zip \
    && unzip asphyxia-core-linux-x64.zip -d /server \
    && rm asphyxia-core-linux-x64.zip

WORKDIR /server/
COPY ./docker-entrypoint.sh .
RUN chmod +x ./asphyxia-core
RUN chmod +x ./docker-entrypoint.sh

RUN chown -R 2000:2000 .

USER asphyxia

ENV ASPHYXIA_PORT 8083

HEALTHCHECK --interval=30s --timeout=10s --retries=3\
    CMD curl -sf -A "Mozilla/5.0" http://localhost:$ASPHYXIA_PORT -o /dev/null || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]