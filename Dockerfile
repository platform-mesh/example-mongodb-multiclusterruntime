# syntax=docker/dockerfile:1

# Build the binary
FROM --platform=${BUILDPLATFORM} docker.io/golang:1.25.4 AS builder

WORKDIR /workspace
RUN mkdir -p /workspace/bin

# Run this with docker build --build-arg goproxy=$(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the sources
COPY ./ ./

ARG TARGETOS
ARG TARGETARCH

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -o /workspace/bin/example-mongodb-multiclusterruntime main.go

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:debug

WORKDIR /
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /workspace/bin/example-mongodb-multiclusterruntime /example-mongodb-multiclusterruntime
USER 65532:65532

ENTRYPOINT ["/example-mongodb-multiclusterruntime"]
