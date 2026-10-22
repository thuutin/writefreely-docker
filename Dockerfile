FROM golang:1.25-alpine3.22 AS build

ARG WRITEFREELY_REF=v0.17.2
ARG WRITEFREELY_COMMIT=acdc6b9ea4a6b7727c211cb1dcb405a12c87fe12

RUN apk add --no-cache git make g++ nodejs npm \
    && npm install -g less less-plugin-clean-css

WORKDIR /src
RUN git clone --depth 1 --branch "${WRITEFREELY_REF}" https://github.com/writefreely/writefreely.git . \
    && test "$(git rev-parse HEAD)" = "${WRITEFREELY_COMMIT}"

ENV NODE_OPTIONS=--openssl-legacy-provider
RUN make build && make ui

FROM alpine:3.22

RUN apk add --no-cache ca-certificates openssl \
    && mkdir -p /data /usr/share/writefreely \
    && chown daemon:daemon /data

COPY --from=build /src/cmd/writefreely/writefreely /usr/local/bin/writefreely
COPY --from=build /src/templates /usr/share/writefreely/templates
COPY --from=build /src/static /usr/share/writefreely/static
COPY --from=build /src/pages /usr/share/writefreely/pages

ENV WRITEFREELY_DOCKER=1
WORKDIR /data
USER daemon
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/writefreely"]
CMD ["serve"]
