# Changelog

## Unreleased

### Changed

- Re-scoped the project from an MQTT client-style API to an MQTT 3.1.1 packet codec library.
- Removed the previous `Client` API because it did not perform real network I/O.
- Updated public metadata and documentation so they no longer claim MQTT client or protocol-stack support.

### Added

- Byte-level Remaining Length, MQTT UTF-8 String, and MQTT Binary Data codecs.
- Packet framing helpers and a generic packet decoder.
- Public packet structures and helpers for CONNECT, CONNACK, PUBLISH, PUBACK, PUBREC, PUBREL, PUBCOMP, SUBSCRIBE, SUBACK, UNSUBSCRIBE, UNSUBACK, PINGREQ, PINGRESP, and DISCONNECT.
- Strict decoding checks for fixed-header type/flags, packet body length, packet identifiers, CONNACK return code, SUBACK return code, CONNECT flags, and UTF-8 string validity.
- 19 MoonBit tests covering supported packet helpers and malformed packet cases.
- Generated package interface file from `moon info`.

## 0.1.0 - 2026-07-04

### Added

- Initial repository setup.
