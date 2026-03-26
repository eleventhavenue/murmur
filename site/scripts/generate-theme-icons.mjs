import { GoogleGenAI } from '@google/genai';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..');
const OUTPUT_DIR = path.join(PROJECT_ROOT, 'public', 'theme-icons');

const API_KEY = process.env.GEMINI_API_KEY || 'AIzaSyAqabdqSnYuDGv14eFVlsZu_ivo4Gb9MWo';
const MODEL = 'gemini-3-pro-image-preview';

const ai = new GoogleGenAI({ apiKey: API_KEY });

const BRAND_STYLE = `
You are creating small, iconic, beautiful toggle button icons for a premium text-to-speech app called Murmur.
Each icon represents a different visual theme/design direction.
Style: minimal, elegant, highly detailed miniature illustrations.
Size: These will be displayed at 32x32px to 48x48px, so they must be simple and readable at small sizes.
Background: Solid white (#FFFFFF) background — will be removed in post-processing.
NO text, NO words, NO letters in the icons.
Each icon should be a single, centered object/symbol.
Style reference: like premium app icons or Notion-style emoji — clean, modern, slightly whimsical.
`.trim();

const ASSETS = {
  'kinetic': {
    prompt: 'A minimal black audio waveform / equalizer bar icon. 5 vertical bars of different heights arranged like a sound waveform. Pure black (#1C1C1A) on white background. Geometric, sharp edges, modern. Like a music player equalizer icon.',
  },
  'serif': {
    prompt: 'A single elegant dark green (#1f3a33) quill pen / calligraphy nib with a small golden (#dcd444) ink drop at the tip. Minimal, editorial, like a luxury magazine masthead icon. On white background.',
  },
  'lilac': {
    prompt: 'A single beautiful lavender/lilac flower bloom, soft purple (#9B8EC4) petals with a lighter center (#C4B8E8). Minimal, delicate, botanical illustration style. Like a small pressed flower. On white background.',
  },
  'editorial': {
    prompt: 'A folded newspaper or magazine corner, dark green (#1f3a33) with a yellow (#dcd444) accent stripe. Minimal, like a broadsheet newspaper folded in quarters. Editorial, sophisticated. On white background.',
  },
  'italic': {
    prompt: 'A single italic forward slash or oblique stroke in dark green (#1f3a33), elegant and calligraphic, with a small dot or flourish. Like the italic marker from a typographer. Minimal, refined. On white background.',
  },
};

async function generateIcon(name, def) {
  console.log(`Generating: ${name}...`);

  const response = await ai.models.generateContent({
    model: MODEL,
    contents: `${BRAND_STYLE}\n\nASSET TO CREATE:\n${def.prompt}`,
    config: { responseModalities: ['TEXT', 'IMAGE'] },
  });

  const parts = response.candidates?.[0]?.content?.parts || [];
  for (const part of parts) {
    if (part.inlineData?.data) {
      const buffer = Buffer.from(part.inlineData.data, 'base64');
      const rawPath = path.join(OUTPUT_DIR, `${name}-raw.png`);
      await fs.writeFile(rawPath, buffer);
      console.log(`  Saved: ${rawPath}`);

      // Process with Sharp — remove white background + resize
      const sharp = (await import('sharp')).default;
      const image = sharp(buffer);
      const { data, info } = await image
        .ensureAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });

      const processed = Buffer.from(data);
      // Remove white background
      for (let i = 0; i < processed.length; i += 4) {
        const r = processed[i], g = processed[i + 1], b = processed[i + 2];
        // If pixel is close to white, make transparent
        if (r > 230 && g > 230 && b > 230) {
          processed[i + 3] = 0;
        }
      }

      // Save transparent version
      const transparentPath = path.join(OUTPUT_DIR, `${name}.png`);
      await sharp(processed, {
        raw: { width: info.width, height: info.height, channels: 4 },
      })
        .png()
        .toFile(transparentPath);
      console.log(`  Transparent: ${transparentPath}`);

      // Save 48px version for UI
      const smallPath = path.join(OUTPUT_DIR, `${name}-sm.png`);
      await sharp(processed, {
        raw: { width: info.width, height: info.height, channels: 4 },
      })
        .resize(48, 48, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
        .png()
        .toFile(smallPath);
      console.log(`  Small: ${smallPath}`);

      return true;
    }
  }
  console.log(`  WARNING: No image in response for ${name}`);
  return false;
}

async function main() {
  await fs.mkdir(OUTPUT_DIR, { recursive: true });

  const targetIcons = process.argv.includes('--icons')
    ? process.argv[process.argv.indexOf('--icons') + 1].split(',')
    : Object.keys(ASSETS);

  for (const name of targetIcons) {
    if (!ASSETS[name]) {
      console.log(`Unknown icon: ${name}, skipping`);
      continue;
    }
    await generateIcon(name, ASSETS[name]);
    // Rate limit
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log('\nDone! Icons saved to:', OUTPUT_DIR);
}

main().catch(console.error);
