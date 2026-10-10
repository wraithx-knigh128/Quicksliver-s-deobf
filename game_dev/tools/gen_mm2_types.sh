#!/bin/sh
# Regenerates tests/prop_types_mm2.lua (run from game_dev/). API-Dump.json:
#   curl -L -o /tmp/API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
DUMP=${1:-/tmp/API-Dump.json}
python3 tools/gen_member_types.py "$DUMP" mm2/ui_lib.lua mm2/mm2_hub.lua mm2/logic.lua -- DataModel Players Workspace RunService UserInputService \
  TweenService StarterGui HttpService ReplicatedStorage VirtualInputManager VirtualUser TeleportService CoreGui GuiService Stats StatsItem PlayerGui \
  Part MeshPart Model Humanoid Tool Camera RemoteEvent RemoteFunction Backpack Player Accessory Folder > tests/prop_types_mm2.lua
