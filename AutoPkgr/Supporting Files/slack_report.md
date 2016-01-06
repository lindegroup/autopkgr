{{# notes }}
Notification services such as Slack don't necissairly use full Markdown formatting. 
The rendering here may not look the exact same in the notification.
Please visit the requisit sites for more specifics on formatting.
{{/ notes }}

{{# updated_applications.count }}
*New software available for testing:*
{{# updated_applications }}
* {{ name }} : {{ version }}
{{/ updated_applications }}
{{/ updated_applications.count }}

{{# integration_updates.count }}
*Update to core components available:*
{{# integration_updates }}
* {{ . }}
{{/ integration_updates }}
{{/ integration_updates.count }}

{{# failures.count }}
Failures occurred in these recipes:
{{# failures }}
* {{ recipe }}
{{/ failures }}
{{/ failures.count }}

{{# error }}
*The following errors occurred:*
* {{ error.suggestion }}
{{/ error }}

{{# url_downloader.data_rows.count }}
*{{ url_downloader.summary_text }}*
{{# url_downloader.data_rows }}
* {{ download_path }}
{{/ url_downloader.data_rows }}
{{/ url_downloader.data_rows.count }}

{{# install_from_dmg.data_rows.count }}
*{{ install_from_dmg.summary_text }}*
{{# install_from_dmg.data_rows }}
* {{ dmg_path }}
{{/ install_from_dmg.data_rows }}
{{/ install_from_dmg.data_rows.count }}

{{# installer.data_rows.count }}
*{{ installer.summary_text }}*
{{# installer.data_rows }}
* {{ pkg_path }}
{{/ installer.data_rows }}
{{/ installer.data_rows.count }}

{{# pkg_copier.data_rows.count }}
*{{ pkg_copier.summary_text }}*
{{# pkg_copier.data_rows }}
* {{ pkg_path }}
{{/ pkg_copier.data_rows }}
{{/ pkg_copier.data_rows.count }}

{{# pkg_creator.data_rows.count }}
*{{ pkg_creator.summary_text }}*
{{# pkg_creator.data_rows }}
* {{ identifier }} v{{ version }}
{{/ pkg_creator.data_rows }}
{{/ pkg_creator.data_rows.count }}

{{# munki_importer.data_rows.count }}
*{{ munki_importer.summary_text }}*
{{# munki_importer.data_rows }}
* {{ name }} {{ version }} Catalog:{{ catalogs }}
{{/ munki_importer.data_rows }}
{{/ munki_importer.data_rows.count }}

{{# jss_importer.data_rows.count }}
*{{ jss_importer.summary_text }}*
{{# jss_importer.data_rows }}
* {{ Package }}
{{/ jss_importer.data_rows }}
{{/ jss_importer.data_rows.count }}
