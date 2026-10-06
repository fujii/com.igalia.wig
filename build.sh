#!/bin/sh
set -e
date=$(date +%F)
flatpak-builder --force-clean --user --install --default-branch=main build com.igalia.wig.yaml
mkdir -p bundles
flatpak build-bundle .flatpak-builder/cache bundles/com.igalia.wig-$date.flatpak com.igalia.wig main
flatpak build-bundle --runtime .flatpak-builder/cache bundles/com.igalia.wig.Debug-$date.flatpak com.igalia.wig.Debug main
