#!/usr/bin/env python3
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="replace")
marker = "XZ1C_MIXED_SD_LAB_V1"
if marker in s:
    print("portrait.xml already patched")
    raise SystemExit(0)

anchor = '\t\t\t\t<listitem name="{@part_sd_btn=Partition SD Card}">'
if anchor not in s:
    raise SystemExit("ERROR: expected Partition SD Card Advanced-menu entry not found")

item = '''\t\t\t\t<!-- XZ1C_MIXED_SD_LAB_V1 -->
\t\t\t\t<listitem name="XZ1C Mixed Adoptable SD (LAB)">
\t\t\t\t\t<actions>
\t\t\t\t\t\t<action function="set">tw_back=advanced</action>
\t\t\t\t\t\t<action function="page">xz1c_mixed_sd</action>
\t\t\t\t\t</actions>
\t\t\t\t</listitem>
'''
s = s.replace(anchor, item + anchor, 1)

page_anchor = '\t\t<page name="partsdcardsel">'
if page_anchor not in s:
    raise SystemExit("ERROR: expected partsdcardsel page not found")

page = '''\n\t\t<!-- XZ1C_MIXED_SD_LAB_V1 -->
\t\t<page name="xz1c_mixed_sd">
\t\t\t<template name="page"/>

\t\t\t<text style="text_l">
\t\t\t\t<placement x="%col1_x_header%" y="%row3_header_y%"/>
\t\t\t\t<text>XZ1C Mixed Adoptable SD</text>
\t\t\t</text>

\t\t\t<text style="text_m_fail">
\t\t\t\t<placement x="%center_x%" y="%row2_y%" placement="5"/>
\t\t\t\t<text>LAB inspection mode - no partition changes</text>
\t\t\t</text>

\t\t\t<text style="text_m">
\t\t\t\t<placement x="%indent%" y="%row4_y%"/>
\t\t\t\t<text>Target: removable SD (/dev/block/mmcblk0)</text>
\t\t\t</text>

\t\t\t<text style="text_m">
\t\t\t\t<placement x="%indent%" y="%row5_y%"/>
\t\t\t\t<text>Read-only capacity and GPT inspection</text>
\t\t\t</text>

\t\t\t<button style="main_button_half_height">
\t\t\t\t<placement x="%indent%" y="%row10_y%"/>
\t\t\t\t<text>Inspect SD / GPT</text>
\t\t\t\t<actions>
\t\t\t\t\t<action function="set">tw_back=xz1c_mixed_sd</action>
\t\t\t\t\t<action function="set">tw_action=cmd</action>
\t\t\t\t\t<action function="set">tw_action_param=/system/bin/xz1c_mixed_sd_inspect.sh</action>
\t\t\t\t\t<action function="set">tw_action_text1=Inspecting SD card...</action>
\t\t\t\t\t<action function="set">tw_complete_text1=Inspection complete</action>
\t\t\t\t\t<action function="set">tw_has_action2=0</action>
\t\t\t\t\t<action function="page">action_page</action>
\t\t\t\t</actions>
\t\t\t</button>

\t\t\t<button style="main_button_half_height">
\t\t\t\t<placement x="%center_x%" y="%row10_y%"/>
\t\t\t\t<text>Back</text>
\t\t\t\t<action function="page">advanced</action>
\t\t\t</button>

\t\t\t<action>
\t\t\t\t<touch key="back"/>
\t\t\t\t<action function="page">advanced</action>
\t\t\t</action>
\t\t</page>

'''
s = s.replace(page_anchor, page + page_anchor, 1)
p.write_text(s, encoding="utf-8")
print("patched", p)
