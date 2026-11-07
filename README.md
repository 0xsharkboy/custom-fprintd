# custom-fprintd

Reproducible NixOS packages for the experimental ELAN Match-on-Chip 2
fingerprint driver. This repository targets the `04f3:0c00` sensor in an HP
Pavilion Laptop 15-eh2xxx and keeps the custom libfprint scoped to fprintd.
It does not replace `pkgs.libfprint` globally.

The packaging and upstream test suites build successfully. Runtime behavior on
the physical sensor still needs to be confirmed with the acceptance steps
below.

## Supported devices

The pinned driver revision declares these USB IDs:

| USB ID | Status |
| --- | --- |
| `04f3:0c00` | Target hardware; physical verification pending |
| `04f3:0c4c` | Driver-declared support |
| `04f3:0c5e` | Driver-declared support |
| `04f3:0c7c` | Driver-declared support |
| `04f3:0c90` | Driver-declared support |

This builds libfprint from the [`elanmoc2` branch of 0xsharkboy/libfprint][fork]:
upstream libfprint 1.94.100 with [Depau's experimental `elanmoc2`
driver][driver] and the following changes on top:

- cancellable commands wait for the finger indefinitely instead of timing out;
- retryable errors are reported to fprintd, which starts a new attempt;
- prints can be deleted individually from the sensor.

The rest of the package definition comes from the nixpkgs revision pinned by
`flake.lock`. The original Arch Linux
investigation was based on [this guide][guide], but `04f3:0c00` is already in
the driver and needs no extra device-ID patch.

## Install from a classic NixOS configuration

Clone the repository somewhere stable, for example
`/etc/nixos/custom-fprintd`. In `/etc/nixos/configuration.nix`, import its
flake module and enable the opt-in driver:

```nix
{ ... }:

let
  customFprintd = builtins.getFlake "path:/etc/nixos/custom-fprintd";
in
{
  imports = [ customFprintd.nixosModules.default ];

  services.fprintd.elanmoc2.enable = true;
}
```

`builtins.getFlake` requires the `nix-command` and `flakes` experimental
features. Current NixOS releases normally enable them for flake use; otherwise
add:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Install from another flake

Add this repository as an input, then import its module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    custom-fprintd.url = "github:YOUR-GITHUB-USER/custom-fprintd";
  };

  outputs = { nixpkgs, custom-fprintd, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        custom-fprintd.nixosModules.default
        ./configuration.nix
        { services.fprintd.elanmoc2.enable = true; }
      ];
    };
  };
}
```

Do not make this repository's `nixpkgs` input follow the consumer's input. The
libfprint fork is deliberately tested against the exact revision in this
repository's lock file. A future lock update should be accepted only after all
checks pass.

The flake also exports these `x86_64-linux` packages:

- `libfprint-elanmoc2`
- `fprintd-elanmoc2`
- `default`, which is `fprintd-elanmoc2`

## Test safely on the laptop

Start with a temporary system generation so a broken authentication path does
not become the boot default:

```console
$ lsusb -d 04f3:0c00
$ sudo nixos-rebuild test
$ fprintd-list "$USER"
$ fprintd-enroll "$USER"
$ fprintd-verify "$USER"
```

Then test all intended local authentication paths:

1. Lock and unlock the GNOME session with a fingerprint.
2. Open a new terminal and run `sudo -k; sudo true`.
3. Test a local TTY login.
4. Confirm the password still works when fingerprint verification is skipped
   or fails.
5. Suspend, resume, and run `fprintd-verify "$USER"` again.

Enabling the module uses the standard NixOS fprintd PAM defaults for local
services. It does not enable fingerprint authentication for remote SSH. A
specific local service can opt out, for example:

```nix
security.pam.services.sudo.fprintAuth = false;
```

Inspect daemon logs with:

```console
$ journalctl -b -u fprintd
```

If everything works, make the generation persistent with
`sudo nixos-rebuild switch`. If not, reboot or run
`sudo nixos-rebuild switch --rollback` to return to the previous generation.

## Deletion and recovery

The driver can enroll, verify and delete individual prints, and can clear the
whole sensor. It does not list the prints stored on the sensor, so fprintd only
knows about prints enrolled through its own local records.

To start clean:

1. Remove the local fprintd enrollments for every user of this sensor.
2. Confirm `fprintd-list USERNAME` shows none for each user.
3. Enroll the first fresh fingerprint.

When fprintd sees the first fresh enrollment with no local records, it asks the
driver to clear the sensor before enrolling. This is sensor-wide: it can erase
prints created by another user or operating system. A normal delete request only
removes the selected print.

## Development

Run the complete automated verification with:

```console
$ nix flake check --print-build-logs
$ nix build --no-link .#libfprint-elanmoc2 .#fprintd-elanmoc2
$ bash tests/package-contract.sh
$ bash tests/module-contract.sh
```

CI runs the same flake checks, explicit package builds, and package contract on
`x86_64-linux`.
A virtual machine cannot emulate the physical USB fingerprint protocol, so the
laptop acceptance steps remain manual.

## License and upstream work

The repository is licensed under LGPL-2.1-or-later. The ELAN MoC2 driver is
libfprint work by Davide Depau and retains its upstream copyright and license
notices.

[fork]: https://github.com/0xsharkboy/libfprint/tree/elanmoc2
[driver]: https://gitlab.freedesktop.org/Depau/libfprint/-/tree/11f0316d069cc90c154c8cb0e46478388c5e2a74/libfprint/drivers/elanmoc2
[guide]: https://medium.com/@llupRisingll/the-quest-to-make-my-hp-laptops-fingerprint-reader-work-on-arch-linux-4d8c123bc494
