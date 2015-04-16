source 'https://github.com/CocoaPods/Specs.git'
platform :osx, "10.8"

AutoPkgr = ["AutoPkgr", "AutoPkgrTests"]

AutoPkgr.each { |t|
    target t do
        pod 'AFNetworking', '~> 2.4.1'
        pod 'Sparkle', '1.8'
        pod 'XMLDictionary', '~> 1.4'
        pod 'mailcore2-osx', '~> 0.5'
        pod 'AHProxySettings', '~> 0.1.1'
        pod 'AHKeychain', '~> 0.2.1'
        pod 'AHLaunchCtl', '~> 0.4.1'
    end
}

target "com.lindegroup.AutoPkgr.helper" do
    pod 'AHLaunchCtl', '~> 0.4.1'
    pod 'AHKeychain', '~> 0.2.1'
    pod 'RNCryptor', '~> 2.2'
end
