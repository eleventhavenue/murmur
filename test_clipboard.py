"""Check what's actually in the clipboard right now."""
import ctypes
import ctypes.wintypes

CF_UNICODETEXT = 13

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

user32.OpenClipboard(0)
try:
    handle = user32.GetClipboardData(CF_UNICODETEXT)
    if handle:
        kernel32.GlobalLock.restype = ctypes.c_wchar_p
        text = kernel32.GlobalLock(handle)
        if text:
            print("=== CLIPBOARD RAW ===")
            print(repr(text[:500]))
            print()
            print("=== CLIPBOARD DISPLAY ===")
            print(text[:500])
        kernel32.GlobalUnlock(handle)
    else:
        print("No text in clipboard")
finally:
    user32.CloseClipboard()
