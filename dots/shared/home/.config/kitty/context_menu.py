#!/usr/bin/python3
# right-click GTK4 popup menu

import subprocess
import os

# single instance is handled by the launcher

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib


CSS = """
window.context-menu {
    background-color: #0f1416;
    border: 2px solid #86d1e9;
    border-radius: 10px;
    padding: 4px 0;
}
window.context-menu .title-label {
    color: #86d1e9;
    font-weight: bold;
    font-size: 13px;
    padding: 6px 16px 4px 16px;
}
window.context-menu .menu-row {
    padding: 6px 16px;
    border-radius: 6px;
    margin: 1px 6px;
    transition: background-color 100ms;
}
window.context-menu .menu-row:hover {
    background-color: #004e5e;
}
window.context-menu .menu-row .icon-label {
    color: #b2cad3;
    font-size: 18px;
    min-width: 28px;
}
window.context-menu .menu-row:hover .icon-label {
    color: #ff71bc;
}
window.context-menu .menu-row .text-label {
    color: #dee3e6;
    font-size: 14px;
}
window.context-menu .menu-row:hover .text-label {
    color: #b2ebff;
    font-weight: bold;
}
window.context-menu .sep {
    min-height: 1px;
    background-color: #344a52;
    margin: 3px 14px;
    opacity: 0.35;
}
"""

def find_kitty_socket():
    try:
        r = subprocess.run(['pgrep', '-x', 'kitty'],
                           capture_output=True, text=True, timeout=2)
        for pid in r.stdout.strip().split('\n'):
            pid = pid.strip()
            if pid:
                return f'unix:@kitty-{pid}'
    except Exception:
        pass
    return None


def kcmd(*args):
    sock = find_kitty_socket()
    if not sock:
        return
    subprocess.Popen(['kitty', '@', '--to', sock] + list(args),
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def do_copy():
    sock = find_kitty_socket()
    if not sock:
        return
    try:
        r = subprocess.run(
            ['kitty', '@', '--to', sock, 'get-text', '--extent=selection'],
            capture_output=True, text=True, timeout=3)
        if r.stdout.strip():
            subprocess.run(['wl-copy'], input=r.stdout, text=True,
                           capture_output=True, timeout=3)
    except Exception:
        pass


# (icon, label, callback) or None = separator
MENU = [
    ('\U000F0190', 'Copy',            do_copy),
    ('\U000F0192', 'Paste',           lambda: kcmd('send-key', 'ctrl+shift+v')),
    ('\U000F0193', 'Paste Sel',       lambda: kcmd('paste-from-selection')),
    None,
    ('\U000F0425', 'New Tab',         lambda: kcmd('launch', '--type=tab', '--cwd=current')),
    ('\U000F0425', 'New Window',      lambda: kcmd('launch', '--cwd=current')),
    ('\U000F0156', 'Close Tab',       lambda: kcmd('close-tab')),
    None,
    ('\U000F0485', 'Split V',         lambda: kcmd('launch', '--cwd=current', '--location=vsplit')),
    ('\U000F0484', 'Split H',         lambda: kcmd('launch', '--cwd=current', '--location=hsplit')),
    None,
    ('\U000F005D', 'Scroll Up',       lambda: kcmd('scroll-window', '3')),
    ('\U000F005E', 'Scroll Down',     lambda: kcmd('scroll-window', '-3')),
    ('\U000F005C', 'Top',             lambda: kcmd('scroll-window', 'start')),
    None,
    ('\U000F0234', 'Clear',           lambda: kcmd('send-text', 'clear\n')),
    ('\U000F0453', 'Reload Cfg',      lambda: kcmd('load-config')),
    None,
    ('\U000F024B', 'Yazi',            lambda: kcmd('launch', '--cwd=current', '--type=window', 'yazi')),
]


class MenuWindow(Gtk.ApplicationWindow):

    def __init__(self, app):
        super().__init__(application=app)
        self.add_css_class('context-menu')
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(260, -1)
        self.set_title('kitty_context_menu')

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        title = Gtk.Label(label='Context Menu')
        title.add_css_class('title-label')
        title.set_halign(Gtk.Align.START)
        vbox.append(title)

        for item in MENU:
            if item is None:
                sep = Gtk.Box()
                sep.add_css_class('sep')
                vbox.append(sep)
                continue

            icon_str, label_str, cb = item
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.add_css_class('menu-row')

            icon = Gtk.Label(label=icon_str)
            icon.add_css_class('icon-label')
            icon.set_halign(Gtk.Align.CENTER)
            icon.set_size_request(22, -1)

            label = Gtk.Label(label=label_str)
            label.add_css_class('text-label')
            label.set_halign(Gtk.Align.START)
            label.set_hexpand(True)

            row.append(icon)
            row.append(label)

            gesture = Gtk.GestureClick()
            gesture.connect('released', self._on_item_click, cb)
            row.add_controller(gesture)

            vbox.append(row)

        self.set_child(vbox)

        key_ctl = Gtk.EventControllerKey()
        key_ctl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctl)

        self._alive = True
        # focus_leave fires too early, so close on Escape, click or timeout
        GLib.timeout_add(8000, self._timeout)

    def _on_item_click(self, gesture, n_press, x, y, callback):
        self._alive = False
        self.close()
        GLib.timeout_add(50, lambda: (callback(), False)[-1])

    def _on_key(self, ctl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self._alive = False
            self.close()
            return True
        return False

    def _timeout(self):
        if self._alive:
            self._alive = False
            self.close()
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='dev.kitty.context.menu')

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        win = MenuWindow(self)
        win.present()


if __name__ == '__main__':
    App().run([])
