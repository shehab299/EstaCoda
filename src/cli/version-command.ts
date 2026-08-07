import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { resolveAssetRoot } from "../utils/asset-resolver.js";

export async function getPackageVersion(): Promise<string> {
  try {
    const packagePath = join(resolveAssetRoot(), "package.json");
    const raw = await readFile(packagePath, "utf8");
    const parsed = JSON.parse(raw) as { version?: string };
    return parsed.version ?? "unknown";
  } catch {
    return "unknown";
  }
}

export async function runVersionCommand(): Promise<{ exitCode: number; output: string }> {
  const version = await getPackageVersion();
  return {
    exitCode: 0,
    output: `estacoda ${version}`
  };
}
