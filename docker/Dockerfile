FROM ubuntu:latest AS build

ARG ZIG_VERSION=0.11.0

ARG ZIG_URL=https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz
# Download Zig

RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L ${ZIG_URL} -o zig-linux-x86_64-${ZIG_VERSION}.tar.xz \
    && tar -xf zig-linux-x86_64-${ZIG_VERSION}.tar.xz

# RUN mv /zig-linux-x86_64-${ZIG_VERSION}/zig /usr/local/bin
# RUN mv /zig-linux-x86_64-${ZIG_VERSION}/lib /usr/local/lib

WORKDIR /opt/app

COPY src src
COPY build.zig .

RUN /zig-linux-x86_64-${ZIG_VERSION}/zig build -Doptimize=ReleaseFast

FROM alpine:latest

WORKDIR /opt/app

COPY --from=build /opt/app/zig-out/bin/aes .

CMD ["./aes"]