# otel-collector-edge

A minimal, custom-built OpenTelemetry Collector binary for edge observability,
built with the [OpenTelemetry Collector Builder (OCB)](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder).

**Why a custom build?**
`otelcol-contrib` ships every component Anthropic has ever merged — the Docker
image weighs ~250 MB. This distribution includes only the components required
for the edge node, producing an image of ~30 MB.

> Part of the [observability-on-edge](https://github.com/graz-dev/observability-on-edge)
> demo. The collector runs as a Kubernetes DaemonSet on an edge node and exports
> telemetry to Jaeger, Prometheus, and Loki on a separate hub node.

---

## Included components

| Type      | Component                          | Purpose                                               |
|-----------|------------------------------------|-------------------------------------------------------|
| Receiver  | `otlpreceiver`                     | Accept traces/metrics/logs via OTLP gRPC and HTTP     |
| Processor | `batchprocessor`                   | Batch telemetry before export (5 s / 512 items)       |
| Processor | `memorylimiterprocessor`           | Prevent OOM on constrained edge hardware              |
| Processor | `tailsamplingprocessor`            | Tail-based trace sampling with 5 s decision window    |
| Processor | `resourceprocessor`                | Attach/override resource attributes                   |
| Exporter  | `otlpexporter`                     | Ship traces to Jaeger via OTLP gRPC                   |
| Exporter  | `lokiexporter`                     | Push logs to Loki                                     |
| Exporter  | `prometheusremotewriteexporter`    | Remote-write metrics to Prometheus                    |
| Extension | `filestorage`                      | bbolt-backed persistent queue for traces and logs     |
| Extension | `healthcheckextension`             | `/` health endpoint on port 13133                     |
| Extension | `zpagesextension`                  | Live debug pages on port 1777                         |

---

## Build locally

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag otelcol-edge:local \
  .
```

For a single-platform build (faster iteration):

```bash
docker build --tag otelcol-edge:local .
```

---

## Consume the image

Pull from the GitHub Container Registry:

```bash
docker pull ghcr.io/graz-dev/otel-collector-edge:latest
```

Example Kubernetes DaemonSet snippet:

```yaml
containers:
  - name: otel-collector
    image: ghcr.io/graz-dev/otel-collector-edge:1.0.0
    args: ["--config=/conf/otelcol.yaml"]
    ports:
      - containerPort: 4317   # OTLP gRPC
      - containerPort: 4318   # OTLP HTTP
      - containerPort: 8888   # Prometheus metrics (self)
      - containerPort: 13133  # Health check
      - containerPort: 1777   # zPages
```

---

## Update the collector version

1. Change `otelcol_version` in `otelcol-builder.yaml`.
2. Update the `@v<version>` pins for every component in the same file.
3. Update the `go install ...@v<version>` line in the `Dockerfile`.
4. Commit, then push a semver tag to trigger a versioned image build:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The CI workflow publishes `ghcr.io/graz-dev/otel-collector-edge:1.1.0` and
`ghcr.io/graz-dev/otel-collector-edge:1.1` automatically.

---

## CI / published tags

| Trigger              | Tags produced                              |
|----------------------|--------------------------------------------|
| Push to `main`       | `:main`, `:sha-<short>`                    |
| Push `v*.*.*` tag    | `:<version>`, `:<major>.<minor>`, `:sha-<short>` |
| Pull request to main | Build only — no image pushed               |

Images are published to `ghcr.io` using `GITHUB_TOKEN`; no external secrets
needed.
