# com.igalia.wig

Flatpak manifest for [wig](https://github.com/Igalia/wig), a web browser built on WPE WebKit.

The manifest builds these modules from source: libevent, OpenXR SDK, Eigen, libmd, libbsd, Monado, WPE WebKit (`main`), wpe-platform-gtk, template-glib and wig.

## Requirements

- `flatpak` and `flatpak-builder`
- The Flathub remote:

  ```sh
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  ```

- The runtime, SDK and SDK extension used by the manifest:

  ```sh
  flatpak install --user flathub org.gnome.Platform//50 org.gnome.Sdk//50 org.freedesktop.Sdk.Extension.llvm22//25.08
  ```

  Alternatively, pass `--install-deps-from=flathub` to `flatpak-builder` to install them automatically.

Building WebKit takes a long time and needs a lot of memory and disk space.

## Building

```sh
./build.sh
```

This runs:

```sh
flatpak-builder --force-clean --user --install --default-branch=main build com.igalia.wig.yaml
flatpak build-bundle .flatpak-builder/cache bundles/com.igalia.wig-$(date +%F).flatpak com.igalia.wig main
flatpak build-bundle --runtime .flatpak-builder/cache bundles/com.igalia.wig.Debug-$(date +%F).flatpak com.igalia.wig.Debug main
```

It builds in `build` and installs the result for the current user as `com.igalia.wig//main`, so `flatpak run com.igalia.wig` runs the latest build.
Every build replaces the previous one, both in the installation and in the local repository `.flatpak-builder/cache`.
To keep older builds, it also exports the build and its `com.igalia.wig.Debug` extension as dated single-file bundles such as `bundles/com.igalia.wig-2026-09-27.flatpak` and `bundles/com.igalia.wig.Debug-2026-09-27.flatpak`.
The app bundle is about 40 MB, and the Debug bundle is about 600 MB and takes several minutes to write.
`bundles` is ignored by git, as are `build` and `.flatpak-builder`.
The `wig`, WebKit and wpe-platform-gtk sources track their `main` branches, so every build picks up the latest commits.
The exact commits used by a build are recorded in `files/manifest.json`:

```sh
ostree --repo=.flatpak-builder/cache cat app/com.igalia.wig/x86_64/main /files/manifest.json
```

## Running

```sh
flatpak run com.igalia.wig
```

### WebXR

WebXR uses the [Monado](https://monado.freedesktop.org/) OpenXR runtime, which is included in the app.
Start `monado-service` from the app before using WebXR:

```sh
flatpak run --command=monado-service com.igalia.wig
```

It runs in a separate sandbox from wig, and wig connects to it through `$XDG_RUNTIME_DIR/app/com.igalia.wig/monado_comp_ipc`.
Flatpak shares this directory between all instances of the app, so it doesn't matter whether `monado-service` or wig is started first.
To stop it, press Enter or Ctrl+C.
If its stdin is `/dev/null` or a regular file, for example when you start it from a script, set `XRT_NO_STDIN=1`, or it fails to start because it can't watch stdin.

The host's Monado isn't used.
Monado's client library, which wig loads, must be the same version as `monado-service`, and the host's library can't be loaded in the sandbox anyway.
Stop the host's `monado.service` while using the app's one, because both can't use the HMD at the same time.

The app has `--device=all` so that `monado-service` can access the HMD and the controllers.
The host still needs the udev rules for the devices, such as those of [xr-hardware](https://gitlab.freedesktop.org/monado/utilities/xr-hardware).

### Running an older build

Only the latest build is installed, so install an older one from its bundles, which replaces the current one:

```sh
flatpak --user uninstall com.igalia.wig com.igalia.wig.Debug
flatpak --user install --bundle bundles/com.igalia.wig-2026-09-21.flatpak
flatpak --user install --bundle bundles/com.igalia.wig.Debug-2026-09-21.flatpak
```

Installing the bundle of the latest build, or running `./build.sh`, brings the current one back.

Don't use `flatpak-builder --run` with an old build directory.
WebKit's web processes are spawned via the Flatpak portal, and the portal starts them from the installed app instead of from the build directory.
If the two WebKit versions differ, the web processes crash with `Received invalid message`.

## Debugging

### Backtrace of a crash

Web processes that crash leave a core file that `coredumpctl` can find.
Find the PID of the crashed process:

```sh
coredumpctl list
```

Then print its backtrace with `flatpak-coredumpctl`, which runs gdb inside the app's sandbox:

```sh
flatpak-coredumpctl -m <pid> --gdb-arguments="-batch -ex 'bt 20'" com.igalia.wig
```

The installed build must be the one that actually crashed.
With a different build, the symbols resolve to nonsense names.
If you have rebuilt since the crash, install the bundles of the crashed build first, as described in "Running an older build".

The debug symbols come from the `com.igalia.wig.Debug` extension, which has to be installed together with the app:

```sh
flatpak --user list --all | grep com.igalia.wig.Debug
```

If the backtrace has no function names or source locations, the extension is missing or belongs to a different build.
