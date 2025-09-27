#!/usr/bin/env python3
"""
install-flatpaks.py: GUI Flatpak group selector and installer for NixOS

- Reads groups from flatpaks.py
- Presents a GUI checklist (Tkinter) to select groups
- Installs all Flatpaks in selected groups system-wide
"""
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox
from tkinter import ttk

# Import the group definitions
try:
    from flatpaks import FLATPAK_GROUPS
except ImportError:
    print("Could not import flatpaks.py. Make sure it is in the same directory.", file=sys.stderr)
    sys.exit(1)

class FlatpakSelector(tk.Tk):
    def __init__(self, groups):
        super().__init__()
        self.title("Flatpak Group Installer")
        self.geometry("400x400")
        self.selected = {}
        label = ttk.Label(self, text="Select Flatpak groups to install:")
        label.pack(pady=10)
        self.check_vars = {}
        for group in groups:
            var = tk.BooleanVar()
            chk = ttk.Checkbutton(self, text=group, variable=var)
            chk.pack(anchor='w', padx=20)
            self.check_vars[group] = var
        btn = ttk.Button(self, text="Install Selected", command=self.on_submit)
        btn.pack(pady=20)
    def on_submit(self):
        self.selected = [g for g, v in self.check_vars.items() if v.get()]
        if not self.selected:
            messagebox.showinfo("No Selection", "No groups selected. Exiting.")
            self.destroy()
        else:
            self.destroy()

def install_flatpaks(groups):
    flatpaks = set()
    for group in groups:
        flatpaks.update(FLATPAK_GROUPS.get(group, []))
    if not flatpaks:
        print("No Flatpaks to install.")
        return
    for app in flatpaks:
        print(f"Installing {app} system-wide...")
        try:
            subprocess.run(["flatpak", "install", "-y", "--system", app], check=True)
        except subprocess.CalledProcessError:
            print(f"Failed to install {app}", file=sys.stderr)
    print("Done.")

def ensure_system_flathub():
    import shutil
    if not shutil.which("flatpak"):
        print("Flatpak is not installed.", file=sys.stderr)
        sys.exit(1)
    # Check if flathub is present as a system remote
    result = subprocess.run(["flatpak", "remotes", "--system"], capture_output=True, text=True)
    if "flathub" not in result.stdout:
        print("Adding Flathub as a system remote...")
        subprocess.run([
            "flatpak", "remote-add", "--if-not-exists", "flathub", "https://flathub.org/repo/flathub.flatpakrepo"
        ], check=True)

def main():
    ensure_system_flathub()
    app = FlatpakSelector(FLATPAK_GROUPS.keys())
    app.mainloop()
    if getattr(app, 'selected', []):
        install_flatpaks(app.selected)

if __name__ == "__main__":
    main()
