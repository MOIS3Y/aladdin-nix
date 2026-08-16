# Contributing to aladdin-nix

Contributions that improve the package, documentation, or support for new
Aladdin 2FA Desktop releases are welcome. Keep the package native to Nix and
avoid an FHS compatibility environment unless upstream makes it necessary.

This guide explains how the package works, how its dependencies were found,
how to inspect a new Debian archive, and how to test an update.

## Development

The package is implemented as a normal Nix derivation. It does not use
`buildFHSEnv`, `steam-run`, or another FHS compatibility environment. The
official Debian archive is extracted and its ELF executable is patched to use
libraries directly from the Nix store.

### Development Tools

Enter the development shell:

```console
nix develop
```

It provides `nixfmt`, `statix`, and `deadnix`. Run all project checks with:

```console
nixfmt --check default.nix flake.nix
statix check .
deadnix --fail .
nix flake check
nix build --print-build-logs
```

Open a temporary shell with the tools used to inspect upstream packages:

```console
nix shell \
  nixpkgs#binutils \
  nixpkgs#dpkg \
  nixpkgs#file \
  nixpkgs#jq \
  nixpkgs#patchelf \
  nixpkgs#ripgrep
```

The tools serve the following purposes:

- `dpkg-deb` reads metadata and extracts Debian archives.
- `file` distinguishes ELF programs from application data.
- `readelf` displays dynamic ELF metadata and `DT_NEEDED` entries.
- `patchelf` displays ELF interpreters, dependencies, and RPATHs.
- `jq` reads the hash and store path produced by Nix.
- `rg` searches binaries and package data for hard-coded paths.

### Package Design

A Debian package is an archive, not a requirement to run a Debian filesystem.
The current archive contains one dynamically linked Go executable together
with its desktop entry, icons, and changelog.

During the build:

1. `dpkg-deb` extracts the archive.
2. Files from `usr` are copied into the package output.
3. `usr/sbin` is moved to `bin` to expose the executable through `PATH`.
4. The desktop entry is changed from an absolute FHS path to the command name.
5. `autoPatchelfHook` patches the ELF interpreter and library search paths.

This is preferable to an FHS environment because the dependencies remain
explicit and the resulting package runs directly from the Nix store.

## Packaging a New Release

Do not update only the version and hash. Inspect every new archive because
upstream may change its layout, desktop entry, or native dependencies.

### Find the Upstream Version

Open the official [Aladdin 2FA product page][aladdin] and follow its Linux x64
Debian download link. The link contains the complete four-part desktop version.

The current URL follows this pattern:

```text
https://www.aladdin-rd.ru/upload/downloads/aladdin-2fa/
aladdin-2fa-desktop-x64-VERSION.deb
```

Use the exact versioned URL rather than a mutable `latest` link.

### Fetch the Debian Archive

Set the new version and prefetch the source:

```console
version=NEW_VERSION
base_url="https://www.aladdin-rd.ru/upload/downloads/aladdin-2fa"
url="$base_url/aladdin-2fa-desktop-x64-$version.deb"
nix store prefetch-file "$url" --json
```

The command prints JSON containing an SRI hash and a Nix store path:

```json
{
  "hash": "sha256-...",
  "storePath": "/nix/store/...-aladdin-2fa-desktop-x64-VERSION.deb"
}
```

Store the path in a variable for the following inspection steps:

```console
deb=$(nix store prefetch-file "$url" --json | jq -r .storePath)
```

Copy the `hash` value into `src.hash` in `default.nix`. The fixed hash makes
the source reproducible and detects replacement of the upstream archive.

### Inspect Debian Metadata

Read the control metadata before changing the package:

```console
dpkg-deb --info "$deb"
dpkg-deb --field "$deb" \
  Package Version Architecture Depends Recommends Homepage
```

Verify at least the following:

- the package name remains `aladdin-2fa-desktop`;
- the version matches the download URL;
- the architecture remains `amd64`;
- the package is still intended for desktop Linux.

Inspect maintainer scripts as well. They may reveal services, configuration,
permissions, or mutable filesystem operations that cannot run during a Nix
build:

```console
work=$(mktemp -d)
dpkg-deb --control "$deb" "$work/control"
find "$work/control" -maxdepth 1 -type f -print | sort
```

The current release has only `control` and `md5sums`. If a future archive adds
`postinst`, `prerm`, or other scripts, inspect them before proceeding:

```console
sed -n '1,240p' "$work/control/postinst"
```

Do not execute maintainer scripts automatically. Model required system-level
behavior explicitly in Nix instead.

### Inspect the Archive Layout

List the archive and extract it into a temporary directory:

```console
dpkg-deb --contents "$deb"
root="$work/root"
mkdir -p "$root"
dpkg-deb --extract "$deb" "$root"
find "$root" -maxdepth 7 -type f -print | sort
```

The current layout is:

```text
usr/sbin/aladdin-2fa-desktop
usr/share/applications/aladdin-2fa-desktop.desktop
usr/share/doc/aladdin-2fa-desktop/changelog.gz
usr/share/icons/hicolor/*/apps/aladdin-2fa-desktop.png
```

Compare it with the install phase in `default.nix`. Update the phase if the
executable, desktop entry, icons, or documentation move.

Check the desktop command explicitly:

```console
grep '^Exec=' \
  "$root/usr/share/applications/aladdin-2fa-desktop.desktop"
```

The current archive uses `/usr/sbin/aladdin-2fa-desktop`. The Nix package
replaces it with `aladdin-2fa-desktop` so desktop environments resolve the
program through `PATH`.

### Inspect ELF Dependencies

Identify every ELF file and print its interpreter and direct dependencies:

```console
find "$root" -type f -exec sh -c '
  file -b "$1" | grep -q ELF || exit 0
  echo "FILE: $1"
  patchelf --print-interpreter "$1" 2>/dev/null || true
  patchelf --print-needed "$1" 2>/dev/null || true
' sh {} \;
```

The same dependencies can be viewed with `readelf`:

```console
readelf -d "$root/usr/sbin/aladdin-2fa-desktop" | grep NEEDED
```

Search for hard-coded FHS paths and dynamically loaded libraries:

```console
strings "$root/usr/sbin/aladdin-2fa-desktop" | \
  rg '/(usr|lib|opt|etc)/|\.so(\.|$)'
```

An embedded source or debug path is not necessarily used at runtime. Confirm
suspect strings through a launch test before introducing an FHS environment.

`autoPatchelfHook` scans installed ELF files during the fixup phase. It changes
the glibc interpreter and adds Nix store paths for matching libraries. A build
failure reports any direct library that cannot be found in `buildInputs`.

### Why These Dependencies Are Present

The current direct ELF dependencies are:

| Input | Purpose |
| --- | --- |
| `libGL` | OpenGL and GLX dispatch. |
| `libx11` | X11 client support and window management. |
| `libxcursor` | X11 cursor loading and rendering. |
| `libxi` | X11 input device extension support. |
| `libxinerama` | X11 multi-monitor geometry. |
| `libxrandr` | Display size, rotation, and monitor handling. |
| `libxxf86vm` | XFree86 video mode extension support. |

`stdenv` supplies glibc, including `libc`, `libm`, `libpthread`, `libresolv`,
`libdl`, and `librt`. Transitive X11 libraries are retained through the direct
inputs above.

Keep libraries in `buildInputs` only when the executable needs them. If a
future version loads a library through `dlopen`, consider
`runtimeDependencies` and verify the resulting RPATH before adding a wrapper.

## Testing an Update

Run deterministic checks first:

```console
nixfmt --check default.nix flake.nix
statix check .
deadnix --fail .
nix flake check
nix build --print-build-logs
```

Confirm that every shared library resolves from the Nix store:

```console
ldd result/bin/aladdin-2fa-desktop
```

There must be no `not found` entries. Inspect the patched interpreter and
RPATH when troubleshooting:

```console
patchelf --print-interpreter result/bin/aladdin-2fa-desktop
patchelf --print-rpath result/bin/aladdin-2fa-desktop
```

Confirm that desktop integration no longer references `/usr/sbin`:

```console
grep '^Exec=' \
  result/share/applications/aladdin-2fa-desktop.desktop
```

The expected result is:

```ini
Exec=aladdin-2fa-desktop
```

Finally, run the application in a graphical desktop session:

```console
nix run
```

Verify that the window opens, icons render, existing authenticators are shown,
and the normal authentication workflow works. Automated build checks cannot
validate access to the display server or the upstream service.

## Update Checklist

For every Aladdin 2FA Desktop release:

1. Find the new versioned `amd64` Debian archive.
2. Prefetch it and record its SRI hash.
3. Inspect metadata and maintainer scripts.
4. Compare the archive layout with the previous release.
5. Inspect every ELF file and its dependencies.
6. Update `version`, `src.hash`, and dependencies when necessary.
7. Run formatting, linting, flake evaluation, and a full build.
8. Check `ldd`, the ELF interpreter, RPATH, and desktop entry.
9. Perform an interactive launch and authentication test.
10. Update documentation when commands or package behavior change.

`flake.lock` pins Nixpkgs, not Aladdin 2FA Desktop. Update it separately:

```console
nix flake update nixpkgs
nix flake check
nix build --print-build-logs
```

Retest the executable after a Nixpkgs update because glibc, OpenGL, and X11
changes may affect proprietary binaries even when the Aladdin version stays
the same.

## Troubleshooting

If a future release builds but does not run:

1. Start the application from a terminal and capture its output.
2. Search the output for missing commands or shared libraries.
3. Run `ldd` and inspect the interpreter and RPATH.
4. Repeat dependency inspection for every changed ELF file.
5. Search the executable for library names and hard-coded paths.
6. Add linked libraries to `buildInputs`.
7. Add dynamically loaded libraries to `runtimeDependencies` if needed.
8. Add a wrapper only for runtime environment variables or subprocesses.
9. Use an FHS environment only when path assumptions cannot be patched.

A native derivation keeps dependencies explicit, produces a smaller closure,
and makes future packaging failures easier to understand.

[aladdin]: https://www.aladdin-rd.ru/catalog/aladdin-2fa/
