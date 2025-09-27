#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox
from tkinter import ttk
import os
import sys
import datetime
import subprocess
import shutil

class VersionDialog(tk.Tk):
    def __init__(self, target_path):
        super().__init__()
        self.title("Select Version")
        self.selected_index = None
        self.selected_action = None
        self.geometry("340x370")
        self.target_path = target_path
        # Show filename above radio buttons
        filename_label = ttk.Label(self, text=os.path.basename(self.target_path), font=("Arial", 11, "bold"))
        filename_label.pack(pady=(10, 0))
        # Show last modified date below filename
        try:
            mtime = os.path.getmtime(self.target_path)
            mtime_str = datetime.datetime.fromtimestamp(mtime).strftime('%b %d %Y %-I:%M%p').replace('AM','am').replace('PM','pm')
        except Exception:
            mtime_str = "Unknown"
        lastmod_label = ttk.Label(self, text=f"Last Modified: {mtime_str}", font=("Arial", 10))
        lastmod_label.pack(pady=(0, 6))
        # Radio buttons for mode selection
        radio_frame = ttk.Frame(self)
        radio_frame.pack(pady=4)
        self.mode_var = tk.StringVar(value="unique")
        unique_radio = ttk.Radiobutton(radio_frame, text="Unique Versions", variable=self.mode_var, value="unique", command=self.on_mode_change)
        all_radio = ttk.Radiobutton(radio_frame, text="All Snapshots", variable=self.mode_var, value="all", command=self.on_mode_change)
        unique_radio.pack(side=tk.LEFT, padx=6)
        all_radio.pack(side=tk.LEFT, padx=6)
        # Column headers
        header_frame = ttk.Frame(self)
        header_frame.pack(pady=(4,0), fill=tk.X)
        tk.Label(header_frame, text="Snapshot Date", font=("Arial", 10, "bold"), anchor="w").pack(side=tk.LEFT, padx=(8,0))
        tk.Label(header_frame, text="Modified", font=("Arial", 10, "bold"), width=14, anchor="center").pack(side=tk.LEFT, padx=(60,0))
        # Single listbox with star spacing and alternating row colors
        frame = ttk.Frame(self)
        frame.pack(pady=2, fill=tk.BOTH, expand=True)
        self.listbox = tk.Listbox(frame, font=("Arial", 11), height=10, width=38)
        scrollbar = ttk.Scrollbar(frame, orient="vertical", command=self.listbox.yview)
        self.listbox.config(yscrollcommand=scrollbar.set)
        self.listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        btn_frame = ttk.Frame(self)
        btn_frame.pack(pady=10)
        style = ttk.Style(self)
        style.configure("TButton", padding=4, font=("Arial", 10), width=9)
        self.open_btn = ttk.Button(btn_frame, text="Open", command=self.open_clicked, style="TButton")
        self.open_btn.pack(side=tk.LEFT, padx=8)
        self.parent_btn = ttk.Button(btn_frame, text="Open Parent Folder", command=self.open_parent_folder_clicked, style="TButton")
        self.parent_btn.pack(side=tk.LEFT, padx=8)
        self.parent_btn.config(width=18)  # Make the button wider
        self.restore_btn = ttk.Button(btn_frame, text="Restore", command=self.restore_clicked, style="TButton")
        self.restore_btn.pack(side=tk.LEFT, padx=8)
        # Disable buttons initially
        self.open_btn.state(["disabled"])
        self.parent_btn.state(["disabled"])
        self.restore_btn.state(["disabled"])
        # Bind selection event
        self.listbox.bind('<<ListboxSelect>>', self.on_listbox_select)
        self.versions = []
        self.reload_versions()
    def reload_versions(self):
        mode = self.mode_var.get()
        all_versions = get_snapshot_versions(self.target_path, mode="all")
        unique_versions = get_snapshot_versions(self.target_path, mode="unique")
        if mode == "all":
            self.versions = all_versions
            unique_mtimes = set(v['modified_time'] for v in unique_versions)
        else:
            self.versions = unique_versions
            unique_mtimes = set(v['modified_time'] for v in unique_versions)
        self.listbox.delete(0, tk.END)
        if not self.versions:
            self.versions = [{'display': "No different versions found", 'path': None, 'is_unique': False, 'modified_time': None}]
        seen_mtimes = set()
        for i, v in enumerate(self.versions):
            label = f"   {v['display']}"
            self.listbox.insert(tk.END, label)
            # In 'all' mode, only the first occurrence of a unique modified date is blue
            if mode == "all":
                if v.get('modified_time') in unique_mtimes and v.get('modified_time') not in seen_mtimes:
                    self.listbox.itemconfig(i, bg="#e0e6f8", fg="#000000")
                    seen_mtimes.add(v.get('modified_time'))
                else:
                    self.listbox.itemconfig(i, bg="#f0f0f0", fg="#000000")
            else:
                self.listbox.itemconfig(i, bg="#e0e6f8", fg="#000000")
    def on_mode_change(self):
        # Disable buttons when changing mode
        self.open_btn.state(["disabled"])
        self.parent_btn.state(["disabled"])
        self.restore_btn.state(["disabled"])
        self.reload_versions()
    def open_clicked(self):
        sel = self.listbox.curselection()
        if sel:
            idx = sel[0]
            snap_path = self.versions[idx]['path']
            if snap_path:
                try:
                    subprocess.Popen(["xdg-open", snap_path])
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to open file: {e}")
            self.destroy()
    def open_parent_folder_clicked(self):
        sel = self.listbox.curselection()
        if sel:
            idx = sel[0]
            snap_path = self.versions[idx]['path']
            if snap_path:
                parent_dir = os.path.dirname(snap_path)
                try:
                    subprocess.Popen(["xdg-open", parent_dir])
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to open folder: {e}")
        self.destroy()
    def restore_clicked(self):
        sel = self.listbox.curselection()
        if sel:
            idx = sel[0]
            snap_path = self.versions[idx]['path']
            if snap_path:
                try:
                    orig = self.target_path
                    stat = os.stat(orig)
                    mtime = datetime.datetime.fromtimestamp(stat.st_mtime)
                    base, ext = os.path.splitext(orig)
                    mtime_str = mtime.strftime('%Y%m%d-%H%M%S')
                    backup = f"{base}-{mtime_str}{ext}"
                    os.rename(orig, backup)
                    if os.path.isdir(snap_path):
                        shutil.copytree(snap_path, orig)
                    else:
                        shutil.copy2(snap_path, orig)
                    messagebox.showinfo("Restore", f"Restored from snapshot. Previous version saved as:\n{backup}")
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to restore file: {e}")
            self.destroy()
    def on_listbox_select(self, event=None):
        sel = self.listbox.curselection()
        if sel and self.versions and self.versions[sel[0]].get('path'):
            self.open_btn.state(["!disabled"])
            self.parent_btn.state(["!disabled"])
            self.restore_btn.state(["!disabled"])
        else:
            self.open_btn.state(["disabled"])
            self.parent_btn.state(["disabled"])
            self.restore_btn.state(["disabled"])

def get_snapshot_versions(target_path, mode="unique"):
    snapdir = "/home/.snapshots"
    rel = os.path.relpath(target_path, "/home")
    if not os.path.isdir(snapdir):
        return []
    try:
        current_stat = os.stat(target_path)
        current_mtime = current_stat.st_mtime
    except Exception:
        current_mtime = None
    snapshots = []
    for snap in sorted(os.listdir(snapdir)):
        snap_path = os.path.join(snapdir, snap, rel)
        if os.path.exists(snap_path):
            try:
                stat = os.stat(snap_path)
                mtime = stat.st_mtime
                # Parse snapshot date from directory name
                snap_date = ""
                parts = snap.split(".")
                if len(parts) > 1 and len(parts[-1]) >= 9:
                    snap_date_raw = parts[-1]
                    try:
                        snap_date_dt = datetime.datetime.strptime(snap_date_raw, "%Y%m%dT%H%M")
                        snap_date = snap_date_dt.strftime("%Y-%m-%d %H:%M")
                    except Exception:
                        snap_date = snap_date_raw
                else:
                    snap_date_dt = None
                snapshots.append({
                    'snapshot': snap,
                    'snapshot_date': snap_date,
                    'snapshot_date_dt': snap_date_dt if 'snap_date_dt' in locals() else None,
                    'modified_time': mtime,
                    'path': snap_path
                })
            except Exception:
                continue
    # Sort by snapshot date descending (latest first)
    snapshots = [s for s in snapshots if s['snapshot_date_dt'] is not None]
    snapshots.sort(key=lambda x: x['snapshot_date_dt'], reverse=True)
    # Prepare display list
    all_versions = []
    for snap in snapshots:
        # Format both snapshot and modified date the same way
        snap_display = snap['snapshot_date_dt'].strftime('%b %d %Y %-I:%M%p').replace('AM','am').replace('PM','pm') if snap['snapshot_date_dt'] else snap['snapshot_date']
        mod_display = datetime.datetime.fromtimestamp(snap['modified_time']).strftime('%b %d %Y %-I:%M%p').replace('AM','am').replace('PM','pm')
        display = f"{snap_display}    {mod_display}"
        all_versions.append({
            'display': display,
            'path': snap['path'],
            'is_unique': False,
            'modified_time': snap['modified_time']
        })
    if mode == "all":
        return all_versions
    # Filter for unique modified times (not current, and not duplicate mtimes)
    seen_mtimes = set()
    unique_versions = []
    for v in all_versions:
        if v['modified_time'] == current_mtime:
            continue
        if v['modified_time'] in seen_mtimes:
            continue
        seen_mtimes.add(v['modified_time'])
        v['is_unique'] = True
        unique_versions.append(v)
    return unique_versions

def main():
    if len(sys.argv) < 2:
        messagebox.showerror("Error", "No file specified.")
        return
    target = sys.argv[1]
    app = VersionDialog(target)
    app.mainloop()

if __name__ == "__main__":
    main()
