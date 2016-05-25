# AutoPkgr Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).


## [Unreleased](unreleased)

### Added
- One-click integration with [@hjuutilainen](https://github.com/hjuutilainen/autopkg-virustotalanalyzer)'s [VirusTotalAnalyzer](https://github.com/hjuutilainen/autopkg-virustotalanalyzer) processor.

### Changed
- Updated versions of MMMarkdown and MailCore2 used in AutoPkgr.
- Clarified wording on the selective notifications picker (thanks to [@poundbangbash](https://github.com/poundbangbash) for the wordsmithing).

### Fixed
- Fixed the AutoPkgr Slack bot icon URL. (#527)
- Some typos found and corrected.

## [1.4.1] - 2016-04-18

### Added
- AutoPkgr now allows you to customize the template used to generate notifications when new actions have occurred. Check it out at the bottom of the Notifications tab. (#184)

### Fixed
- Fixed a long-standing issue that caused an incorrect prompt for the AutoPkgr keychain password! (#469)
- Addressed several issues that may have prevented notifications from working reliably in version 1.4. (#508, #515)
- Fixed a crash caused by the SMTP server setting being blank. (#502)
- AutoPkgr launches a bit faster now. (#500)
- AutoPkgr now reports [InstallFromDMG](https://github.com/autopkg/autopkg/wiki/Processor-InstallFromDMG) processor results in addition to [Installer](https://github.com/autopkg/autopkg/wiki/Processor-Installer) processor results.
- Fixed an issue that would cause the email notification subject to be blank.

### Changed
- Adjusted default formatting of email and Slack notifications. (#507)
- Added logging for SMTP operations.
- Prevented password field from wrapping to a "new line." (#481)
- Increased width of active recipe list picker.

### Security
- A note on keychain security in AutoPkgr 1.4.1:

    The fix for [issue #469](https://github.com/lindegroup/autopkgr/issues/469) requires AutoPkgr to be less aggressive when locking the AutoPkgr keychain (a separate keychain stored in ~/Library/Keychains that stores your SMTP credentials for email notifications). It's possible for somebody with access to your AutoPkgr Mac to obtain your SMTP password using the `security` command while the AutoPkgr keychain is unlocked.

    Here's why AutoPkgr exceeds our security requirements, even with less aggressive keychain locking:

    - AutoPkgr's locking behavior is still _more_ restrictive than your login keychain's behavior.
    - Physical access or VNC to your AutoPkgr Mac is necessary to use the `security` command to obtain the SMTP password.
    - AutoPkgr goes to great lengths to keep the actual AutoPkgr keychain password both unknown and unnecessary to know, which prevents password exposure via the Keychain Access app.

    Taking common sense security steps should mitigate any risks introduced by this change. Here are three to consider:

    - Use an SMTP account dedicated to AutoPkgr for email notifications.
    - Run AutoPkgr on a dedicated Mac or VM, rather than using one shared by other services.
    - Unless necessary, don't leave the Mac logged in. AutoPkgr works great at the login window (which is why it has its own keychain in the first place), and a Mac at the login window is magnitudes safer than one with an active user session.


## [1.4] - 2016-03-01

### Added
- You can now select which events trigger a notification. For example, you can receive only Munki import notifications, and ignore download notifications. In other words, no more daily emails about VLC downloading! (#184)
- Ability to select multiple repos and then update, add, or remove the selected repos. (#434)
- Ability to select multiple recipes and then run, enable, or disable the selected recipes. (#434)
- Built-in integration with FileWave version 10 and higher, via the new [FileWaveImporter](https://github.com/autopkg/filewave) processor. (#339, with thanks to [@johncclayton](https://github.com/johncclayton).)
- Integration with new [LANrevImporter](https://github.com/jbaker10/LANrevImporter) processor. (#488) See the [LANrevImporter wiki](https://github.com/jbaker10/LANrevImporter/wiki/Switching-from-AbsoluteManageExport-to-LANrevImporter) for information on migrating from AbsoluteManageExport.
- Ability to switch between multiple recipe lists. (#263)
- Ability to specify pre/post processors. (#346, #384)
- MakeCatalogs.munki will be included when .munki recipes are run from the contextual menu. (#485)

### Fixed
- Fixed a bug that caused progress spinners to incorrectly display on multiple recipes if they share the same name. (#447)
- Fixed a bug that caused AutoPkgr to freeze when adding a custom repo with a trailing space in the URL. (#486)
- Fixed a minor counting error in log output. (#446)
- Fixed crash that occurred if Git was not reinstalled after an OS X upgrade. (#458)
- Fixed a bug that resulted in unreliable "Run This Only Recipe Only" selection. (#456)
- XPC connections to helper tool are now explicitly closed on process completion.

### Changed
- Totally redesigned and simplified the JSSImporter settings sheet.
- JSSImporter configuration UI now supports cloud distribution points (CDP) and local distribution points. (#463, #309)
- MakeCatalogs.munki recipe is now added by name rather than by identifier. An override with the same name will now be used, if one exists. (Hat tip to [@grahampugh](https://github.com/grahampugh).)
- General improvements to integration performance. No longer makes duplicate GitHub API calls when "releases" don't exist.
- Updated "AutoPkgr" link in footer of notification emails to point to [AutoPkgr information page](http://www.lindegroup.com/autopkgr) instead of [GitHub repo](https://github.com/lindegroup/autopkgr).
- Moved Recipe/Override chooser out of contextual menu and into AutoPkg preference panel.
- Widened images in readme.md so they'll look awesome with GitHub.com's new repo layout.
- Updated bundled version of Sparkle auto-update framework.
- The "Add Repo" button and associated text field now work with any supported URL, not just HTTPS.
- When you right-click and run a single Munki recipe, AutoPkgr will now run MakeCatalogs.munki too.
- Made width of tab views more consistent.


## [1.3.2] - 2015-09-16

### Added
- You can now specify the name of the AutoPkgr bot when configuring Slack integration. (#437)

### Changed
- Now includes localized hostname in all notifications, not just email.

### Fixed
- Fixed an unpleasant freeze that occurred after installing JSSImporter. (#443)
- AutoPkgr now more gracefully handles mid-run interactive prompts from AutoPkg, which is usually a result of missing parent recipes. (#441)
- Fixed a bug that resulted in errors when a repo path contained spaces. (#435)
- Fixed a tiny typo in the default Munki repo path.
- Resolved an issue in the CocoaPods configuration (#445).


## [1.3.1] - 2015-08-19

### Added
- Now supports GitHub two-factor authentication for generation of API tokens. (#393)
- Made Slack and HipChat output more verbose, including errors. (#417)

### Changed
- Changed the way a valid user is determined when adding a schedule. Users not physically logged into the system can now enable the schedule assuming they have a valid home directory, and a `com.github.autopkg.plist` preference file. (#416)

### Fixed
- Adjusted a few things that should improve AutoPkgr's behavior when running on Mac OS X 10.8.
- Fixed a bug that would cause proxy settings to be displayed incorrectly. (#399)
- Fixed a bug where schedule changes would not reload in-memory launchd schedule.
- Incorporates a new version of AHLaunchCtl, which improves the reliability of the schedule settings.
- Fixed a bug that would prevent JSSImporter-related defaults from getting set.
- Fixed a bug that would result in repos appearing twice in the repo table. (#406)
- Fixed a bug causing search results to be incorrectly formatted. (#410)
- Improved handling of git operations when using proxies.
- Resolved issue where Slack/HipChat settings were not saving properly in OS X El Capitan. (Note: AutoPkgr does not officially support El Capitan yet.)

### Removed
- AutoPkgr no longer attempts to automatically correct or change JSS URLs entered through the "Configure JSSImporter" options. As long as the URL you enter is valid, you shouldn't notice this.


## [1.3] - 2015-05-08

### Added
- Integration with Absolute Manage (via the [AbsoluteManageExport](https://github.com/tburgin/AbsoluteManageExport) processor). (#217)
- Integration with MacPatch (via the [MacPatchImporter](https://github.com/SMSG-MAC-DEV/MacPatch-AutoPKG) processor). (#347)
- Now you can send notifications directly to a Slack (#358) or HipChat (#359) channel.
- More flexible options for scheduling AutoPkg to run. New daily and weekly options! (#361)
- By popular request, you can now right-click on a recipe and choose Run This Recipe. (#107)
- You can also right-click on a recipe in the list and choose Get Info to see various details about the recipe. (#342, #357, #370)
- Right-click on a repo to access the GitHub commits page or update a single repo. (#357)
- The repo and recipe lists are now sortable! (#356)
- The repos list now displays the number of stars each repo has on GitHub (and you can sort by them too). (#356, #357)
- Proxy configuration is now much easier than typing Terminal commands. Just go to the Folders & Integration tab, then click on Configure AutoPkg to access the proxy settings.
- In the same location as the proxy settings, you can now create the GitHub API token used with `autopkg search` feature using AutoPkgr. This allows a greater number of search queries per hour.
- The install tab now displays status of additional integrated tools and processors, like AbsoluteManageExport and MacPatchImporter.
- Easier uninstallation of components like JSSImporter and AbsoluteManagerExport. (#332)
- Better validation of the standard output AutoPkgr receives from AutoPkg.
- Ability to change the Git binary used by AutoPkg.
- The repos list now has a status indicator showing if there are new commits to an installed repo. (#357)
- The recipe list now has a status indicator showing if a recipe is missing a parent recipe. (#357, #370)
- We're now using OS X Notification Center for a few useful messages, like when new software has been packaged by AutoPkg. (#79)
- Added the ability to configure how often notifications are sent for new version of AutoPkg, JSSImporter, Git, and other components. (#379)
- Added a "Check for AutoPkgr Updates" item in the AutoPkgr menu extra. (#275, #312)

### Changed
- New JSSImporter users will now get the "official" [jss-recipes repo](https://github.com/autopkg/jss-recipes) when configuring JSSImporter.
    Note: Existing JSSImporter users will not (yet) be affected, but will eventually need to transition to the new repo. Instructions will be available soon. In the meantime, read through the [jss-recipes readme](https://github.com/autopkg/jss-recipes#introduction)!
- Reworked Folders & Integration tab interface to support a theorically unlimited number of integration tools, including Munki, Casper, Absolute Manage, and MacPatch. The sky is the limit.
- Updated readme to make it clear that you should only update repos before every AutoPkg run if you trust recipe authors.
- Removed unused menus and menu items.
- Significantly rewrote the readme with new and updated information.
- Behind-the-scenes code cleanup, typo fixes, refactors, and reorganization. Always tidying up!

### Fixed
- Fixed a bug that could prevent email configuration changes from "sticking."
- Squished a bug that could cause the `JSS_VERIFY_SSL` key to be incorrectly set.
- Stomped on a bug that resulted in a "(null)" error in certain circumstances. (#352)
- Swatted a bug that required pressing Tab or Enter in order to save the email password before sending a test email. Now the password is saved upon clicking the Send Test Email button as well. (#352)
- When a JSSImporter update was available, the text on the Install tab would often overflow its container. We've enlarged the container, so hopefully that won't happen now. (#314)
- AutoPkgr now remembers the last window position and table sort status upon subsequent launches. (#375)
- Squashed a bug that resulted in "Version (null)" in OS X notifications. (#376)
- Eradicated a bug that could cause AutoPkgr to falsely believe there are multiple instances of AutoPkg running.


## [1.2.3] - 2015-05-08

### Changed
- Now you can check the SSL box even if you're not using SMTP authentication. (#335)
- Relative date/time now shown in AutoPkgr menu status (e.g. "Today at 8:00 AM"). (#340)

### Fixed
- Fixed a particularly devious bug that would cause AutoPkgr to get stuck running recipes while certain apps (usually Google Chrome) were active. (#230)
- AutoPkgr menu status should now be up to date upon first click, not just upon status change. (#340)
- Fixed a bug that caused progress indicators to show inaccurate counts when the `StopProcessingIf` processor is present in a recipe. (#333)
- Reduced the odds of error messages overflowing the on-screen alert dialog boxes.
- AutoPkgr now asks for XML when talking to your JSS, but should successfully revert to JSON if your JSS stubbornly refuses. (#287)
- Fixed a minor bug that could result in excess CPU usage.
- Various minor cosmetic changes.

### Security
- Updated to the most recent version of the AFNetworking components.


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
- AutoPkgr now passes the recipe and override identifier into AutoPkg to avoid naming clashes when multiple repos have recipes with the same name. Thanks to [@rtrouton](https://github.com/rtrouton) for the suggestion. (#208)
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
- Using master JDS is now set with a checkbox. Thanks to [@everetteallen](https://github.com/everetteallen) for this suggestion. ([#174](https://github.com/lindegroup/autopkgr/issues/174#issuecomment-64712310))

### Fixed
- Fixed a condition that could cause preferences to be erased if an error occurs during launch.
- Fixed a condition that could cause AutoPkg to hang due to Python stdout buffer not getting flushed.
- Fixed a condition where keychain was queried for email password even when authentication was not enabled.
- Automatically removes trailing slash from JSS_URL which could cause 404 errors. Thanks to [@acodega](https://github.com/acodega) for getting to the bottom of this! ([#221](https://github.com/lindegroup/autopkgr/issues/221#issuecomment-66159456))
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
- AutoPkgr now does not remove [@sheagcraig](https://github.com/sheagcraig)'s jss-recipes repository when the JSS settings have been cleared.

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
- AutoPkgr's configuration window is now correctly brought to front (thanks to [@MitchelSBlake](https://github.com/MitchelSBlake)). (#93)
- Git install is now working. (#61)
- Both the recipes and repos table views scale proportionally as the window resizes.
- The configuration window is now displayed each time AutoPkgr is launched, (rather than just the first time).
- AutoPkg is now downloaded and installed using the release `.pkg` per feedback from [@timsutton](https://github.com/timsutton).
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
- Replaced references to "Apps" with "Recipes" per [@gregneagle](https://github.com/gregneagle)'s feedback.

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


[unreleased]: https://github.com/lindegroup/autopkgr/compare/v1.4.1...HEAD
[1.4.1]: https://github.com/lindegroup/autopkgr/compare/v1.4...v1.4.1
[1.4]: https://github.com/lindegroup/autopkgr/compare/v1.3.2...v1.4
[1.3.2]: https://github.com/lindegroup/autopkgr/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/lindegroup/autopkgr/compare/v1.3...v1.3.1
[1.3]: https://github.com/lindegroup/autopkgr/compare/v1.2.3...v1.3
[1.2.3]: https://github.com/lindegroup/autopkgr/compare/v1.2.2...v1.2.3
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
