#!/bin/sh
set -e
date=$(date +%F)
flatpak-builder --force-clean --user --install --default-branch=main-$date _build com.igalia.wig.yaml
