AutoPkgr Change Log
===================

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).


## [Unreleased][unreleased]

### Changed
- Now you can check the SSL box even if you're not using SMTP authentication. (#335)

### Fixed
- Fixed a bug that caused progress indicators to show inaccurate counts when the `StopProcessingIf` processor is present in a recipe. (#333)


## [1.2.2] - 2015-04-16

### Added
- Compatibility with upcoming changes to AutoPkg reporting format.
- Updated documentation to include information about creating/editing overrides.
- Items in Help menu now link to useful URLs.

### Changed
- AutoPkgr now prevents you from proceeding beyond the Install tab if you don't have AutoPkg and Git installed.


## [1.2.1] - 2015-03-08

### Added
- Created changelog.
- AutoPkgr now displays the version number of Git and AutoPkg in the Install tab. (#244)
- Now you'll receive an email when new versions of Git, AutoPkg, or AutoPkgr are available. (#137)

### Security
- Now using three-way encryption to store SMTP password more securely. (#271)
- Improved security of the helper tool AutoPkgr uses to run in the background.
- AutoPkgr now tries to obfuscate sharepoint usernames and passwords in email notifications. (#227)

### Fixed
- Background run not updating date in status menu. (#286)
- Resolved an issue that prevented "Launch at Login" button from working in 10.8 and 10.9. (#272)
- Prevented displaying progress detail messages unnecessarily.
- Properly processes `%20` in URLs when parsing versions. (#270)
- Fixed the "Check for repo updates before each recipe run" checkbox wording.
- Fixed a bug that prevented status messages over 50 characters from being displayed in the menu.
- Fixed a bug that prevented autopkg run status from appearing in the menu.
- Made configuration options for "Run AutoPkg Now" consistent with menu items.
- Fixed a situation that prevented launchd from reading current defaults values. (#296)
- Now showing AutoPkgr icon in both the Dock and the menu bar by default.
- Small improvements to keychain migration method.

### Changed
- Uninstall is now handled by the main app, not the helper tool.


## [1.2] - 2015-02-13

### Added
- By popular request, scheduling will now be handled by a LaunchDaemon. This allows AutoPkgr to continue running after a restart, even if nobody is logged in. (#72)
- You can now set how AutoPgkr is displayed, either as a menu item, Dock item, or both. (#10)
- You can now set AutoPkgr to launch at login. (#11)
- If the "check for repo updates" option is enabled, it will now perform the repo update prior to each `autopkg run`, rather than just when AutoPkgr is launched. This should help next time the AdobeFlashPlayer recipe changes rapidly.
- AutoPkgr now passes the recipe and override identifier into AutoPkg to avoid naming clashes when multiple repos have recipes with the same name. Thanks to @rtrouton for the suggestion. (#208)
- The AutoPkgr menu has been redesigned and enhanced with new menu options.
- Progress is now displayed during repo-update.
- We now use OS X's Notifications feature to display test email success. More notifications coming soon!
- Creating an override will now prompt for override name, allowing for the creation of multiple overrides with the same parent. (For example, `FirefoxSelfService.jss` and `FirefoxAutoUpdate.jss`.)
- When enabling a recipe, if the parent recipe is not installed, an alert will be displayed.
- Scheduled recipes will automatically be removed from the recipe list if their repo is removed, or if a repo update no longer contains the recipe.
- You can now search GitHub for AutoPkg recipes, equivalent to `autopkg search [recipe]`.
- Easy uninstall! If you ever want to uninstall AutoPkgr and its components, hold the **Option** key and choose **Uninstall** from the AutoPkgr menu icon.

### Changed
- New keychain item for AutoPkgr located at `~/Library/Keychains/AutoPkgr.keychain`. It can be unlocked and examined using the computer's serial number as the password.
- Using master JDS is now set with a checkbox. Thanks to @everetteallen for this suggestion. ([#174](https://github.com/lindegroup/autopkgr/issues/174#issuecomment-64712310))

### Fixed
- Fixed a condition that could cause preferences to be erased if an error occurs during launch.
- Fixed a condition that could cause AutoPkg to hang due to Python stdout buffer not getting flushed.
- Fixed a condition where keychain was queried for email password even when authentication was not enabled.
- Automatically removes trailing slash from JSS_URL which could cause 404 errors. Thanks to @acodega for getting to the bottom of this! ([#221](https://github.com/lindegroup/autopkgr/issues/221#issuecomment-66159456))
- Minor typo fixes and additional log entries, as always.


## [1.1.3] - 2014-12-15

### Removed
- Removed parts of the code that we no longer use, like an unzipper class.

### Changed
- Updated all references from jss-autopkg-addon to JSSImporter. This should resolve a problem that prevented AutoPkgr from properly installing or upgrading JSSImporter on many systems.

### Fixed
- Typo fixes, mostly internal.


## [1.1.2] - 2014-12-01

### Added
- Made compatible with latest release of [jss-autopkg-addon](https://github.com/sheagcraig/jss-autopkg-addon).

### Changed
- If using JSS integration, python-jss now automatically "URL encodes" the distribution point passwords (#177).
- Updated readme to clarify that Casper 9 or newer is required for JSS integration.
- AutoPkgr now does not remove @sheagcraig's jss-recipes repository when the JSS settings have been cleared.

### Fixed
- Fixed a bug which would set `SSL_VERIFY` incorrectly for Casper environments with self-signed certificates.
- Made GUI elements match more consistently between OS X Mavericks and OS X Yosemite.
- Fixed a bug that caused errors in environments with a password-protected proxy.
- Corrected spelling of "available" in email notifications and other places.


## [1.1.1] - 2014-11-15

### Added
- Better proxy support. AutoPkgr can now use proxies set in System Preferences, including Auto Detected WPAD/PAC.
- Compatibility with Yosemite's "dark mode." (#190)

### Changed
- Minor GUI adjustments.

### Fixed
- Better handling of URLs for Cloud hosted JSS. (#170)
- More comprehensive logging relating to JSS operations.
- Cleaner UI error messages. (related to #167)
- Correctly detects Xcode git. (#181)


## [1.1] - 2014-10-21

### Added
- Added built-in support for integrating with JAMF's Casper Suite. (#75)
- Added built-in support for creating and editing recipe overrides. (#60)
- Added environmental proxy support. (#152 and #130)
- Improved readme with detailed information on Munki and Casper integration, and some troubleshooting tips.
- Additional detail added to logs.
- Better version reporting in email messages (especially with `.munki` recipes).
- More concise errors when Python exceptions occur.

### Fixed
- Fixed bug that prevented certain repos from appearing automatically in the repos list (#148).


## [1.0.4] - 2014-09-24

### Added
- The ability to cancel installations, recipe checks, and other tasks in progress.
- Implemented code signing to avoid "unidentified developer" error upon first launch.
- Now using the Sparkle framework, so AutoPkgr can keep itself up to date.
- Git install feature is now available for Macs running 10.8.

### Changed
- Git installer for 10.9 no longer relies on the Xcode command line tools. No need to leave AutoPkgr to get Git!

### Fixed
- More detail in logs, including the ability to enable a verbose log mode for troubleshooting (see [readme](https://github.com/lindegroup/autopkgr/blob/master/README.md)).
- Improved behavior of the "Open in Finder" buttons.
- Resolved bug that would cause an incorrect hostname to be reported in notification emails.
- Resolved bug that would prevent "from" address from appearing in log output.


## [1.0.3] - 2014-09-09

### Added
- Added check to ensure multiple autopkg instances aren't running simultaneously.
- Implemented a new testing procedure that should prevent some nasty bugs from escaping into the wild.
- During recipe checks, you'll now see helpful status messages in the AutoPkgr menu extra.
- Introduced localized strings.
- Beautiful new DMG branding.

### Changed
- Restored compatibility with Mac OS X 10.8.

### Fixed
- More accurate and streamlined detection of Git installation status.
- Fixed bug that prevented recipe checks from completing and notification emails from sending. (#122, #117)
- Fixed bug that left orphaned Python processes running in the background. (#121)
- Better reporting of downloaded app version numbers. (#85, #77)
- More detailed error reporting in both the app and the email notifications. (#104)
- The logs are a bit more verbose, which should help with troubleshooting future problems.
- Fixed bug that prevented the "Open in Finder" buttons from being very useful. (#118)
- Numerous little tweaks to the messages in the app, email, and logs.
- Fixed bug that could pass bad values into the SMTP settings.


## [1.0.2] - 2014-09-04

### Added
- Compatible with AutoPkg v0.4.0.
- AutoPkgr now presents progress and errors. (#76, #84, #105)
- Added SMTP port status indicators. (#16)
- Allow setting certain AutoPkg preferences directly from AutoPkgr. (#70)
- MakeCatalogs.munki is appended to the recipe list if any `.munki` recipe is selected. (#74, #106)

### Changed
- Version 1.0.2 is only compatible with Mac OS X 10.9 and higher.

### Fixed
- AutoPkgr's configuration window is now correctly brought to front (thanks to @MitchelSBlake). (#93)
- Git install is now working. (#61)
- Both the recipes and repos table views scale proportionally as the window resizes.
- The configuration window is now displayed each time AutoPkgr is launched, (rather than just the first time).
- AutoPkg is now downloaded and installed using the release `.pkg` per feedback from @timsutton.
- RecipeRepos are now populated from the GitHub API and sorted by star count. (#108)
- The default state of the "Install Git" and "Install AutoPkg" buttons, status indicators, and labels now default to _not_ installed.


## [1.0.1] - 2014-07-21

### Added
- Added support for StartTLS
- Added the ability to update AutoPkg. If a new version is detected on launch, the button changes to "Update AutoPkg" and the status icon changes to yellow. If no new version is detected and AutoPkg is installed the button is disabled and the status icon is green.
- Added a "Check Now" option in the menulet.
- Added the ability to customize the From email address, (as opposed to defaulting to shortname@hostname).

### Changed
- Adjusted precedence for determining local Munki repo path. It is now 1) AutoPkgr preferenece domain, 2) AutoPkg preference domain, 3) Munki preference domain, 4) "default" value.
- Less alarming log output.
- Replaced references to "Apps" with "Recipes" per @gregneagle's feedback.

### Removed
- Removed "Save and Close" button. Changes are now saved immediately.

### Fixed
- Fixed an issue that would cause AutoPkg to always report as installed on first launch.
- Fixed an issue where LGUnzipper could not unzip to a target folder if the folder already existed.
- Improved duplicate repo detection.
- Vastly improved the email notification formatting.
- The UI now scales appropriately when the window size changes.


## 1.0 - 2014-07-13

### Added
- Initial public release of AutoPkgr.


[unreleased]: https://github.com/lindegroup/autopkgr/compare/v1.2.2...HEAD
[1.2.2]: https://github.com/lindegroup/autopkgr/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/lindegroup/autopkgr/compare/v1.2...v1.2.1
[1.2]: https://github.com/lindegroup/autopkgr/compare/v1.1.3...v1.2
[1.1.3]: https://github.com/lindegroup/autopkgr/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/lindegroup/autopkgr/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/lindegroup/autopkgr/compare/v1.1...v1.1.1
[1.1]: https://github.com/lindegroup/autopkgr/compare/v1.0.4...v1.1
[1.0.4]: https://github.com/lindegroup/autopkgr/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/lindegroup/autopkgr/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/lindegroup/autopkgr/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/lindegroup/autopkgr/compare/v1.0...v1.0.1
