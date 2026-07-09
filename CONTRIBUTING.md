# Contributing

Thank you for helping improve this MoonBit MQTT packet codec.

Before submitting a change, please run:

```bash
moon fmt
moon check
moon test
```

Scope rules:

- Keep this package focused on MQTT 3.1.1 byte-level packet encoding and decoding.
- Do not add network behavior or client APIs that return success without real I/O.
- If a feature is only partially implemented, document the exact supported subset and add tests for it.
- Update README tables and tests together when public behavior changes.

Development notes:

- `moon info` updates `pkg.generated.mbti`, the generated public interface.
- Decoders in this package expect one already-buffered MQTT packet in the input array. Stream framing belongs in a separate higher-level layer.
