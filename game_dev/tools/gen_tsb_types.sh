#!/bin/sh
# Regenerates tests/prop_types_tsb.lua (run from game_dev/) - the strict Roblox API tables of the Tech Lab tests (the extra services are what the shared fake world creates). API-Dump.json:
#   curl -L -o /tmp/API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
DUMP=${1:-/tmp/API-Dump.json}
python3 tools/gen_member_types.py "$DUMP" tech_lab.lua tech_data.lua tech_math.lua tech_options.lua tests/tsb_sim.lua tests/tsb_lab_tests.lua -- DataModel Players Workspace RunService UserInputService \
  VirtualInputManager Part Model Humanoid Animator Animation AnimationTrack Tool Camera RemoteEvent Backpack Player Folder Highlight Attachment LinearVelocity BodyPosition BodyGyro \
  BodyVelocity AlignPosition AlignOrientation CoreGui ReplicatedStorage StarterGui HttpService TeleportService GuiService TweenService Stats StatsItem VirtualUser \
  > tests/prop_types_tsb.lua
