# AES in Zig

This is a Zig implementation of the [Advanced Encryption Standard (AES)](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf).

The objective of this project is to analyze the concurrent capabilities of Zig, under various workloads, and to compare the performance between different languages.

## Requirements

- [Docker](https://www.docker.com/)
- [Zig version 0.11.0](https://ziglang.org/download/) if you want to run it locally

## Usage

### Setup

Creates needed directories

```bash
make setup
```

### Build

Builds the image with the binary:
```bash
make build
```

### Deploy

Deploys the app along with the metrics framework

```bash
make deploy
```