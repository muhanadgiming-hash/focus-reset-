# Adds Focus Reset's extra resources to the generated Xcode project:
#   * Runner/en.lproj + ar.lproj InfoPlist.strings (Arabic permission prompts)
#   * Runner/PrivacyInfo.xcprivacy (Apple privacy manifest)
# Uses the xcodeproj gem that ships with CocoaPods. Safe to run repeatedly.
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')
group = project.main_group.find_subpath('Runner', false) or abort('Runner group not found')

# Localised InfoPlist.strings
variant = group.children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'InfoPlist.strings' }
variant ||= group.new_variant_group('InfoPlist.strings')
%w[en ar].each do |lang|
  path = "#{lang}.lproj/InfoPlist.strings"
  next if variant.children.any? { |f| f.path == path }
  ref = variant.new_reference(path)
  ref.name = lang
  ref.last_known_file_type = 'text.plist.strings'
end
target.resources_build_phase.add_file_reference(variant, true)

# Privacy manifest
privacy = group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' }
privacy ||= group.new_reference('PrivacyInfo.xcprivacy')
target.resources_build_phase.add_file_reference(privacy, true)

regions = project.root_object.known_regions
%w[en ar Base].each { |r| regions << r unless regions.include?(r) }

project.save
puts 'Added InfoPlist.strings (en, ar) and PrivacyInfo.xcprivacy'
