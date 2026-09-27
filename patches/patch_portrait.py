#!/usr/bin/env python3
import pathlib, re, sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_portrait.py portrait.xml ui.xml")

portrait = pathlib.Path(sys.argv[1])
ui = pathlib.Path(sys.argv[2])
p = portrait.read_text()
u = ui.read_text()

# Remove only pages/variables owned by this patch. Stock pages are not touched.
for name in ("xz1c_sd_menu", "xz1c_sd_config", "xz1c_sd_format"):
    p = re.sub(
        r'\n?\s*<page\s+name="' + re.escape(name) + r'">.*?</page>\s*',
        "\n", p, flags=re.S)

for name in (
    "tw_xz1c_sd_loaded", "tw_xz1c_sd_total_gib",
    "tw_xz1c_sd_total_display", "tw_xz1c_sd_status",
    "tw_xz1c_sd_layout", "tw_xz1c_sd_alloc_gib",
    "tw_xz1c_sd_device", "tw_xz1c_sd_sector", "tw_xz1c_sd_bytes",
    "tw_xz1c_sd_app_gib", "tw_xz1c_sd_public_gib",
    "tw_xz1c_sd_swap_gib", "tw_xz1c_sd_app_on",
    "tw_xz1c_sd_public_on", "tw_xz1c_sd_swap_on",
):
    u = re.sub(
        r'\n?\s*<variable\s+name="' + re.escape(name) + r'"[^>]*/>\s*',
        "\n", u)

if "</variables>" not in u:
    raise SystemExit("ui.xml: </variables> not found")

vars_xml = """
<variable name="tw_xz1c_sd_loaded" value="0"/>
<variable name="tw_xz1c_sd_total_gib" value="0"/>
<variable name="tw_xz1c_sd_total_display" value="Not loaded"/>
<variable name="tw_xz1c_sd_status" value="Insert SD card and press Load SD"/>
<variable name="tw_xz1c_sd_layout" value="none"/>
<variable name="tw_xz1c_sd_alloc_gib" value="0"/>
<variable name="tw_xz1c_sd_device" value="/dev/block/mmcblk0"/>
<variable name="tw_xz1c_sd_sector" value="512"/>
<variable name="tw_xz1c_sd_bytes" value="0"/>
<variable name="tw_xz1c_sd_app_gib" value="0"/>
<variable name="tw_xz1c_sd_public_gib" value="0"/>
<variable name="tw_xz1c_sd_swap_gib" value="0"/>
<variable name="tw_xz1c_sd_app_on" value="1"/>
<variable name="tw_xz1c_sd_public_on" value="1"/>
<variable name="tw_xz1c_sd_swap_on" value="0"/>
"""
u = u.replace("</variables>", vars_xml + "\n</variables>", 1)

# Follow the proven baseline insertion strategy: put the new entry into Advanced,
# immediately after its template. This does not alter stock Partition SD Card or
# Reload Theme controls.
if "Partition the memory card" not in p:
    marker = '<page name="advanced">'
    pos = p.find(marker)
    if pos < 0:
        raise SystemExit("advanced page not found")
    insert = p.find("<template", pos)
    if insert < 0:
        raise SystemExit("advanced template not found")
    insert_end = p.find(">", insert) + 1
    entry = """
<listitem name="Partition the memory card">
<actions><action function="page">xz1c_sd_menu</action></actions>
</listitem>
"""
    p = p[:insert_end] + entry + p[insert_end:]

pages = r"""
<page name="xz1c_sd_menu">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Partition the memory card</text></text>
<text style="text_m"><placement x="%indent%" y="%row5_y%"/><text>%tw_xz1c_sd_status%</text></text>

<button style="main_button">
<placement x="%indent%" y="%row8_y%"/><text>Load SD</text>
<actions>
<action function="set">tw_back=xz1c_sd_menu</action>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_probe.sh</action>
<action function="set">tw_action_param=</action>
<action function="set">tw_action_text1=Reading SD card...</action>
<action function="set">tw_complete_text1=SD card loaded</action>
<action function="page">action_page</action>
</actions>
</button>

<button style="main_button">
<placement x="%indent%" y="%row12_y%"/><text>Configure Mixed SD</text>
<actions><action function="page">xz1c_sd_config</action></actions>
</button>

<button style="main_button">
<placement x="%indent%" y="%row16_y%"/><text>Format SD</text>
<actions><action function="page">xz1c_sd_format</action></actions>
</button>

<button style="main_button">
<placement x="%indent%" y="%row20_y%"/><text>Back</text>
<actions><action function="page">advanced</action></actions>
</button>
</page>

<page name="xz1c_sd_config">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Configure Mixed SD</text></text>
<text style="text_m"><placement x="%indent%" y="%row5_y%"/><text>Total usable: %tw_xz1c_sd_alloc_gib% GiB</text></text>

<!-- Checkbox state. Tapping the checkbox toggles the matching *_on variable.
     Disabled regions are assigned 0 GiB by the redistribution actions. -->
<button style="main_button">
<placement x="%indent%" y="%row7_y%"/>
<text>[✓] App / Internal   F2FS   %tw_xz1c_sd_app_gib% GiB</text>
<actions>
<action function="toggle">tw_xz1c_sd_app_on</action>
<action function="compute">tw_xz1c_sd_app_gib=0</action>
<action function="compute">tw_xz1c_sd_public_gib=%tw_xz1c_sd_alloc_gib%</action>
<action function="compute">tw_xz1c_sd_swap_gib=0</action>
</actions>
</button>

<slidervalue>
<placement x="%indent%" y="%row9_y%" w="%content_width%"/>
<text>App / Internal: %tw_xz1c_sd_app_gib% GiB</text>
<data variable="tw_xz1c_sd_app_gib" min="0" max="%tw_xz1c_sd_alloc_gib%"/>
<actions>
<action function="compute">tw_xz1c_sd_public_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%)*%tw_xz1c_sd_public_on%/((%tw_xz1c_sd_public_on%)+(%tw_xz1c_sd_swap_on%))</action>
<action function="compute">tw_xz1c_sd_swap_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%-%tw_xz1c_sd_public_gib</action>
</actions>
</slidervalue>

<input>
<placement x="%indent%" y="%row11_y%" w="%content_width%"/>
<text>App / Internal GiB</text>
<data variable="tw_xz1c_sd_app_gib"/>
<restrict minlen="1" maxlen="5" allow="0123456789"/>
<actions>
<action function="compute">tw_xz1c_sd_public_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%)*%tw_xz1c_sd_public_on%/((%tw_xz1c_sd_public_on%)+(%tw_xz1c_sd_swap_on%))</action>
<action function="compute">tw_xz1c_sd_swap_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%-%tw_xz1c_sd_public_gib</action>
</actions>
</input>

<button style="main_button">
<placement x="%indent%" y="%row14_y%"/>
<text>[✓] Download / Public   exFAT   %tw_xz1c_sd_public_gib% GiB</text>
<actions>
<action function="toggle">tw_xz1c_sd_public_on</action>
<action function="compute">tw_xz1c_sd_public_gib=0</action>
<action function="compute">tw_xz1c_sd_app_gib=%tw_xz1c_sd_alloc_gib%/2</action>
<action function="compute">tw_xz1c_sd_swap_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%</action>
</actions>
</button>

<slidervalue>
<placement x="%indent%" y="%row16_y%" w="%content_width%"/>
<text>Download / Public: %tw_xz1c_sd_public_gib% GiB</text>
<data variable="tw_xz1c_sd_public_gib" min="0" max="%tw_xz1c_sd_alloc_gib%"/>
<actions>
<action function="compute">tw_xz1c_sd_app_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_public_gib%)*%tw_xz1c_sd_app_on%/((%tw_xz1c_sd_app_on%)+(%tw_xz1c_sd_swap_on%))</action>
<action function="compute">tw_xz1c_sd_swap_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_public_gib%-%tw_xz1c_sd_app_gib</action>
</actions>
</slidervalue>

<input>
<placement x="%indent%" y="%row18_y%" w="%content_width%"/>
<text>Download / Public GiB</text>
<data variable="tw_xz1c_sd_public_gib"/>
<restrict minlen="1" maxlen="5" allow="0123456789"/>
<actions>
<action function="compute">tw_xz1c_sd_app_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_public_gib%)*%tw_xz1c_sd_app_on%/((%tw_xz1c_sd_app_on%)+(%tw_xz1c_sd_swap_on%))</action>
<action function="compute">tw_xz1c_sd_swap_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_public_gib%-%tw_xz1c_sd_app_gib</action>
</actions>
</input>

<button style="main_button">
<placement x="%indent%" y="%row21_y%"/>
<text>[ ] Swap   Linux swap   %tw_xz1c_sd_swap_gib% GiB</text>
<actions>
<action function="toggle">tw_xz1c_sd_swap_on</action>
<action function="compute">tw_xz1c_sd_swap_gib=0</action>
<action function="compute">tw_xz1c_sd_app_gib=%tw_xz1c_sd_alloc_gib%/2</action>
<action function="compute">tw_xz1c_sd_public_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_app_gib%</action>
</actions>
</button>

<slidervalue>
<placement x="%indent%" y="%row23_y%" w="%content_width%"/>
<text>Swap: %tw_xz1c_sd_swap_gib% GiB</text>
<data variable="tw_xz1c_sd_swap_gib" min="0" max="%tw_xz1c_sd_alloc_gib%"/>
<actions>
<action function="compute">tw_xz1c_sd_app_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_swap_gib%)*%tw_xz1c_sd_app_on%/((%tw_xz1c_sd_app_on%)+(%tw_xz1c_sd_public_on%))</action>
<action function="compute">tw_xz1c_sd_public_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_swap_gib%-%tw_xz1c_sd_app_gib</action>
</actions>
</slidervalue>

<input>
<placement x="%indent%" y="%row25_y%" w="%content_width%"/>
<text>Swap GiB</text>
<data variable="tw_xz1c_sd_swap_gib"/>
<restrict minlen="1" maxlen="5" allow="0123456789"/>
<actions>
<action function="compute">tw_xz1c_sd_app_gib=(%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_swap_gib%)*%tw_xz1c_sd_app_on%/((%tw_xz1c_sd_app_on%)+(%tw_xz1c_sd_public_on%))</action>
<action function="compute">tw_xz1c_sd_public_gib=%tw_xz1c_sd_alloc_gib%-%tw_xz1c_sd_swap_gib%-%tw_xz1c_sd_app_gib</action>
</actions>
</input>

<text style="text_m"><placement x="%indent%" y="%row28_y%"/><text>SUM: %tw_xz1c_sd_app_gib% + %tw_xz1c_sd_public_gib% + %tw_xz1c_sd_swap_gib% GiB</text></text>

<button style="main_button">
<placement x="%indent%" y="%row31_y%"/>
<text>Wipe &amp; Create Mixed SD</text>
<actions>
<action function="set">tw_back=xz1c_sd_config</action>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_partition.sh</action>
<action function="set">tw_action_param=%tw_xz1c_sd_app_gib% %tw_xz1c_sd_public_gib% %tw_xz1c_sd_swap_gib% f2fs</action>
<action function="set">tw_action_text1=Wiping and creating Mixed SD...</action>
<action function="set">tw_complete_text1=Mixed SD layout created</action>
<action function="set">tw_slider_text=Swipe to Confirm</action>
<action function="page">confirm_action</action>
</actions>
</button>

<button style="main_button">
<placement x="%indent%" y="%row34_y%"/><text>Back</text>
<actions><action function="page">xz1c_sd_menu</action></actions>
</button>
</page>

<page name="xz1c_sd_format">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Format SD</text></text>
<text style="text_m"><placement x="%indent%" y="%row6_y%"/><text>Use the current Mixed SD configuration.</text></text>
<text style="text_m"><placement x="%indent%" y="%row9_y%"/><text>GREEN F2FS: %tw_xz1c_sd_app_gib%  YELLOW exFAT: %tw_xz1c_sd_public_gib%  RED swap: %tw_xz1c_sd_swap_gib%</text></text>
<button style="main_button">
<placement x="%indent%" y="%row14_y%"/><text>Confirm Format SD</text>
<actions>
<action function="set">tw_back=xz1c_sd_format</action>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_partition.sh</action>
<action function="set">tw_action_param=%tw_xz1c_sd_app_gib% %tw_xz1c_sd_public_gib% %tw_xz1c_sd_swap_gib% f2fs</action>
<action function="set">tw_action_text1=Formatting SD card...</action>
<action function="set">tw_complete_text1=SD card formatted</action>
<action function="set">tw_slider_text=Swipe to Confirm</action>
<action function="page">confirm_action</action>
</actions>
</button>
<button style="main_button">
<placement x="%indent%" y="%row18_y%"/><text>Back</text>
<actions><action function="page">xz1c_sd_menu</action></actions>
</button>
</page>
"""
p += "\n" + pages
portrait.write_text(p)
ui.write_text(u)
