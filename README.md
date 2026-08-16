# aladdin4nix

**A ready-to-use Nix package for Aladdin 2FA Desktop on x86_64 Linux.**

`aladdin4nix` repackages the official Aladdin 2FA Desktop application for
NixOS and other Linux distributions with the Nix package manager.

<div align="center">

[![Nix Flakes](https://img.shields.io/badge/Nix-Flakes-5277C3?style=for-the-badge&logo=nixos&logoColor=white&labelColor=101418)][flakes]
![Platform](https://img.shields.io/badge/Platform-x86__64--linux-blue?style=for-the-badge&logo=linux&logoColor=white&labelColor=101418)
[![License](https://img.shields.io/badge/License-Unfree-orange?style=for-the-badge&labelColor=101418)][aladdin]

</div>

## Features

- Packages the official Aladdin 2FA Desktop release.
- Patches native ELF dependencies without a full FHS environment.
- Provides an application entry for `nix run`.
- Installs a desktop entry and application icons.
- Works on NixOS and other distributions with Nix installed.
- Includes a reproducible development environment.

## Quick Start

Run Aladdin 2FA Desktop without installing it:

```console
nix run github:MOIS3Y/aladdin4nix
```

The package is downloaded, built, and started in one command. Nix reuses the
result from its store on subsequent runs.

> [!NOTE]
> The upstream application is available only for `x86_64-linux`.

## Installation

### Nix Profile

Install the application into your user profile:

```console
nix profile add github:MOIS3Y/aladdin4nix
```

After installation, start it from your application menu or terminal:

```console
aladdin-2fa-desktop
```

Remove the application from your profile with:

```console
nix profile remove aladdin4nix
```

The profile entry is named `aladdin4nix`. You can confirm it with
`nix profile list`.

### NixOS Flake

Add this repository to your flake inputs and include its default package:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aladdin4nix.url = "github:MOIS3Y/aladdin4nix";
  };

  outputs =
    { nixpkgs, aladdin4nix, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          {
            environment.systemPackages = [
              aladdin4nix.packages.${system}.default
            ];
          }
        ];
      };
    };
}
```

Apply the configuration as usual:

```console
sudo nixos-rebuild switch --flake .#hostname
```

### Existing NixOS Configuration

You can also build the package directly from a checked-out repository:

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.callPackage /path/to/aladdin4nix/default.nix { })
  ];
}
```

Because the application is proprietary, make sure unfree packages are allowed
in the Nixpkgs instance used by your configuration:

```nix
{
  nixpkgs.config.allowUnfree = true;
}
```

## Updating

Update the installed profile package to the latest flake revision:

```console
nix profile upgrade aladdin4nix
```

For a NixOS flake configuration, update its locked input and rebuild:

```console
nix flake update aladdin4nix
sudo nixos-rebuild switch --flake .#hostname
```

## Local Usage

Clone the repository and run the local flake:

```console
git clone https://github.com/MOIS3Y/aladdin4nix.git
cd aladdin4nix
nix run
```

Build the package without starting it:

```console
nix build
```

The resulting executable is available at:

```console
./result/bin/aladdin-2fa-desktop
```

## Development

Enter the development environment:

```console
nix develop
```

It provides `nixfmt`, `statix`, and `deadnix`. Run all project checks with:

```console
nixfmt --check default.nix flake.nix
statix check .
deadnix --fail .
nix flake check
```

## About Aladdin 2FA

[Aladdin 2FA][aladdin] provides PUSH and OTP authentication together with
JaCarta Authentication Server. The desktop client allows users to work with
their authenticators without installing the mobile application.

This repository is an unofficial Nix package. The application itself is
developed and distributed by Aladdin R.D.

## Supported Platforms

| Platform        | Support |
| --------------- | ------- |
| `x86_64-linux`  | Yes     |
| `aarch64-linux` | No      |
| macOS           | No      |

Other architectures are not supported because upstream publishes only an
x86_64 Linux binary and does not provide source code.

## License

The packaging code in this repository does not change the license of the
upstream application. Aladdin 2FA Desktop is proprietary software and is
marked as `unfree` in the Nix package metadata.

[aladdin]: https://www.aladdin-rd.ru/catalog/aladdin-2fa/
[flakes]: https://wiki.nixos.org/wiki/Flakes
