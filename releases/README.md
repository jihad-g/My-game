# Shardlands builds

| File | Version | Platform |
|---|---|---|
| [Shardlands-v0.25.1-windows.zip](Shardlands-v0.25.1-windows.zip) | 0.25.1 (Smoother running; world colour pass: richer colours, chunky blocks, soft tree fade) | Windows 10/11, 64-bit |

Older builds are in the git history of this folder (v0.25.0: commit 31df5a1, v0.24.0: commit 9eaed18, v0.23.1: commit 311413e, v0.23.0: commit d91a552, v0.22.0: commit 537925d, v0.21.0: commit d113f78, v0.20.0: commit 520386f, v0.19.0: commit 8ea33dd, v0.18.0: commit 4bc7d38, v0.17.1: commit 0042754, v0.16.0: commit 482c0c8, v0.13.0: commit d8a28b4, v0.12.0: commit 6a42fc1).

## Install on Windows

1. Click the zip above, then **Download raw file** (the download icon at the top right).
2. Right-click the downloaded zip → **Extract All...** → Extract.
3. Open the extracted `windows` folder and double-click **Shardlands.exe**.
4. If Windows says "Windows protected your PC": **More info** → **Run anyway**
   (the game is not code-signed yet).

Needs a graphics card with Vulkan support. Saves are kept in
`%APPDATA%\Godot\app_userdata\Shardlands\worlds` (with automatic backups - see *Recover* in the menu).

## Build it yourself

See [docs/RELEASE.md](../docs/RELEASE.md): `python3 tools/fetch_export_templates.py windows linux web`
then `tools/build_release.sh`.
