#!/usr/bin/env python3
"""GPG Encryption Settings dialog — replicates nemo-seahorse/libcryptui UI.

nemo-crypt - GPG encryption integration for Nemo file manager
Copyright (C) 2026 John Crouch <github@ko4dfo.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Outputs selections on stdout for the calling script to parse:
    MODE=symmetric|recipients
    RECIPIENTS=keyid1,keyid2,...
    SIGNER=keyid|none
Exits 0 on OK, 1 on Cancel.
"""

import subprocess
import sys

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Pango


def get_gpg_keys(key_type="public"):
    """Return list of (keyid, uid) tuples for GPG keys.

    Args:
        key_type: "public" for --list-keys, "secret" for --list-secret-keys

    Returns:
        list of (keyid, uid) tuples, or None on error
    """
    keys = []

    if key_type == "secret":
        cmd = ["gpg", "--list-secret-keys", "--with-colons"]
        record_type = "sec"
    else:
        cmd = ["gpg", "--list-keys", "--with-colons"]
        record_type = "pub"

    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
        current_keyid = None
        for line in out.splitlines():
            fields = line.split(":")
            if fields[0] == record_type:
                current_keyid = fields[4]
            elif fields[0] == "uid" and current_keyid:
                keys.append((current_keyid, fields[9]))
                current_keyid = None
    except subprocess.CalledProcessError:
        # GPG command failed
        return None
    except FileNotFoundError:
        # GPG not installed
        return None
    except Exception:
        # Unexpected error
        return None

    return keys


class EncryptDialog(Gtk.Dialog):
    def __init__(self, public_keys, secret_keys):
        super().__init__(
            title="Encryption settings",
            flags=Gtk.DialogFlags.MODAL,
        )
        self.set_default_size(520, 400)
        self.set_resizable(True)
        self.set_icon_name("dialog-password")
        self.add_button("Cancel", Gtk.ResponseType.CANCEL)
        ok_btn = self.add_button("OK", Gtk.ResponseType.OK)
        ok_btn.get_style_context().add_class("suggested-action")

        self.public_keys = public_keys
        self.secret_keys = secret_keys

        content = self.get_content_area()
        content.set_spacing(8)
        content.set_margin_start(12)
        content.set_margin_end(12)
        content.set_margin_top(8)
        content.set_margin_bottom(4)

        # ── Radio buttons: passphrase vs recipients ──
        self.radio_passphrase = Gtk.RadioButton.new_with_label(
            None, "Use passphrase only"
        )
        self.radio_recipients = Gtk.RadioButton.new_with_label_from_widget(
            self.radio_passphrase, "Choose a set of recipients:"
        )
        self.radio_recipients.set_active(True)
        self.radio_passphrase.connect("toggled", self._on_mode_toggled)

        content.pack_start(self.radio_passphrase, False, False, 0)
        content.pack_start(self.radio_recipients, False, False, 0)

        # ── Recipient area (filter + key list) ──
        self.recipient_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)

        # Filter row
        filter_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        self.filter_combo = Gtk.ComboBoxText()
        self.filter_combo.append_text("All Keys")
        self.filter_combo.append_text("Personal Keys")
        self.filter_combo.set_active(0)
        self.filter_combo.connect("changed", self._on_filter_changed)
        filter_row.pack_start(self.filter_combo, False, False, 0)

        search_label = Gtk.Label(label="Search for:")
        filter_row.pack_start(search_label, False, False, 0)

        self.search_entry = Gtk.Entry()
        self.search_entry.connect("changed", self._on_filter_changed)
        filter_row.pack_start(self.search_entry, True, True, 0)

        self.recipient_box.pack_start(filter_row, False, False, 0)

        # Key list: checkbox, Name, Key ID
        # Model: selected (bool), uid (str), keyid_short (str), keyid_full (str)
        self.key_store = Gtk.ListStore(bool, str, str, str)
        # Track seen keys to avoid duplicates (keys with multiple UIDs)
        seen_keys = set()
        for keyid, uid in public_keys:
            if keyid in seen_keys:
                continue
            seen_keys.add(keyid)
            short_id = keyid[-8:] if len(keyid) > 8 else keyid
            self.key_store.append([False, uid, short_id, keyid])

        self.key_filter = self.key_store.filter_new()
        self.key_filter.set_visible_func(self._key_visible_func)

        self.key_view = Gtk.TreeView(model=self.key_filter)
        self.key_view.set_headers_visible(True)
        self.key_view.get_selection().set_mode(Gtk.SelectionMode.SINGLE)

        # Checkbox column
        toggle_renderer = Gtk.CellRendererToggle()
        toggle_renderer.connect("toggled", self._on_key_toggled)
        col_check = Gtk.TreeViewColumn("", toggle_renderer, active=0)
        col_check.set_min_width(30)
        self.key_view.append_column(col_check)

        # Name column
        name_renderer = Gtk.CellRendererText()
        name_renderer.set_property("ellipsize", Pango.EllipsizeMode.END)
        col_name = Gtk.TreeViewColumn("Name", name_renderer, text=1)
        col_name.set_expand(True)
        col_name.set_resizable(True)
        col_name.set_sort_column_id(1)
        self.key_view.append_column(col_name)

        # Key ID column
        id_renderer = Gtk.CellRendererText()
        col_id = Gtk.TreeViewColumn("Key ID", id_renderer, text=2)
        col_id.set_min_width(80)
        self.key_view.append_column(col_id)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_shadow_type(Gtk.ShadowType.IN)
        scroll.add(self.key_view)
        self.recipient_box.pack_start(scroll, True, True, 0)

        content.pack_start(self.recipient_box, True, True, 0)

        # ── Sign message as ──
        sign_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        sign_label = Gtk.Label(label="Sign message as:")
        sign_box.pack_start(sign_label, False, False, 0)

        self.sign_combo = Gtk.ComboBoxText()
        self.sign_combo.append("none", "None (Don't Sign)")
        for keyid, uid in secret_keys:
            self.sign_combo.append(keyid, uid)
        self.sign_combo.set_active(0)
        sign_box.pack_start(self.sign_combo, True, True, 0)

        content.pack_start(sign_box, False, False, 8)

        self.show_all()

    def _on_mode_toggled(self, widget):
        use_recipients = self.radio_recipients.get_active()
        self.recipient_box.set_sensitive(use_recipients)

    def _on_filter_changed(self, widget):
        self.key_filter.refilter()

    def _key_visible_func(self, model, iter, data):
        uid = model[iter][1].lower()
        keyid = model[iter][3].lower()

        # Filter combo
        filter_idx = self.filter_combo.get_active()
        if filter_idx == 1:  # Personal Keys
            secret_ids = {k[0] for k in self.secret_keys}
            if model[iter][3] not in secret_ids:
                return False

        # Search text
        search = self.search_entry.get_text().strip().lower()
        if search:
            return search in uid or search in keyid

        return True

    def _on_key_toggled(self, renderer, path):
        # Convert filter path to store path
        filter_path = Gtk.TreePath.new_from_string(path)
        store_path = self.key_filter.convert_path_to_child_path(filter_path)
        if store_path:
            self.key_store[store_path][0] = not self.key_store[store_path][0]

    def get_results(self):
        """Return (mode, recipients_list, signer_keyid)."""
        if self.radio_passphrase.get_active():
            mode = "symmetric"
        else:
            mode = "recipients"

        recipients = []
        for row in self.key_store:
            if row[0]:  # checked
                recipients.append(row[3])  # full keyid

        signer = self.sign_combo.get_active_id()

        return mode, recipients, signer


def main():
    public_keys = get_gpg_keys("public")
    secret_keys = get_gpg_keys("secret")

    # Check for GPG errors
    if public_keys is None or secret_keys is None:
        md = Gtk.MessageDialog(
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="GPG Error",
            secondary_text="Failed to retrieve GPG keys. Please ensure GPG is installed and configured correctly."
        )
        md.run()
        md.destroy()
        return 1

    # Handle case where no keys exist (use symmetric encryption)
    if not public_keys and not secret_keys:
        print("MODE=symmetric", flush=True)
        print("RECIPIENTS=", flush=True)
        print("SIGNER=none", flush=True)
        return 0

    dialog = EncryptDialog(public_keys, secret_keys)
    response = dialog.run()
    dialog.hide()

    if response != Gtk.ResponseType.OK:
        return 1

    mode, recipients, signer = dialog.get_results()

    if mode == "recipients" and not recipients:
        md = Gtk.MessageDialog(
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK,
            text="No recipients selected."
        )
        md.run()
        md.destroy()
        return 1

    print(f"MODE={mode}", flush=True)
    print(f"RECIPIENTS={','.join(recipients)}", flush=True)
    print(f"SIGNER={signer}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
