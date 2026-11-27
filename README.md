# Family

A co-op psychological horror game built with Godot 4 (Mobile / Vulkan) featuring cross-platform multiplayer (PC & Android), WebRTC proximity voice chat, adaptive noise detection mechanics, and atmospheric multi-tool exploration.

## Features
- **Cross-Platform Multiplayer**: Seamless room-code lobby and peer-to-peer gameplay across PC and Android mobile devices.
- **Proximity Voice Chat**: In-game spatial audio with real-time mic calibration and noise threshold detection.
- **Dynamic Loudness Meter**: Responsive UI sound meter detecting player movement, tool switching clicks, and proximity voice chat.
- **Atmospheric Lighting**: Flashlights, UV blacklight clues, and manual cranking recharge mechanics with third-person aim synchronization.

## Architecture
- **Game Client**: Godot Engine 4 (GDScript)
- **Signaling Server**: Node.js WebSocket signaling server hosted on Render ([family-server](https://github.com/syzhn321-svg/family-server))
- **Networking**: WebSockets for matchmaking & WebRTC / ENet relay for real-time synchronization.

## Building & Running
- **Godot Version**: Godot 4.x (Forward+ / Mobile)
- **Main Scene**: `res://scenes/main_menu.tscn`
- **Android Export**: Configured in `export_presets.cfg`
