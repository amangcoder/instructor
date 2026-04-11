#!/usr/bin/env ruby
# add_widget_extension.rb — TASK-017
#
# Adds the InstructorWidget WidgetKit extension to the Xcode project.
# Run once from the ios/ directory:
#
#   cd ios && ruby add_widget_extension.rb
#
# Prerequisites:
#   gem install xcodeproj
#
# What this script does:
#   1. Opens Runner.xcodeproj
#   2. Creates an "InstructorWidget" App Extension target
#   3. Adds all Swift source files from ./InstructorWidget/
#   4. Configures build settings (bundle ID, deployment target, entitlements)
#   5. Adds App Groups entitlement to the Runner target
#   6. Adds WidgetKit + SwiftUI frameworks to the widget target
#   7. Embeds the extension in the Runner app bundle
#   8. Saves the project

require 'xcodeproj'

PROJECT_PATH       = File.expand_path('../Runner.xcodeproj', __FILE__)
WIDGET_DIR         = File.expand_path('../InstructorWidget', __FILE__)
APP_GROUP          = 'group.com.layersiq.instructor'
BUNDLE_ID_PREFIX   = 'com.layersiq.instructor'
WIDGET_BUNDLE_ID   = "#{BUNDLE_ID_PREFIX}.InstructorWidget"
IOS_DEPLOYMENT     = '16.0'
SWIFT_VERSION      = '5.9'

puts "Opening #{PROJECT_PATH} ..."
project = Xcodeproj::Project.open(PROJECT_PATH)

# ── Find the Runner target ─────────────────────────────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }
abort("ERROR: Runner target not found!") unless runner_target

# ── Guard: skip if widget target already exists ───────────────────────────────
if project.targets.any? { |t| t.name == 'InstructorWidget' }
  puts "InstructorWidget target already exists — nothing to do."
  exit 0
end

# ── Create the widget extension target ────────────────────────────────────────
puts "Creating InstructorWidget target ..."
widget_target = project.new_target(
  :app_extension,
  'InstructorWidget',
  :ios,
  IOS_DEPLOYMENT
)

# ── Create the InstructorWidget group ─────────────────────────────────────────
widget_group = project.main_group.new_group('InstructorWidget', 'InstructorWidget')

# ── Add source files ──────────────────────────────────────────────────────────
swift_files = Dir.glob(File.join(WIDGET_DIR, '*.swift'))
info_plist   = File.join(WIDGET_DIR, 'Info.plist')

swift_files.each do |path|
  file_ref = widget_group.new_file(path)
  widget_target.add_file_references([file_ref])
  puts "  + #{File.basename(path)}"
end

# Add Info.plist reference (not compiled, just referenced)
plist_ref = widget_group.new_file(info_plist)
puts "  + Info.plist"

# ── Build settings ────────────────────────────────────────────────────────────
[
  widget_target.build_configuration_list.build_configurations.find { |c| c.name == 'Debug' },
  widget_target.build_configuration_list.build_configurations.find { |c| c.name == 'Release' },
].compact.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'          => WIDGET_BUNDLE_ID,
    'PRODUCT_NAME'                       => 'InstructorWidget',
    'SWIFT_VERSION'                      => SWIFT_VERSION,
    'IPHONEOS_DEPLOYMENT_TARGET'         => IOS_DEPLOYMENT,
    'INFOPLIST_FILE'                     => 'InstructorWidget/Info.plist',
    'CODE_SIGN_ENTITLEMENTS'             => 'InstructorWidget/InstructorWidget.entitlements',
    'SKIP_INSTALL'                       => 'YES',
    'LD_RUNPATH_SEARCH_PATHS'            => ['$(inherited)', '@executable_path/../../Frameworks'],
    'TARGETED_DEVICE_FAMILY'             => '1',   # iPhone only
    'SWIFT_OPTIMIZATION_LEVEL'           => config.name == 'Debug' ? '-Onone' : '-O',
    'APPLICATION_EXTENSION_API_ONLY'     => 'YES',
  })
end

# ── Add WidgetKit and SwiftUI system frameworks ────────────────────────────────
puts "Linking WidgetKit and SwiftUI frameworks ..."
[
  project.frameworks_group.new_file('System/Library/Frameworks/WidgetKit.framework'),
  project.frameworks_group.new_file('System/Library/Frameworks/SwiftUI.framework'),
].each do |fw_ref|
  fw_ref.last_known_file_type = 'wrapper.framework'
  fw_ref.source_tree          = 'SDKROOT'
  widget_target.frameworks_build_phase.add_file_reference(fw_ref)
end

# ── Embed extension in Runner ─────────────────────────────────────────────────
puts "Embedding widget extension in Runner ..."
embed_phase = runner_target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && p.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_path    = ''
  embed_phase.dst_subfolder_spec = '13'  # PlugIns
end

product_ref = widget_target.product_reference
file_in_embed = embed_phase.add_file_reference(product_ref)
file_in_embed.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ── Runner entitlements (App Group) ───────────────────────────────────────────
puts "Updating Runner entitlements ..."
runner_target.build_configuration_list.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] ||= 'Runner/Runner.entitlements'
end

# ── Save ──────────────────────────────────────────────────────────────────────
project.save
puts ""
puts "✅  Done! InstructorWidget target added to Runner.xcodeproj."
puts ""
puts "Next steps:"
puts "  1. Open Runner.xcworkspace in Xcode."
puts "  2. Select the InstructorWidget target → Signing & Capabilities."
puts "  3. Sign with your team and enable 'App Groups' capability."
puts "     Group identifier: #{APP_GROUP}"
puts "  4. Also add 'App Groups' (#{APP_GROUP}) to the Runner target."
puts "  5. Build on a physical device (WidgetKit simulator support is limited)."
