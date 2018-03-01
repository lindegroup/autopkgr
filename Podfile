source 'https://github.com/CocoaPods/Specs.git'
platform :osx, "10.9"

AutoPkgr = ["AutoPkgr", "AutoPkgrTests"]

AutoPkgr.each { |t|
    target t do
        pod 'AFNetworking', '~> 2.5.4'
        pod 'Sparkle', '~> 1.14.0'
        pod 'XMLDictionary', '~> 1.4'
        pod 'mailcore2-osx', '~> 0.5'
        pod 'GRMustache', '~> 7.3.2'
        pod 'ACEView', '~> 0.0.5'
        pod 'MMMarkdown', '~> 0.5.1'
        pod 'AHProxySettings', '~> 0.1.1'
        pod 'AHKeychain', '~> 0.3.0'
        pod 'AHLaunchCtl', :git => 'https://github.com/eahrold/AHLaunchCtl.git'
        pod 'OpenSSL-OSX'
    end
}

target "com.lindegroup.AutoPkgr.helper" do
    pod 'AHLaunchCtl', :git => 'https://github.com/eahrold/AHLaunchCtl.git'
    pod 'AHKeychain', '~> 0.3.0'
    pod 'RNCryptor-objc', '~> 3.0.5'
end
