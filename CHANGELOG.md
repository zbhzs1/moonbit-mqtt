# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-04

### Added
- Initial MQTT 3.1.1 client implementation
- Connection management (CONNECT/DISCONNECT)
- Message publishing with QoS 0 support
- Topic subscription and unsubscription
- Username/password authentication
- Keep-alive heartbeat mechanism
- Message encoding and decoding for MQTT packets
- Comprehensive unit test suite
- CI/CD workflow with GitHub Actions
- Complete README documentation

### Technical Details
- Pure MoonBit implementation with no external dependencies
- Type-safe API using MoonBit's strong type system
- Support for WebAssembly (wasm-gc) target
- Full test coverage for core functionality

## [Unreleased]

### Planned
- QoS 1 and QoS 2 support
- Message receiving and callback mechanism
- Last Will and Testament support
- WebSocket transport layer
- TLS/SSL encrypted connections
- Persistent session support
