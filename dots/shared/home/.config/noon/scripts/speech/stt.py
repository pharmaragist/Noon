#!/usr/bin/env python3
import argparse
import csv
import fcntl
import json
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

LOCK_FILE = Path("/tmp/speech_stt.lock")
CHUNK_SECONDS = 3
OVERLAP_SECONDS = 0.5


def _lock_pid(fd):
    try:
        os.lseek(fd, 0, os.SEEK_SET)
        return int(os.read(fd, 64).strip() or 0)
    except Exception:
        return 0


def _pid_alive(pid):
    if not pid or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def _acquire_lock(fd):
    
    
    
    deadline = time.monotonic() + 3.0
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            holder = _lock_pid(fd)
            if _pid_alive(holder):
                try:
                    os.kill(holder, signal.SIGTERM)
                    print(f"stopping previous STT (pid {holder})", file=sys.stderr)
                except OSError:
                    pass
            if time.monotonic() >= deadline:
                return False
            time.sleep(0.2)


def run_stt(config_path=None):
    lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o644)
    if not _acquire_lock(lock_fd):
        os.close(lock_fd)
        print("STT already running", file=sys.stderr)
        sys.exit(1)
    os.ftruncate(lock_fd, 0)
    os.lseek(lock_fd, 0, os.SEEK_SET)
    os.write(lock_fd, f"{os.getpid()}\n".encode())

    try:
        config = {}
        if config_path:
            config = json.loads(Path(config_path).read_text())

        result = subprocess.run(
            ["pactl", "get-source-mute", "@DEFAULT_SOURCE@"],
            capture_output=True, text=True, timeout=3
        )
        if "Mute: yes" in result.stdout:
            print("Microphone is muted — unmute to start STT", file=sys.stderr)
            return

        import sounddevice as sd

        model_name = config.get("whisper_model", "base")
        device = config.get("device") or None
        sample_rate = 16000
        chunk_samples = int(CHUNK_SECONDS * sample_rate)
        overlap_samples = int(OVERLAP_SECONDS * sample_rate)

        all_chunks = []
        window_chunks = []
        lock = threading.Lock()
        stop_event = threading.Event()
        last_printed = ""

        cache = Path.home() / ".cache/huggingface/hub"
        model_cached = (
            any(model_name in str(p) for p in cache.glob("**/config.json"))
            if cache.exists()
            else False
        )
        if not model_cached:
            print(f"Downloading model '{model_name}'...", file=sys.stderr)

        
        
        model_holder = {}
        model_ready = threading.Event()

        def load_model():
            try:
                from faster_whisper import WhisperModel
                model_holder["model"] = WhisperModel(
                    model_name, device="cpu", compute_type="int8"
                )
                if not model_cached:
                    print("Download complete.", file=sys.stderr)
            except Exception as e:
                model_holder["error"] = e
            finally:
                model_ready.set()

        threading.Thread(target=load_model, daemon=True).start()

        signal.signal(signal.SIGTERM, lambda *_: stop_event.set())
        signal.signal(signal.SIGINT, lambda *_: stop_event.set())

        def callback(indata, frames, time, status):
            with lock:
                all_chunks.append(indata.copy())
                window_chunks.append(indata.copy())

        def transcribe(audio_window):
            nonlocal last_printed
            if len(audio_window) < sample_rate * 0.5:
                return
            model_ready.wait()
            if "error" in model_holder:
                raise model_holder["error"]
            model = model_holder["model"]
            segments, _ = model.transcribe(
                audio_window,
                language=config.get("language"),
                beam_size=1,
                best_of=1,
                vad_filter=True,
            )
            text = " ".join(s.text.strip() for s in segments).strip()
            if text and text != last_printed:
                csv.writer(sys.stdout).writerow(["stt", text])
                sys.stdout.flush()
                last_printed = text

        def transcribe_loop():
            import numpy as np
            while True:
                with lock:
                    total = sum(c.shape[0] for c in window_chunks)
                if total < chunk_samples:
                    if stop_event.is_set():
                        break
                    threading.Event().wait(0.5)
                    continue
                with lock:
                    audio_window = np.concatenate(window_chunks).flatten()
                    kept_samples = min(overlap_samples, len(audio_window))
                    kept = audio_window[-kept_samples:]
                    window_chunks.clear()
                    window_chunks.append(kept.reshape(-1, 1))
                transcribe(audio_window)
            with lock:
                if window_chunks:
                    audio_window = np.concatenate(window_chunks).flatten()
                    window_chunks.clear()
                else:
                    audio_window = None
            if audio_window is not None:
                transcribe(audio_window)

        t = threading.Thread(target=transcribe_loop, daemon=True)
        t.start()

        print("Recording... (Ctrl+C or SIGTERM to stop)", file=sys.stderr)
        csv.writer(sys.stdout).writerow(["state", "listening"])
        sys.stdout.flush()
        with sd.InputStream(
            samplerate=sample_rate,
            channels=1,
            dtype="float32",
            device=device,
            callback=callback,
        ):
            stop_event.wait()
        csv.writer(sys.stdout).writerow(["state", "idle"])
        sys.stdout.flush()

    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=None)
    args = parser.parse_args()
    run_stt(args.config)


if __name__ == "__main__":
    main()
