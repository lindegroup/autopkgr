source 'https://github.com/CocoaPods/Specs.git'
platform :osx, "11.0"

AutoPkgr = ["AutoPkgr", "AutoPkgrTests"]

AutoPkgr.each { |t|
    target t do
        pod 'AFNetworking', '~> 2.5.4'
        pod 'Sparkle', '1.26.0'
        pod 'XMLDictionary', '~> 1.4'
        pod 'GRMustache', '~> 7.3.2'
        pod 'ACEView', '~> 0.0.5'
        pod 'MMMarkdown', '~> 0.5.1'
        pod 'AHProxySettings', '~> 0.1.1'
        pod 'AHKeychain', '~> 0.3.0'
        pod 'OpenSSL-Universal'
        pod 'AHLaunchCtl', :git => 'https://github.com/eahrold/AHLaunchCtl.git'
    end
}

target "com.lindegroup.AutoPkgr.helper" do
    pod 'AHLaunchCtl', :git => 'https://github.com/eahrold/AHLaunchCtl.git'
    pod 'AHKeychain', '~> 0.3.0'
    pod 'RNCryptor-objc', '~> 3.0.6'
end

post_install do |installer|
    # Fix xcconfig files: remove conflicting -l"crypto" -l"ssl" flags
    Dir.glob("Pods/Target Support Files/Pods-*/Pods-*.xcconfig").each do |file_path|
        content = File.read(file_path)
        if content.include?('OTHER_LDFLAGS') && content.include?('-l"crypto"')
            puts "Fixing OpenSSL conflicts in #{file_path}"
            content.gsub!(/\s*-l"crypto"/, '')
            content.gsub!(/\s*-l"ssl"/, '')
            content.gsub!(/^(OTHER_LDFLAGS = .*?)\s+/, '\1 ')
            File.write(file_path, content)
        end
    end

    # Propagate Universal build settings to all pod targets
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            current = config.build_settings['MACOSX_DEPLOYMENT_TARGET']
            if current.nil? || current.to_f < 11.0
                config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
            end
            config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
        end
    end

    # Fix RNCryptor-objc SecRandomCopyBytes type conflict with macOS 15+ SDK
    rncryptor_file = "#{installer.sandbox.root}/RNCryptor/RNCryptor/RNCryptor.m"
    if File.exist?(rncryptor_file)
        FileUtils.chmod(0644, rncryptor_file)
        content = File.read(rncryptor_file)
        content.gsub!(/^.*extern int SecRandomCopyBytes.*\n/, '')
        File.write(rncryptor_file, content)
    end
end
