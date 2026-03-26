# Test Fixtures

Shared test data for cross-package contract tests. Both sides of a contract load the same fixture file to verify their encoder/decoder agrees on the format.

Organize by domain:

```
test-fixtures/
  stt/                    # SttResult payloads
  caption_bus/            # Caption bus event payloads
  transport/              # WebRTC signaling, Realtime payloads
  encryption/             # Encrypted blob format samples
```

See `CONTRIBUTING.md` Section 7 (Integration Testing Strategy) for details.
