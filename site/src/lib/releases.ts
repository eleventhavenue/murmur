/**
 * Latest release lookup.
 *
 * The download buttons used to hardcode a versioned filename, which meant the
 * main call to action broke the moment a new version shipped. This resolves the
 * real asset from the GitHub releases API instead, and degrades to the releases
 * page if the API is unreachable or rate limited.
 */

import { githubRepo } from "./config";

export interface ReleaseAsset {
  name: string;
  url: string;
  size: number;
}

export interface Release {
  version: string;
  url: string;
  publishedAt: string | null;
  windows?: ReleaseAsset;
  macos?: ReleaseAsset;
  linux?: ReleaseAsset;
}

interface GitHubAsset {
  name: string;
  browser_download_url: string;
  size: number;
}

const releasesPage = `https://github.com/${githubRepo}/releases`;

/** Used when GitHub can't be reached, so the page always renders something sane. */
export const FALLBACK_RELEASE: Release = {
  version: "latest",
  url: `${releasesPage}/latest`,
  publishedAt: null,
};

function pick(assets: GitHubAsset[], test: (name: string) => boolean): ReleaseAsset | undefined {
  const match = assets.find((a) => test(a.name.toLowerCase()));
  if (!match) return undefined;
  return { name: match.name, url: match.browser_download_url, size: match.size };
}

export async function getLatestRelease(): Promise<Release> {
  try {
    const res = await fetch(`https://api.github.com/repos/${githubRepo}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
      // Re-check hourly. A new release appears on the site without a redeploy.
      next: { revalidate: 3600 },
    });

    if (!res.ok) return FALLBACK_RELEASE;

    const data = (await res.json()) as {
      tag_name?: string;
      html_url?: string;
      published_at?: string;
      assets?: GitHubAsset[];
    };

    const assets = data.assets ?? [];

    return {
      version: data.tag_name ?? "latest",
      url: data.html_url ?? `${releasesPage}/latest`,
      publishedAt: data.published_at ?? null,
      windows: pick(assets, (n) => n.endsWith(".exe")) ?? pick(assets, (n) => n.endsWith(".msi")),
      macos: pick(assets, (n) => n.endsWith(".dmg")) ?? pick(assets, (n) => n.endsWith(".app.tar.gz")),
      linux: pick(assets, (n) => n.endsWith(".appimage")) ?? pick(assets, (n) => n.endsWith(".deb")),
    };
  } catch {
    return FALLBACK_RELEASE;
  }
}

/** "383 MB" — installers here are large enough that buyers deserve a warning. */
export function formatSize(bytes: number): string {
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
  return `${Math.round(bytes / 1024 ** 2)} MB`;
}
