FROM swift:6.0-bookworm AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources/ Sources/
COPY Tests/ Tests/
RUN swift build -c release --static-swift-stdlib

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends chromium ca-certificates && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.build/release/remark /usr/local/bin/remark
ENTRYPOINT ["remark"]
