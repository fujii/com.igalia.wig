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
flatpak-builder --force-clean --user --install --default-branch=main-$(date +%F) _build com.igalia.wig.yaml
```

It builds in `_build` and installs the result for the current user as a dated branch such as `com.igalia.wig//main-2026-09-27`.
The newly installed branch becomes the current one, so `flatpak run com.igalia.wig` runs the latest build.
The `wig`, WebKit and wpe-platform-gtk sources track their `main` branches, so every build picks up the latest commits.
`_build` is overwritten by every build, but each build is kept as its branch in the local repository `.flatpak-builder/cache`.
The exact commits used by a build are recorded in `files/manifest.json`:

```sh
ostree --repo=.flatpak-builder/cache cat app/com.igalia.wig/x86_64/main-2026-09-27 /files/manifest.json
```

## Running

```sh
flatpak run com.igalia.wig
```

Start it from a directory such as `~` or `/`.
WebKit spawns its web processes in a sub-sandbox with `flatpak-spawn --sandbox`, which uses the current working directory.
The sub-sandbox has no access to your home directory, so if you start wig from somewhere else inside it (for example `~/src/foo`), the sandbox check fails and WebKit silently runs the web processes without the sandbox ([bug 325395](https://bugs.webkit.org/show_bug.cgi?id=325395)).

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

Each build stays installed as its own branch, so you can run an older one by naming its branch:

```sh
flatpak --user list --app | grep com.igalia.wig   # list the installed builds
flatpak run com.igalia.wig//main-2026-09-21
```

To change which build `flatpak run com.igalia.wig` starts:

```sh
flatpak --user make-current com.igalia.wig main-2026-09-21
```

Don't use `flatpak-builder --run` with an old build directory.
WebKit's web processes are spawned via the Flatpak portal, and the portal starts them from the installed app instead of from the build directory.
If the two WebKit versions differ, the web processes crash with `Received invalid message`.

### Uninstalling a build

```sh
flatpak --user uninstall com.igalia.wig//main-2026-09-21
```

This only removes the installed app.
The build is still in the local repository `.flatpak-builder/cache`, so you can install it again later.

### Reinstalling an uninstalled build

Install it from `.flatpak-builder/cache`:

```sh
flatpak --user install wig-origin com.igalia.wig//main-2026-09-21
```

`wig-origin` is the local remote that `flatpak-builder --install` adds for `.flatpak-builder/cache`.
Flatpak removes it automatically when the last build installed from it is uninstalled.
In that case, add it again first:

```sh
flatpak --user remote-add --no-gpg-verify wig-origin .flatpak-builder/cache
```

To list the branches in `.flatpak-builder/cache`, run:

```sh
ostree --repo=.flatpak-builder/cache refs | grep ^app/com.igalia.wig/
```

### Removing a build completely

To also free the disk space, delete the branch from `.flatpak-builder/cache`:

```sh
flatpak --user uninstall com.igalia.wig//main-2026-09-21
ostree --repo=.flatpak-builder/cache refs --delete app/com.igalia.wig/x86_64/main-2026-09-21
flatpak build-update-repo --prune .flatpak-builder/cache
```

After this, the build can't be reinstalled.

## Debugging

### Backtrace of a crash

Web processes that crash leave a core file that `coredumpctl` can find.
Find the PID of the crashed process:

```sh
coredumpctl list
```

Then print its backtrace with `flatpak-coredumpctl`, which runs gdb inside the app's sandbox:

```sh
flatpak-coredumpctl -m <pid> --gdb-arguments="-batch -ex 'bt 20'" com.igalia.wig//main-2026-09-27
```

Give the branch of the build that actually crashed.
With a different branch, the symbols resolve to nonsense names.

The debug symbols come from the `com.igalia.wig.Debug` extension, which has to be installed for the same branch:

```sh
flatpak --user list --all | grep com.igalia.wig.Debug
```

If the backtrace has no function names or source locations, the extension for that branch is missing.
