#!/bin/sh
# Regenerates the strict Roblox API tables of the Tech Lab tests (run from game_dev/). API-Dump.json:
#   curl -L -o /tmp/API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
#   tests/prop_types_tsb.lua      the engine on its own (tests/tsb_lab_tests.lua)   - the extra services are what the shared fake world creates
#   tests/prop_types_tsb_hub.lua  the WindUI hub (tests/tsb_hub_tests.lua): + the window library and the Wraith UI core
#   tests/prop_types_classic.lua  the classic hub on WindUI (tests/classic_tests.lua): its own menu + every module bundled into it
DUMP=${1:-/tmp/API-Dump.json}
EXTRA="DataModel Players Workspace RunService UserInputService VirtualInputManager Part Model Humanoid Animator Animation AnimationTrack Tool Camera RemoteEvent Backpack Player Folder \
  Highlight Attachment LinearVelocity BodyPosition BodyGyro BodyVelocity AlignPosition AlignOrientation BillboardGui TextLabel CoreGui ReplicatedStorage StarterGui HttpService \
  TeleportService GuiService TweenService Stats StatsItem VirtualUser"
python3 tools/gen_member_types.py "$DUMP" tech_lab.lua tech_data.lua tech_math.lua tech_options.lua tests/tsb_sim.lua tests/tsb_lab_tests.lua -- $EXTRA > tests/prop_types_tsb.lua
python3 tools/gen_member_types.py "$DUMP" tech_lab.lua tech_data.lua tech_math.lua tech_options.lua ping_model.lua tsb/lab_hub.lua mm2/ui_lib.lua mm2/windui_ui.lua mm2/vendor/windui.lua \
  tests/tsb_sim.lua tests/tsb_hub_tests.lua --quoted -- $EXTRA PlayerGui Frame ScreenGui TextService LocalizationService Lighting ContextActionService MarketplaceService SoundService \
  MeshPart Accessory > tests/prop_types_tsb_hub.lua
python3 tools/gen_member_types.py "$DUMP" ../tsb_animation_hub.lua classic_wind.lua tech_lab.lua tech_data.lua tech_math.lua tech_options.lua ping_model.lua drag_tracker.lua combo_options.lua assist.lua combat_math.lua \
  block_state.lua block_predict.lua block_info.lua kyoto_plan.lua block_sense.lua combo_engine.lua tsb_data.lua mm2/ui_lib.lua mm2/windui_ui.lua mm2/vendor/windui.lua \
  tests/tsb_sim.lua tests/classic_tests.lua --quoted -- $EXTRA PlayerGui Frame ScreenGui TextService LocalizationService Lighting ContextActionService MarketplaceService SoundService \
  MeshPart Accessory CanvasGroup ScrollingFrame TextButton TextBox ImageLabel UIScale UIStroke UICorner UIGradient UIListLayout UIPadding SpawnLocation > tests/prop_types_classic.lua
