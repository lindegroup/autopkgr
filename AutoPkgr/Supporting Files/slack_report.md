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
{{/ munki_importer.data_rows.count }}{{# jss_importer.data_rows.count }}
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
