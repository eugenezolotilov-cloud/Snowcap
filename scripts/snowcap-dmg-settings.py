# Usage: dmgbuild -s scripts/snowcap-dmg-settings.py -D app=<Snowcap.app> -D background=<background.tiff> Snowcap <output.dmg>
import os.path

app = defines["app"]
background = defines["background"]
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon_locations = {os.path.basename(app): (174, 229), "Applications": (486, 229)}
window_rect = ((200, 160), (660, 410))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
icon_size = 96
text_size = 13
arrange_by = None
