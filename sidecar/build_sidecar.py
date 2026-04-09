"""
Build the TTS sidecar into a standalone exe using PyInstaller.
Run from the murmur project root:
  .venv/Scripts/python.exe sidecar/build_sidecar.py
"""

import PyInstaller.__main__
import os

SIDECAR_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SIDECAR_DIR)
MODELS_DIR = os.path.join(SIDECAR_DIR, "models")

# Check model files exist
model_file = os.path.join(MODELS_DIR, "kokoro-v1.0.onnx")
voices_file = os.path.join(MODELS_DIR, "voices-v1.0.bin")

if not os.path.exists(model_file):
    print(f"ERROR: Model not found at {model_file}")
    print("Download from: https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx")
    exit(1)

if not os.path.exists(voices_file):
    print(f"ERROR: Voices not found at {voices_file}")
    print("Download from: https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin")
    exit(1)

print(f"Model: {model_file} ({os.path.getsize(model_file) / 1024 / 1024:.0f} MB)")
print(f"Voices: {voices_file} ({os.path.getsize(voices_file) / 1024 / 1024:.0f} MB)")
print("Building sidecar...")

PyInstaller.__main__.run([
    os.path.join(SIDECAR_DIR, "tts_server.py"),
    "--name=murmur-tts",
    "--onedir",  # onedir is faster to start than onefile
    "--console",  # needs stdin/stdout
    "--noconfirm",
    f"--distpath={os.path.join(PROJECT_ROOT, 'src-tauri', 'binaries')}",
    f"--workpath={os.path.join(PROJECT_ROOT, 'build', 'pyinstaller')}",
    f"--specpath={os.path.join(PROJECT_ROOT, 'build')}",
    # Bundle model files
    f"--add-data={model_file};models",
    f"--add-data={voices_file};models",
    # Hidden imports that PyInstaller misses
    "--hidden-import=kokoro_onnx",
    "--hidden-import=onnxruntime",
    "--hidden-import=numpy",
    # Exclude unnecessary packages to reduce size
    "--exclude-module=torch",
    "--exclude-module=tensorflow",
    "--exclude-module=matplotlib",
    "--exclude-module=PIL",
    "--exclude-module=cv2",
    "--exclude-module=scipy",
    "--exclude-module=pandas",
    "--exclude-module=tkinter",
])

print("\nDone! Sidecar built at: src-tauri/binaries/murmur-tts/")
