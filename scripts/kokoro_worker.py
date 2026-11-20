#!/usr/bin/env python3
"""
Persistent in-memory Kokoro v1.0 ONNX TTS worker for Oh! Gnomes.
Runs on Apple Silicon M4 CPU NEON (CPUExecutionProvider) with zero disk roundtrips.

Protocol:
  - stdin:  One JSON object per line: {"text": "...", "voice": "bm_george", "speed": 1.08}
  - stdout: Binary frame per request:
              [uint32 LE sample_rate][uint32 LE byte_length][float32 LE PCM bytes...]
            (sample_rate == 0 and byte_length == 0 indicates synthesis error)
  - stderr: Human-readable status ("READY" once model is warm).
"""

import json
import os
import struct
import sys
import numpy as np
import onnxruntime as ort
from kokoro_onnx import Kokoro


def main() -> None:
    model_dir = os.environ.get(
        "OH_GNOMES_KOKORO_DIR",
        os.path.expanduser("~/.zen/models/kokoro"),
    )
    model_path = os.path.join(model_dir, "kokoro-v1.0.onnx")
    voices_path = os.path.join(model_dir, "voices-v1.0.bin")

    if not os.path.exists(model_path) or not os.path.exists(voices_path):
        sys.stderr.write(f"ERROR: Kokoro model files not found in {model_dir}\n")
        sys.stderr.flush()
        sys.exit(1)

    # Explicitly pin to CPUExecutionProvider (Apple Silicon M4 NEON SIMD)
    os.environ["ONNX_PROVIDER"] = "CPUExecutionProvider"
    sess_opts = ort.SessionOptions()
    sess_opts.intra_op_num_threads = max(1, min(6, (os.cpu_count() or 4)))
    sess = ort.InferenceSession(model_path, sess_options=sess_opts, providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(sess, voices_path)

    sys.stderr.write("READY\n")
    sys.stderr.flush()

    out = sys.stdout.buffer
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            text = str(req.get("text", "")).strip()
            voice = str(req.get("voice", "bm_george"))
            speed = float(req.get("speed", 1.05))
            lang = str(req.get("lang", "en-gb"))

            if not text:
                out.write(struct.pack("<II", 24000, 0))
                out.flush()
                continue

            samples, sr = kokoro.create(text, voice=voice, speed=speed, lang=lang)
            pcm = np.asarray(samples, dtype="<f4").tobytes()
            out.write(struct.pack("<II", int(sr), len(pcm)))
            out.write(pcm)
            out.flush()
        except Exception as exc:
            sys.stderr.write(f"SYNTH_ERROR: {exc}\n")
            sys.stderr.flush()
            out.write(struct.pack("<II", 0, 0))
            out.flush()


if __name__ == "__main__":
    main()
