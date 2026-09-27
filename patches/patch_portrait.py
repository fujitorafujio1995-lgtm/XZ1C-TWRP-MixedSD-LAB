#!/usr/bin/env python3
import pathlib, sys, re

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_portrait.py portrait.xml ui.xml")
portrait = pathlib.Path(sys.argv[1])
ui = pathlib.Path(sys.argv[2])
p = portrait.read_text()
u = ui.read_text()

vars_xml = """
<variable name="tw_xz1c_sd_loaded" value="0"/>
<variable name="tw_xz1c_sd_total_gib" value="0"/>
<variable name="tw_xz1c_sd_total_display" value="Not loaded"/>
<variable name="tw_xz1c_sd_status" value="Insert SD card and press Load SD"/>
<variable name="tw_xz1c_sd_layout" value="none"/>
<variable name="tw_xz1c_internal_gib" value="8"/>
<variable name="tw_xz1c_portable_gib" value="8"/>
<variable name="tw_xz1c_sd_device" value="/dev/block/mmcblk0"/>
<variable name="tw_xz1c_sd_sector" value="512"/>
<variable name="tw_xz1c_sd_bytes" value="0"/>
"""
if "tw_xz1c_sd_total_gib" not in u:
    u = u.replace("</variables>", vars_xml + "\n</variables>", 1)

entry = """
<button style="main_button">
<placement x="%indent%" y="%row17_y%"/>
<text>Partition the memory card</text>
<actions><action function="page">xz1c_sd_menu</action></actions>
</button>
"""
if "Partition the memory card" not in p:
    marker = p.find('<page name="advanced">')
    if marker < 0:
        raise SystemExit("advanced page not found")
    insert = p.find("<template", marker)
    p = p[:insert] + entry + p[insert:]

for name in ("xz1c_sd_menu","xz1c_sd_load_action","xz1c_sd_loaded","xz1c_sd_config"):
    p = re.sub(r'\n<page name="' + name + r'">.*?</page>\n', '\n', p, flags=re.S)

pages = """
<page name="xz1c_sd_menu">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Partition the memory card</text></text>
<text style="text_m"><placement x="%indent%" y="%row5_y%"/><text>Read the real SD card before choosing sizes.</text></text>

<button style="main_button">
<placement x="%indent%" y="%row8_y%"/><text>Format SD</text>
<actions>
<action function="set">tw_back=xz1c_sd_menu</action>
<action function="set">tw_action=cmd</action>
<action function="set">tw_action_param=/sbin/xz1c_mixed_sd_format.sh</action>
<action function="set">tw_action_text1=Clearing SD...</action>
<action function="set">tw_complete_text1=SD cleared</action>
<action function="set">tw_slider_text=Swipe to Confirm</action>
<action function="page">confirm_action</action>
</actions>
</button>

<button style="main_button">
<placement x="%indent%" y="%row12_y%"/><text>Load SD</text>
<actions>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_probe.sh</action>
<action function="set">tw_action_param=</action>
<action function="set">tw_action_text1=Reading SD...</action>
<action function="set">tw_complete_text1=SD read complete</action>
<action function="set">tw_back=xz1c_sd_menu</action>
<action function="page">xz1c_sd_load_action</action>
</actions>
</button>

<text style="text_m"><placement x="%indent%" y="%row16_y%"/><text>%tw_xz1c_sd_status%</text></text>
<action function="page">advanced</action>
</page>

<page name="xz1c_sd_load_action">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Loading SD information...</text></text>
<template name="console"/>
<action>
<condition var1="tw_operation_state" var2="1"/>
<actions><action function="page">xz1c_sd_loaded</action></actions>
</action>
<action>
<condition var1="tw_operation_state" op="!=" var2="1"/>
<actions><action function="%tw_action%">%tw_action_param%</action></actions>
</action>
</page>

<page name="xz1c_sd_loaded">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>SD card detected</text></text>
<text style="text_m"><placement x="%indent%" y="%row5_y%"/><text>Capacity: %tw_xz1c_sd_total_display%</text></text>
<text style="text_m"><placement x="%indent%" y="%row7_y%"/><text>Device: %tw_xz1c_sd_device%</text></text>
<text style="text_m"><placement x="%indent%" y="%row9_y%"/><text>Layout: %tw_xz1c_sd_layout%</text></text>

<condition var1="tw_xz1c_sd_layout" var2="mixed"/>
<button style="main_button">
<placement x="%indent%" y="%row13_y%"/><text>Use as internal storage</text>
<actions>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_use_internal.sh</action>
<action function="set">tw_action_param=</action>
<action function="set">tw_action_text1=Checking adopted layout...</action>
<action function="set">tw_complete_text1=Check complete</action>
<action function="set">tw_back=xz1c_sd_loaded</action>
<action function="page">action_page</action>
</actions>
</button>
</condition>

<condition var1="tw_xz1c_sd_layout" op="!=" var2="mixed"/>
<button style="main_button">
<placement x="%indent%" y="%row13_y%"/><text>Create partitions</text>
<actions><action function="page">xz1c_sd_config</action></actions>
</button>
</condition>
<action function="page">xz1c_sd_menu</action>
</page>

<page name="xz1c_sd_config">
<template name="page"/>
<text style="text_l"><placement x="%col1_x_header%" y="%row3_header_y%"/><text>Partition the memory card</text></text>
<text style="text_m"><placement x="%indent%" y="%row5_y%"/><text>Total: %tw_xz1c_sd_total_display%</text></text>

<slidervalue>
<placement x="indent" y="%row8_y%" w="%content_width%"/>
<text>Internal / Adopted: %tw_xz1c_internal_gib% GiB</text>
<data variable="tw_xz1c_internal_gib" min="8" max="%tw_xz1c_sd_total_gib%"/>
<actions><action function="compute">tw_xz1c_portable_gib=%tw_xz1c_sd_total_gib%-tw_xz1c_internal_gib</action></actions>
</slidervalue>

<input>
<placement x="%indent%" y="%row12_y%" w="%content_width%"/>
<text>Internal GiB</text>
<data variable="tw_xz1c_internal_gib"/>
<restrict minlen="1" maxlen="5" allow="0123456789"/>
<actions><action function="compute">tw_xz1c_portable_gib=%tw_xz1c_sd_total_gib%-tw_xz1c_internal_gib</action></actions>
</input>

<text style="text_m"><placement x="%indent%" y="%row15_y%"/><text>Portable: %tw_xz1c_portable_gib% GiB</text></text>
<text style="text_m"><placement x="%indent%" y="%row17_y%"/><text>Portable is always Total - Internal.</text></text>

<button style="main_button">
<placement x="%indent%" y="%row20_y%"/><text>Create partitions</text>
<actions>
<action function="set">tw_back=xz1c_sd_loaded</action>
<action function="set">tw_action=/sbin/xz1c_mixed_sd_partition.sh</action>
<action function="set">tw_action_param=%tw_xz1c_internal_gib% %tw_xz1c_portable_gib%</action>
<action function="set">tw_action_text1=Creating GPT...</action>
<action function="set">tw_complete_text1=Partitions created</action>
<action function="set">tw_show_reboot=1</action>
<action function="page">action_page</action>
</actions>
</button>
<action function="page">xz1c_sd_loaded</action>
</page>
"""
p += pages
portrait.write_text(p)
ui.write_text(u)
