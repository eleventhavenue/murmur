# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['C:\\Users\\12895\\tts-studio\\murmur\\sidecar\\tts_server.py'],
    pathex=[],
    binaries=[],
    datas=[('C:\\Users\\12895\\tts-studio\\murmur\\sidecar\\models\\kokoro-v1.0.onnx', 'models'), ('C:\\Users\\12895\\tts-studio\\murmur\\sidecar\\models\\voices-v1.0.bin', 'models')],
    hiddenimports=['kokoro_onnx', 'onnxruntime', 'numpy'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['torch', 'tensorflow', 'matplotlib', 'PIL', 'cv2', 'scipy', 'pandas', 'tkinter'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='murmur-tts',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='murmur-tts',
)
