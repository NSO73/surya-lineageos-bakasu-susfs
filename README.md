# surya-lineageos-bakasu-susfs

LineageOS kernel for the **Poco X3 NFC (`surya`)** with **ReSukiSU / BakaSU** root and **SUSFS**, built automatically by GitHub Actions from upstream sources only: no fork, no copied files.

The output is an **AnyKernel3** zip that replaces only the kernel. The ramdisk, dtb and dtbo already on the device are kept.

## Components

Every version is pinned in [`versions.env`](versions.env), the single source of truth for what gets built.

| Component | Upstream | Role |
|---|---|---|
| Kernel | [LineageOS/android_kernel_xiaomi_surya](https://github.com/LineageOS/android_kernel_xiaomi_surya) | base, branch matching the ROM (`lineage-22.2`) |
| Root | [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU) (formerly ReSukiSU) | KernelSU driver, integrated with its `kernel/setup.sh` at a pinned tag |
| SUSFS | [JackA1ltman/NonGKI_Kernel_Build_2nd](https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd) | SUSFS backport for non-GKI 4.14 kernels (core patch + inline hooks) |
| Packaging | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) | flashable zip, with the local [`anykernel/anykernel.sh`](anykernel/anykernel.sh) |
| Toolchain | [kdrag0n/proton-clang](https://github.com/kdrag0n/proton-clang) | compiler |

Kernel options added to `surya_defconfig` live in [`config/surya.fragment`](config/surya.fragment). The build fails if Kconfig drops any of them.

## Install

1. Back up the current `boot` partition: this is your rollback.
2. Flash the zip from the [latest release](../../releases), from recovery or an AnyKernel3-capable app.
3. Install **the manager APK of the same version** as the kernel. Each release links it at the top of its notes. This is required: the manager ships `ksud`, and with another version no root module starts.
4. Open the manager, which updates `ksud`, then reboot.

On the very first boot after flashing, before step 3, root modules do not run. This is expected.

### SUSFS configuration

The kernel provides the SUSFS mechanism, but **hides nothing until it is configured**. Configure it from the SUSFS screen of the BakaSU manager, or with `ksud susfs config …`. The configuration is stored in `/data/adb/ksu/.susfs.json` and re-applied on every boot.

## Automatic updates

The [`update`](.github/workflows/update.yml) workflow runs daily:

1. [`scripts/check-upstreams.sh`](scripts/check-upstreams.sh) queries every upstream: latest commit of each tracked branch, latest BakaSU release (pre-releases included). New commits in multi-purpose repos count only if they touch files the build uses: the 4.14 SUSFS patch and hook script for NonGKI, the flashing scripts and tools for AnyKernel3. LineageOS ROM builds never trigger anything: only commits to the surya kernel repo do.
2. If a version moved, the new `versions.env` is committed on a side branch and built by the [`build`](.github/workflows/build.yml) workflow.
3. **Build succeeds**: a release is published with the zip, its SHA-256, the version details and the matching manager APK, then `main` moves forward.
4. **Build fails**: `main` is left untouched, nothing is published, and an `upstream-failure` issue is opened (or updated) with the versions involved and a link to the log.

A new LineageOS kernel branch (for example `lineage-23.0`) is reported but **never adopted automatically**: switch `KERNEL_BRANCH` by hand only once the ROM itself moves to that version.

The `update` workflow can also be run by hand, with the `force` option to rebuild and publish without any upstream change.

## Manual build

The `build` workflow runs on every change to `versions.env`, `config/`, `patches/` or `anykernel/`, and by hand from the Actions tab (`release` option to publish). The zip is available as a run artifact.

The build keeps a compiler cache (`ccache`): a first build takes 30 to 40 minutes, later ones a few minutes.

## Local fixups

If an upstream change makes the SUSFS patch stop applying cleanly to the LineageOS tree, the build stops and lists the rejected hunks (attached to the run artifacts). The fix goes in `patches/*.patch`, applied right after the SUSFS patch. This folder stays empty as long as no fix is needed.

## Credits

| Project | Author | What it brings |
|---|---|---|
| [LineageOS kernel](https://github.com/LineageOS/android_kernel_xiaomi_surya) | LineageOS | the base kernel |
| [BakaSU / ReSukiSU](https://github.com/Baka-SU/BakaSU), based on [KernelSU](https://github.com/tiann/KernelSU) | BakaSU, KernelSU | the root driver in the kernel, and the manager app (including its SUSFS settings screen) |
| [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) | simonpunk | the SUSFS kernel code compiled into this kernel: path, mount and map hiding, uname/cmdline spoofing |
| [NonGKI_Kernel_Build_2nd](https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd) | JackA1ltman | the backport of SUSFS and its inline hooks to 4.14 non-GKI kernels |
| [AnyKernel3](https://github.com/osm0sis/AnyKernel3) | osm0sis | the flashable zip |
| [Proton Clang](https://github.com/kdrag0n/proton-clang) | kdrag0n | the toolchain |

Each component keeps the license of its original project; the kernel is GPL-2.0.

## License

The files of this repository (workflows, scripts, configuration) are released under the [GPL-2.0](LICENSE), like the kernel they build.
