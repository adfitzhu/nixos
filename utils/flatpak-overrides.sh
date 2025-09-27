#!/bin/bash
# flatpak-overrides.sh - Apply consistent Flatpak permissions

# Global overrides for all apps
flatpak override --user --socket=wayland --nosocket=x11 --nosocket=fallback-x11
flatpak override --user --env=XCURSOR_PATH=/run/host/user-share/icons:/run/host/share/icons
flatpak override --user --env=GTK_THEME=Adwaita:dark

# App-specific overrides
flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro com.github.tchx84.Flatseal
flatpak override --user --filesystem=xdg-download --filesystem=xdg-documents com.microsoft.Edge
flatpak override --user --filesystem=xdg-music --filesystem=xdg-documents --socket=pulseaudio org.audacityteam.Audacity
flatpak override --user --socket=x11 --nosocket=wayland org.onlyoffice.desktopeditors

echo "Flatpak overrides applied successfully!"
