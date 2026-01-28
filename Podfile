source 'https://github.com/CocoaPods/Specs.git'
platform :osx, "10.13"

AutoPkgr = ["AutoPkgr", "AutoPkgrTests"]

AutoPkgr.each { |t|
    target t do
        pod 'AFNetworking', '~> 2.5.4'
        pod 'Sparkle', '1.26.0'
        pod 'XMLDictionary', '~> 1.4'
        pod 'mailcore2-osx', '0.6.4'
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

# Post-install hook to fix OpenSSL linking conflicts
# Removes conflicting -l"crypto" -l"ssl" flags that conflict with -framework "OpenSSL"
post_install do |installer|
    # Fix xcconfig files directly since they override target settings
    Dir.glob("Pods/Target Support Files/Pods-*/Pods-*.xcconfig").each do |file_path|
        content = File.read(file_path)
        if content.include?('OTHER_LDFLAGS') && content.include?('-l"crypto"')
            puts "Fixing OpenSSL conflicts in #{file_path}"
            # Remove conflicting library flags while preserving framework flag
            content.gsub!(/\s*-l"crypto"/, '')
            content.gsub!(/\s*-l"ssl"/, '')
            # Clean up any double spaces in OTHER_LDFLAGS line
            content.gsub!(/^(OTHER_LDFLAGS = .*?)\s+/, '\1 ')
            File.write(file_path, content)
        end
    end
end
