#!/usr/bin/env ruby

require "pathname"
require "xcodeproj"

root = Pathname(__dir__).join("..").expand_path
project_path = root.join("CyclixWatch.xcodeproj")
project_path.rmtree if project_path.exist?

project = Xcodeproj::Project.new(project_path.to_s)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2600"
project.root_object.attributes["LastUpgradeCheck"] = "2600"

source_group = project.main_group.new_group("CyclixWatch", root.to_s)
sources = source_group.new_group("Sources", root.join("Sources").to_s)
assets = source_group.new_file(root.join("Assets.xcassets").to_s)

target = project.new_target(
  :application,
  "CyclixWatch",
  :watchos,
  "10.0",
  project.products_group,
  :swift
)

[
  root.join("Sources/CyclixWatchApp.swift"),
  root.join("Sources/Models.swift"),
  root.join("Sources/Services.swift"),
  root.join("Sources/Views.swift"),
].each do |file_path|
  ref = sources.new_file(file_path.to_s)
  target.add_file_references([ref])
end

target.add_resources([assets])

project.build_configurations.each do |config|
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["DEVELOPMENT_TEAM"] = "944VS3P2G8"
end

target.build_configurations.each do |config|
  settings = config.build_settings
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["DEVELOPMENT_TEAM"] = "944VS3P2G8"
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Cyclix Watch"
  settings["INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription"] = "Cyclix necesita Bluetooth para desbloquear y bloquear bicicletas por BLE desde el Apple Watch."
  settings["INFOPLIST_KEY_NSLocationWhenInUseUsageDescription"] = "Cyclix necesita tu ubicación para validar zonas y mostrar la estación más cercana."
  settings["INFOPLIST_KEY_WKApplication"] = "YES"
  settings["INFOPLIST_KEY_WKCompanionAppBundleIdentifier"] = "com.example.cyclixMapaDetalle"
  settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/Frameworks"
  settings["MARKETING_VERSION"] = "1.0"
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.cyclixMapaDetalle.watchkitapp"
  settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  settings["SDKROOT"] = "watchos"
  settings["SKIP_INSTALL"] = "NO"
  settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
  settings["SWIFT_VERSION"] = "5.0"
  settings["TARGETED_DEVICE_FAMILY"] = "4"
  settings["WATCHOS_DEPLOYMENT_TARGET"] = "10.0"
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: target)
scheme.save_as(project_path.to_s, "CyclixWatch", true)

project.save
