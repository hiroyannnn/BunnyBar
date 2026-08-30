#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE_CACHE="/private/tmp/BunnyBarVerifyModuleCache"
BEHAVIOR_CHECK="/private/tmp/BunnyBarBehaviorRuntimeCheck"
GEOMETRY_CHECK="/private/tmp/BunnyBarRabbitSceneGeometryCheck"
MOTION_CHECK="/private/tmp/BunnyBarMotionCapture"
MOTION_SHEET="/private/tmp/BunnyBarNaturalHopMotionSheet.png"

cd "${ROOT_DIR}"

xcodebuild \
  -project BunnyBar/BunnyBar.xcodeproj \
  -scheme BunnyBar \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build

xcrun swiftc -warnings-as-errors \
  -module-cache-path "${MODULE_CACHE}" \
  -framework AppKit -framework Metal -framework SpriteKit \
  BunnyBar/Sources/BunnyBar/App/SystemMetrics.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitScene.swift \
  BunnyBar/Tests/RabbitBehaviorRuntimeCheck.swift \
  -o "${BEHAVIOR_CHECK}"
"${BEHAVIOR_CHECK}"

xcrun swiftc -warnings-as-errors \
  -module-cache-path "${MODULE_CACHE}" \
  -framework AppKit -framework SpriteKit \
  BunnyBar/Sources/BunnyBar/App/SystemMetrics.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitScene.swift \
  BunnyBar/Tests/RabbitSceneGeometryCheck.swift \
  -o "${GEOMETRY_CHECK}"
"${GEOMETRY_CHECK}"

xcrun swiftc -warnings-as-errors \
  -module-cache-path "${MODULE_CACHE}" \
  -framework AppKit -framework Metal -framework SpriteKit \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
  BunnyBar/Tests/RabbitMotionCapture.swift \
  -o "${MOTION_CHECK}"
"${MOTION_CHECK}" "${MOTION_SHEET}"

echo "PASS: BunnyBar build and deterministic checks"
