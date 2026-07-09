# Development Report

## Project Scope

This project is an MQTT 3.1.1 packet codec for MoonBit. It implements byte-level packet encoding and decoding helpers that can be reused by a future MQTT client, broker, test tool, or teaching example.

Runtime features such as network transport, MQTT client state, broker sessions, TLS, MQTT 5.0, and QoS retransmission state machines are outside the current packet-codec scope and can be developed as separate higher-level extensions.

## Implemented Capabilities

| Area | Implementation |
| --- | --- |
| Basic codecs | `encode_remaining_length`, `decode_remaining_length`, `encode_string`, `decode_string`, `encode_binary`, `decode_binary` |
| Fixed header | `decode_fixed_header` plus per-packet type/flag/length checks |
| Packet framing | `packet_total_length`, `has_complete_packet` |
| Generic packet dispatch | `encode_packet`, `decode_packet`, and `Packet` |
| Connection packets | `encode_connect`, `decode_connect`, `encode_connack`, `decode_connack` |
| Publish packets | `encode_publish`, `decode_publish` for QoS 0/1/2 packet layout |
| QoS acknowledgement packets | `encode_puback`, `decode_puback`, `encode_pubrec`, `decode_pubrec`, `encode_pubrel`, `decode_pubrel`, `encode_pubcomp`, `decode_pubcomp` |
| Subscribe packets | `encode_subscribe`, `decode_subscribe`, `encode_suback`, `decode_suback` |
| Unsubscribe packets | `encode_unsubscribe`, `decode_unsubscribe`, `encode_unsuback`, `decode_unsuback` |
| Empty control packets | `encode_pingreq`, `decode_pingreq`, `encode_pingresp`, `decode_pingresp`, `encode_disconnect`, `decode_disconnect` |

## Validation

Local verification commands:

```bash
moon fmt
moon info
moon check
moon test
```

Current test result: 20 tests passing.

The tests cover byte-level packet examples, UTF-8 decoding, binary payload preservation, packet framing helpers, generic packet encoding/decoding, CONNECT round trip with optional fields, CONNACK return code validation, PUBLISH QoS 0/1/2 packet layouts, QoS acknowledgement packet helpers, SUBSCRIBE and UNSUBSCRIBE packet bodies, SUBACK and UNSUBACK helpers, empty control packets, invalid fixed-header flags, and trailing-byte detection.

## Scope Boundaries

- Network transport: no TCP, WebSocket, TLS, or socket APIs.
- Client runtime: no connection manager, reconnect loop, heartbeat scheduler, or subscription callback system.
- Broker and session semantics: no broker runtime, session persistence, retained-message store, or will-message delivery semantics.
- QoS runtime state: no resend queue, acknowledgement queue, state machine, or duplicate-delivery handling.
- MQTT 5.0: no MQTT 5.0 properties, reason codes, or extended control packets.

## Consistency Notes

The README and `moon.mod` description are intentionally scoped to packet codec helpers. They should not be changed to claim MQTT client behavior unless real network I/O, session behavior, and corresponding tests are added.
