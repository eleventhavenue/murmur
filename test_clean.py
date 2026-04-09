import re

def clean_text(text):
    text = re.sub(r'#{1,6}\s*', '', text)
    text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
    text = re.sub(r'`{1,3}[^`]*`{1,3}', '', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    text = text.replace('→', ', ')
    text = text.replace('←', ', ')
    text = text.replace('—', ', ')
    text = text.replace('–', ', ')
    text = text.replace('•', ', ')
    text = text.replace('|', ', ')
    text = text.replace('·', ' ')
    text = re.sub(r'^\s*[-*+]\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\n+', '. ', text)
    text = re.sub(r'\s{2,}', ' ', text)
    # Also clean common mojibake from clipboard
    text = text.replace('â€"', ', ')  # em dash mojibake
    text = text.replace('â€™', "'")   # curly quote mojibake
    text = text.replace('â€œ', '"')   # left double quote mojibake
    text = text.replace('â€\x9d', '"')  # right double quote mojibake
    text = text.replace('Â', '')       # common encoding artifact
    return text.strip()

test_texts = [
    'Three fixes applied: → auto-play, — text cleaning, • better splitting',
    '**Bold text** and `code` with #headings',
    'The price is $8/mo — that\'s 81% margin',
    'â€" this is a common encoding issue â€™ with curly quotes',
    'Three fixes applied:\n\n1. **Auto-play on new text** — selecting new text',
    'Bug 3: Reading code/markdown symbols — The clipboard is capturing raw markdown',
]

for t in test_texts:
    print(f'INPUT:  {repr(t)}')
    print(f'CLEAN:  {repr(clean_text(t))}')
    print()
