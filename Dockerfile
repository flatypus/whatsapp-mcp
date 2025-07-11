FROM golang:1.24-alpine AS go-builder

RUN apk add --no-cache gcc musl-dev sqlite-dev

WORKDIR /app/whatsapp-bridge

COPY whatsapp-bridge/ .

ENV CGO_ENABLED=1

RUN go mod download
RUN go build -o whatsapp-bridge main.go

FROM ghcr.io/astral-sh/uv:alpine

RUN apk add --no-cache ffmpeg sqlite

WORKDIR /app

COPY --from=go-builder /app/whatsapp-bridge/whatsapp-bridge /app/whatsapp-bridge/

COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

RUN mkdir -p /app/whatsapp-bridge/store
RUN mkdir -p /app/data

ENV PATH="/app:$PATH"
ENV WHATSAPP_DATA_DIR="/app/data"

EXPOSE $PORT

ENTRYPOINT ["/app/docker-entrypoint.sh"]