# macMule

<img width="1728" height="1117" alt="Screenshot 2026-02-14 at 21 16 58" src="https://github.com/user-attachments/assets/fecd35db-88db-461e-85eb-5e50ad17dc47" />

**Original eMule for macOS — download, drag to Applications, run.**

macMule packages [eMule](https://github.com/irwir/eMule) (the ed2k/Kad file-sharing client) as a self-contained macOS `.app` using Wine. No configuration needed — it auto-connects to the eMule Security server and the Kad network on first launch.

## Download

Grab the latest `.dmg` from [**Releases**](../../releases), open it, drag **macMule** to your Applications folder, and launch.

## Requirements

- macOS 10.15.4 (Catalina) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Rosetta 2 (automatically prompted on Apple Silicon)
- ~1 GB disk space

## How It Works

macMule bundles:
- **eMule** (community x64 build by [irwir](https://github.com/irwir/eMule))
- **Wine Crossover** (x86_64 Windows compatibility layer by [Gcenx](https://github.com/Gcenx))

On first launch, it copies a Wine prefix and eMule files to `~/Library/Application Support/macMule/`. Your downloads go to `~/Library/Application Support/macMule/drive_c/eMule/Incoming/`.

## Building from Source

Prerequisites:
- [Wine Crossover](https://github.com/Gcenx/wine-crossover): `brew install --cask gcenx/wine/wine-crossover`
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`
- GitHub CLI: `brew install gh`

Then:

```bash
git clone https://github.com/mderouet/macMule.git
cd macMule
./build.sh            # builds latest stable release
./build.sh 0.70b      # builds a specific version
./build.sh 0.72a      # also works for pre-releases
```

This produces `build/macMule-v<version>.dmg`.

## License

- **eMule**: [GPL v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
- **Wine**: [LGPL 2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)

## Credits

- [irwir/eMule](https://github.com/irwir/eMule) — eMule community build
- [Wine](https://www.winehq.org/) / [Gcenx](https://github.com/Gcenx) — Wine Crossover for macOS
- [eMule Security](https://www.emule-security.org/) — Server list and Kad nodes
