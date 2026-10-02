FROM debian:bookworm-slim
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
       coturn iproute2 iputils-ping netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*
CMD ["sleep", "infinity"]
