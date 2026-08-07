import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

let cachedRoot: string | undefined;

function isPackaged(): boolean {
  return typeof process !== "undefined" && "pkg" in process && Boolean((process as { pkg?: unknown }).pkg);
}

export function resolveAssetRoot(): string {
  if (cachedRoot !== undefined) return cachedRoot;

  const override = process.env.ESTACODA_ASSET_ROOT;
  if (override && override.length > 0) {
    cachedRoot = override;
    return cachedRoot;
  }

  if (isPackaged()) {
    cachedRoot = dirname(process.execPath);
    return cachedRoot;
  }

  cachedRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
  return cachedRoot;
}

export function __resetAssetRootCacheForTest(): void {
  cachedRoot = undefined;
}