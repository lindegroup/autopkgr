{{# notes }}
Notification services such as Slack don't necessarily use full Markdown formatting. Rendering the text below may not look identical to the resulting notification.
{{/ notes }}
{{# updated_applications.count }}
*New software available for testing:*
{{# updated_applications }}
- {{ name }}: {{ version }}
{{/ updated_applications }}
{{/ updated_applications.count }}{{# integration_updates.count }}
*Update to core components available:*
{{# integration_updates }}
- {{ . }}
{{/ integration_updates }}
{{/ integration_updates.count }}{{# failures.count }}
*Failures occurred in these recipes:*
{{# failures }}
- {{ recipe }}
{{/ failures }}
{{/ failures.count }}{{# error }}
*The following errors occurred:*
- {{ error.suggestion }}
{{/ error }}{{# url_downloader.data_rows.count }}
*{{ url_downloader.summary_text }}*
{{# url_downloader.data_rows }}
{{ download_path }}
{{/ url_downloader.data_rows }}
{{/ url_downloader.data_rows.count }}{{# install_from_dmg.data_rows.count }}
*{{ install_from_dmg.summary_text }}*
{{# install_from_dmg.data_rows }}
{{ dmg_path }}
{{/ install_from_dmg.data_rows }}
{{/ install_from_dmg.data_rows.count }}{{# installer.data_rows.count }}
*{{ installer.summary_text }}*
{{# installer.data_rows }}
{{ pkg_path }}
{{/ installer.data_rows }}
{{/ installer.data_rows.count }}{{# pkg_copier.data_rows.count }}
*{{ pkg_copier.summary_text }}*
{{# pkg_copier.data_rows }}
{{ pkg_path }}
{{/ pkg_copier.data_rows }}
{{/ pkg_copier.data_rows.count }}{{# pkg_creator.data_rows.count }}
*{{ pkg_creator.summary_text }}*
{{# pkg_creator.data_rows }}
- {{ identifier }} (version {{ version }})
{{/ pkg_creator.data_rows }}
{{/ pkg_creator.data_rows.count }}{{# munki_importer.data_rows.count }}
*{{ munki_importer.summary_text }}*
{{# munki_importer.data_rows }}
- *{{ name }}* (version {{ version }} imported into {{ catalogs }})
{{/ munki_importer.data_rows }}
{{/ munki_importer.data_rows.count }}{{# jamfcategoryuploader.data_rows.count }}
*{{ jamfcategoryuploader.summary_text }}*
{{# jamfcategoryuploader.data_rows }}
{{# category }}- Category: *{{ category }}*{{/ category }}{{# priority }}
- Priority: *{{ priority }}*{{/ priority }}
{{/ jamfcategoryuploader.data_rows }}
{{/ jamfcategoryuploader.data_rows.count }}{{# jamfcomputergroupuploader.data_rows.count }}
*{{ jamfcomputergroupuploader.summary_text }}*
{{# jamfcomputergroupuploader.data_rows }}
{{# group }}- Group: *{{ group }}*{{/ group }}{{# template }}
- Template: *{{ template }}*{{/ template }}
{{/ jamfcomputergroupuploader.data_rows }}
{{/ jamfcomputergroupuploader.data_rows.count }}{{# jamfdockitemuploader.data_rows.count }}
*{{ jamfdockitemuploader.summary_text }}*
{{# jamfdockitemuploader.data_rows }}
{{# dock_item_id }}- Dock Item Id: *{{ dock_item_id }}*{{/ dock_item_id }}{{# dock_item_name }}
- Dock Item Name: *{{ dock_item_name }}*{{/ dock_item_name }}{{# dock_item_type }}
- Dock Item Type: *{{ dock_item_type }}*{{/ dock_item_type }}{{# dock_item_path }}
- Dock Item Path: *{{ dock_item_path }}*{{/ dock_item_path }}
{{/ jamfdockitemuploader.data_rows }}
{{/ jamfdockitemuploader.data_rows.count }}{{# jamfextensionattributeuploader.data_rows.count }}
*{{ jamfextensionattributeuploader.summary_text }}*
{{# jamfextensionattributeuploader.data_rows }}
{{# name }}- Name: *{{ name }}*{{/ name }}{{# path }}
- Path: *{{ path }}*{{/ path }}
{{/ jamfextensionattributeuploader.data_rows }}
{{/ jamfextensionattributeuploader.data_rows.count }}{{# jamfpackageuploader.data_rows.count }}
*{{ jamfpackageuploader.summary_text }}*
{{# jamfpackageuploader.data_rows }}
{{# pkg_path }}- Package Path: *{{ pkg_path }}*{{/ pkg_path }}{{# pkg_name }}
- Package Name: *{{ pkg_name }}*{{/ pkg_name }}{{# version }}
- Version: *{{ version }}*{{/ version }}{{# category }}
- Category: *{{ category }}*{{/ category }}
{{/ jamfpackageuploader.data_rows }}
{{/ jamfpackageuploader.data_rows.count }}{{# jamfpatchuploader.data_rows.count }}
*{{ jamfpatchuploader.summary_text }}*
{{# jamfpatchuploader.data_rows }}
{{# patch_id }}- Patch Id: *{{ patch_id }}*{{/ patch_id }}{{# patch_policy_name }}
- Patch Policy Name: *{{ patch_policy_name }}*{{/ patch_policy_name }}{{# patch_softwaretitle }}
- Patch Software Title: *{{ patch_softwaretitle }}*{{/ patch_softwaretitle }}{{# patch_version }}
- Patch Version: *{{ patch_version }}*{{/ patch_version }}
{{/ jamfpatchuploader.data_rows }}
{{/ jamfpatchuploader.data_rows.count }}{{# jamfpolicyuploader.data_rows.count }}
*{{ jamfpolicyuploader.summary_text }}*
{{# jamfpolicyuploader.data_rows }}
{{# policy }}- Policy: *{{ policy }}*{{/ policy }}{{# template }}
- Template: *{{ template }}*{{/ template }}{{# icon }}
- Icon: *{{ icon }}*{{/ icon }}
{{/ jamfpolicyuploader.data_rows }}
{{/ jamfpolicyuploader.data_rows.count }}{{# jamfscriptuploader.data_rows.count }}
*{{ jamfscriptuploader.summary_text }}*
{{# jamfscriptuploader.data_rows }}
{{# script }}- Script: *{{ script }}*{{/ script }}{{# path }}
- Path: *{{ path }}*{{/ path }}{{# category }}
- Category: *{{ category }}*{{/ category }}{{# priority }}
- Priority: *{{ priority }}*{{/ priority }}{{# os_req }}
- OS Requirements: *{{ os_req }}*{{/ os_req }}{{# info }}
- Info: *{{ info }}*{{/ info }}{{# notes }}
- Notes: *{{ notes }}*{{/ notes }}{{# P4 }}
- P4: *{{ P4 }}*{{/ P4 }}{{# P5 }}
- P5: *{{ P5 }}*{{/ P5 }}{{# P6 }}
- P6: *{{ P6 }}*{{/ P6 }}{{# P7 }}
- P7: *{{ P7 }}*{{/ P7 }}{{# P8 }}
- P8: *{{ P8 }}*{{/ P8 }}{{# P9 }}
- P9: *{{ P9 }}*{{/ P9 }}{{# P10 }}
- P10: *{{ P10 }}*{{/ P10 }}{{# P11 }}
- P11: *{{ P11 }}*{{/ P11 }}
{{/ jamfscriptuploader.data_rows }}
{{/ jamfscriptuploader.data_rows.count }}{{# jss_importer.data_rows.count }}
*{{ jss_importer.summary_text }}*
{{# jss_importer.data_rows }}
{{# Categories }}- Category: *{{ Categories }}*{{/ Categories }}{{# Groups }}
- Group: *{{ Groups }}*{{/ Groups }}{{# Icon }}
- Icon: *{{ Icon }}*{{/ Icon }}{{# Package }}
- Package: *{{ Package }}*{{/ Package }}{{# Policy }}
- Policy: *{{ Policy }}*{{/ Policy }}{{# Scripts }}
- Script: *{{ Scripts }}*{{/ Scripts }}
{{/ jss_importer.data_rows }}
{{/ jss_importer.data_rows.count }}{{# absolute_manage_export.data_rows.count }}
*{{ absolute_manage_export.summary_text }}*
{{# absolute_manage_export.data_rows }}
- {{ Package }}
{{/ absolute_manage_export.data_rows }}
{{/ absolute_manage_export.data_rows.count }}{{# lanrev_importer.data_rows.count }}
*{{ lanrev_importer.summary_text }}*
{{# lanrev_importer.data_rows }}
- {{ Package }}
{{/ lanrev_importer.data_rows }}
{{/ lanrev_importer.data_rows.count }}{{# macpatch_importer.data_rows.count }}
*{{ macpatch_importer.summary_text }}*
{{# macpatch_importer.data_rows }}
- {{ name }} (version {{ version }})
{{/ macpatch_importer.data_rows }}
{{/ macpatch_importer.data_rows.count }}{{# virus_total_analyzer.data_rows.count }}
*{{ virus_total_analyzer.summary_text }}*
{{# virus_total_analyzer.data_rows }}
- {{ name }} (Ratio {{ ratio }}: {{ permalink }})
{{/ virus_total_analyzer.data_rows }}
{{/ virus_total_analyzer.data_rows.count }}
