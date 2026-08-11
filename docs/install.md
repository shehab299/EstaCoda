# Install EstaCoda

## Prebuilt Binary (Recommended)

Download a prebuilt binary from GitHub Releases. No Node.js, git, or pnpm is required — the Node.js runtime is embedded.

```bash
curl -fsSL https://raw.githubusercontent.com/sifr01-labs/EstaCoda/main/scripts/install.sh | bash
```

The installer detects your platform, downloads the correct binary, extracts it to `~/.estacoda/bin/`, and adds a wrapper symlink to `~/.local/bin/`. Restart your shell or run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Options:

```bash
bash scripts/install.sh --version v0.1.0    # Install a specific release
bash scripts/install.sh --dir /opt/estacoda # Custom install directory
bash scripts/install.sh --fhs               # Linux FHS: /usr/local/lib/estacoda + /usr/local/bin
```

Platforms supported: Linux x64, Linux arm64, macOS x64, macOS arm64.

### Building from source

If you want to build the binary yourself:

```bash
pnpm run build:binary          # Build for host platform
pnpm run build:binary:linux-x64  # Build for a specific target
```

Output: `dist-bin/release/<platform>/estacoda` and `dist-bin/estacoda-<platform>.tar.gz`.

## Post-Install

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

## Uninstall

```bash
bash scripts/uninstall.sh
```

Removes the binary install directory, wrapper symlinks, and PATH entries. User data (`~/.estacoda`) is preserved by default.

## Troubleshooting

**Unsupported platform**: Ensure you're on Linux (x64/arm64) or macOS (x64/arm64). Windows is not yet supported.

**Permission denied**: Try with `sudo` or use `--dir` to install to a user-writable location.

**Binary not found after install**: Add `~/.local/bin` to your PATH: `export PATH="$HOME/.local/bin:$PATH"`
