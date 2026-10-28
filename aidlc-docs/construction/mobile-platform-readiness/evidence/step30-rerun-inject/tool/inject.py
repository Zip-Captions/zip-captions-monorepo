"""Feed QA speech into an Android emulator through gRPC injectAudio.

One injectAudio stream is opened for the whole test. The stream carries
16 kHz mono S16 audio in 20 ms packets. It streams silence until a trigger
file appears ("speech only after the recogniser is ready"), then plays a
script of WAV phrases and silences, then keeps streaming silence until the
stop file appears. A host timestamp is printed at every phrase start and end.

Usage (venv python):
  inject.py --port 8560 --trigger T --stop S SCRIPT...

SCRIPT items:
  wav:PATH               play a 16 kHz mono S16 WAV
  silence:SECONDS        silence
  repeat:N:PERIOD:PATH   N times: play the WAV, then pad silence so each
                         repetition takes PERIOD seconds

No gRPC token is used or printed (the emulator is started without
-grpc-use-jwt). MODE_UNSPECIFIED is used; this client paces itself to
real time, with at most ~200 ms of lead, so printed times are accurate to
about 0.3 s (the emulator's internal buffer is ~300 ms).
"""
import argparse
import datetime
import os
import sys
import time
import wave

import grpc

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stubs'))
import emulator_controller_pb2 as pb  # noqa: E402
import emulator_controller_pb2_grpc as pbg  # noqa: E402

RATE = 16000
PACKET_MS = 20
PACKET_BYTES = RATE * PACKET_MS // 1000 * 2
SILENCE = bytes(PACKET_BYTES)
LEAD = 0.2


def stamp():
    return datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]


def load_wav(path):
    with wave.open(path, 'rb') as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1
        assert w.getsampwidth() == 2
        data = w.readframes(w.getnframes())
    pad = (-len(data)) % PACKET_BYTES
    return data + bytes(pad)


def packets(data):
    for i in range(0, len(data), PACKET_BYTES):
        yield data[i:i + PACKET_BYTES]


def expand(script):
    """Yield ('wav', name, bytes) | ('silence', None, seconds)."""
    for item in script:
        kind, _, rest = item.partition(':')
        if kind == 'wav':
            yield ('wav', os.path.basename(rest), load_wav(rest))
        elif kind == 'silence':
            yield ('silence', None, float(rest))
        elif kind == 'repeat':
            n, period, path = rest.split(':', 2)
            data = load_wav(path)
            secs = len(data) / 2 / RATE
            for i in range(int(n)):
                yield ('wav', f'{os.path.basename(path)}#{i + 1}', data)
                yield ('silence', None, max(0.0, float(period) - secs))
        else:
            raise SystemExit(f'bad script item: {item}')


def stream(args):
    fmt = pb.AudioFormat(
        samplingRate=RATE,
        channels=pb.AudioFormat.Mono,
        format=pb.AudioFormat.AUD_FMT_S16,
        mode=pb.AudioFormat.MODE_UNSPECIFIED,
    )
    start = time.monotonic()
    sent = 0  # packets sent
    first = True

    def emit(chunk):
        nonlocal sent, first
        # Pace to real time with a small lead.
        due = start + sent * PACKET_MS / 1000 - LEAD
        delay = due - time.monotonic()
        if delay > 0:
            time.sleep(delay)
        sent += 1
        if first:
            first = False
            return pb.AudioPacket(format=fmt, audio=chunk)
        return pb.AudioPacket(audio=chunk)

    print(f'stream open {stamp()}', flush=True)
    while not os.path.exists(args.trigger):
        if os.path.exists(args.stop):
            print(f'stopped before trigger {stamp()}', flush=True)
            return
        yield emit(SILENCE)
    print(f'trigger seen {stamp()}', flush=True)
    for kind, name, payload in expand(args.script):
        if os.path.exists(args.stop):
            break
        if kind == 'wav':
            print(f'phrase {name} start {stamp()}', flush=True)
            for chunk in packets(payload):
                yield emit(chunk)
            print(f'phrase {name} end {stamp()}', flush=True)
        else:
            for _ in range(int(payload * 1000 / PACKET_MS)):
                if os.path.exists(args.stop):
                    break
                yield emit(SILENCE)
    print(f'script done, streaming silence {stamp()}', flush=True)
    while not os.path.exists(args.stop):
        yield emit(SILENCE)
    print(f'stop file seen {stamp()}', flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--port', type=int, required=True)
    p.add_argument('--trigger', required=True)
    p.add_argument('--stop', required=True)
    p.add_argument('--open-file', default=None,
                   help='do not open the gRPC stream until this file exists '
                        '(the guest microphone must be open first; opening '
                        'the stream earlier crashed the emulator)')
    p.add_argument('script', nargs='*')
    args = p.parse_args()
    if args.open_file:
        print(f'waiting for open file {stamp()}', flush=True)
        while not os.path.exists(args.open_file):
            if os.path.exists(args.stop):
                print(f'stopped before open {stamp()}', flush=True)
                return
            time.sleep(0.05)
    channel = grpc.insecure_channel(f'127.0.0.1:{args.port}')
    stub = pbg.EmulatorControllerStub(channel)
    try:
        stub.injectAudio(stream(args))
        print(f'injectAudio finished OK {stamp()}', flush=True)
    except grpc.RpcError as e:
        print(f'injectAudio ended with {e.code()} {e.details()} {stamp()}',
              flush=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
