# Install EstaCoda

EstaCoda is not published as a public npm package yet. Keep install docs clear about which paths work now and which paths are planned.

## Local Developer Path

Use this inside a source checkout:

```bash
cd /path/to/EstaCoda
corepack enable
pnpm install
pnpm run build
node dist/index.js --help
node dist/index.js --version
```

For packaging regression checks:

```bash
pnpm run verify:local-bin
scripts/verify-package-bin.sh
```

`scripts/verify-package-bin.sh` builds the project, captures the tarball filename from `npm pack --json`, installs that tarball into a temporary prefix, runs the installed `estacoda` binary, and cleans up after itself.

## Local Manual Installer

Use this from a local checkout when you want an `estacoda` command on your PATH:

```bash
bash scripts/install.sh
```

The script checks Node.js >= 22.18.0 and Corepack, builds `dist/`, writes a Node-backed wrapper to `~/.estacoda/bin/estacoda`, and updates PATH where possible.

You can also run the wrapper directly from the checkout:

```bash
bash scripts/estacoda-wrapper.sh --version
```

After local manual install, restart your shell or run:

```bash
export PATH="$HOME/.estacoda/bin:$PATH"
```

## Prebuilt Binary (Recommended)

Download a prebuilt binary from GitHub Releases. No Node.js, git, or pnpm is required — the Node.js runtime is embedded.

```bash
curl -fsSL https://raw.githubusercontent.com/sifr01-labs/EstaCoda/main/scripts/install-binary.sh | bash
```

The installer detects your platform, downloads the correct binary, extracts it to `~/.estacoda/bin/`, and adds a wrapper symlink to `~/.local/bin/`. Restart your shell or run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Options:

```bash
bash scripts/install-binary.sh --version v0.1.0    # Install a specific release
bash scripts/install-binary.sh --dir /opt/estacoda # Custom install directory
bash scripts/install-binary.sh --fhs               # Linux FHS: /usr/local/lib/estacoda + /usr/local/bin
```

Platforms supported: Linux x64, Linux arm64, macOS x64, macOS arm64.

The install method stamp is written to `<install-dir>/.install-method.json`. The update engine detects this stamp and routes `estacoda update` to download a new binary tarball rather than using pnpm.

### Building from source

If you want to build the binary yourself:

```bash
pnpm run build:binary          # Build for host platform
pnpm run build:binary:linux-x64  # Build for a specific target
```

Output: `dist-bin/release/<platform>/estacoda` and `dist-bin/estacoda-<platform>.tar.gz`.

## Post-Install

For any path that gives you an `estacoda` command:

```bash
estacoda                    # Start onboarding on first run; launch a session when ready
estacoda setup              # Review, edit, or repair setup
estacoda setup --interactive
estacoda verify             # Check readiness
```

Bare `estacoda` routes new users directly into the Onboarding Wizard. `estacoda setup --interactive` remains the operator surface: it opens the Setup Editor for configured or degraded setup (supporting primary provider/model, fallback route, auxiliary route, Agent Evolution, and optional capability editing), and shows repair-first diagnostics for missing credentials, broken provider routes, broken config, untrusted workspaces, and state paths that are not writable.

Onboarding Wizard users see a configuration summary, confirm it, then setup applies and verifies. The redacted manifest and apply plan still exist internally for operator inspection, but they are not the normal first screen after setup questions. First-run detection may prepare an idempotent default profile skeleton; cancelling before apply does not apply the reviewed configuration, grant workspace trust, or save collected credentials. Workspace trust is required before EstaCoda can run in that workspace; if trust is deferred, setup may be saved but launch is blocked with `Setup saved. Workspace trust is still required before EstaCoda can run here.`

`Start EstaCoda now?` appears only after successful apply and verification. If selected, setup reloads the selected profile config, reloads trust state, verifies workspace trust, rebuilds runtime from fresh config, and enters the normal interactive launcher.

Advanced/direct provider setup can reference an existing environment variable:

```bash
estacoda setup --provider deepseek --model deepseek-chat --api-key-env DEEPSEEK_API_KEY
estacoda setup --advanced --provider deepseek --model deepseek-chat --api-key-env DEEPSEEK_API_KEY
```

Direct setup flags are advanced compatibility paths. Guided repair uses reviewed setup instead.

## Update

```bash
estacoda update          # Dry-run: see what would update
estacoda update --apply  # Apply update (requires ESTACODA_UPDATE_ARTIFACT)
```

## Troubleshooting

**Node too old**: Install Node.js >= 22.18.0.

**pnpm not found**: Run `corepack enable`, then retry.

**No prebuilt binary**: The prebuilt binary is the recommended install path. If the binary is not available for your platform, use the [local developer path](#local-developer-path) or [build from source](#building-from-source).
