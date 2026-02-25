# syntax=docker/dockerfile:1

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

# git is required by OCB to resolve Go modules via VCS
RUN apk add --no-cache git

# Install OCB (OpenTelemetry Collector Builder)
RUN go install go.opentelemetry.io/collector/cmd/builder@v0.95.0

WORKDIR /build

COPY otelcol-builder.yaml .

# Cross-compile for the target platform
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    /go/bin/builder --config=otelcol-builder.yaml

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM gcr.io/distroless/base-debian12

COPY --from=builder /build/output/otelcol-edge /otelcol-edge

# OTLP gRPC | OTLP HTTP | Prometheus metrics | health-check | zPages
EXPOSE 4317 4318 8888 13133 1777

ENTRYPOINT ["/otelcol-edge"]
