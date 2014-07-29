Pod::Spec.new do |s|
  s.name = 'AHLaunchCtl'
  s.version = '0.2.0'
  s.license = 'MIT'
  s.summary = 'An LaunchD framework for OSX Cocoa apps'
  s.homepage = 'https://github.com/eahrold/AHLaunchCtl'
  s.authors  = { 'Eldon Ahrold' => 'eldonahrold@gmail.com' }
  s.source   = { :git => 'https://github.com/eahrold/AHLaunchCtl.git', :tag => "0.2.0", :submodules => true }
  s.requires_arc = true

  s.osx.deployment_target = '10.8'
  
  s.public_header_files = 'AHLaunchCtl/*.h'
  s.source_files = 'AHLaunchCtl/*.{h,m}'
  s.frameworks = 'SystemConfiguration','ServiceManagement','Security'
end
