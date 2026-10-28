@tool
extends EditorPlugin
## Inclui o plugin Android de anúncios (android_plugin/) na exportação.
## O arquivo bin/aqua-ads.aar é gerado pelo GitHub Actions.

const ADMOB_APP_ID := "ca-app-pub-4311255826061303~5610988046"
const ADS_SDK := "com.google.android.gms:play-services-ads:23.6.0"
const REMOVED_PERMISSIONS := [
	"com.google.android.gms.permission.AD_ID",
	"android.permission.ACCESS_ADSERVICES_AD_ID",
	"android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
	"android.permission.ACCESS_ADSERVICES_TOPICS",
]

var _export: AquaAdsExport


func _enter_tree() -> void:
	_export = AquaAdsExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AquaAdsExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "AquaAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["aqua_ads/bin/aqua-ads.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([ADS_SDK])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n' % ADMOB_APP_ID

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		# Jogo infantil: não usa o ID de publicidade nem as APIs de rastreamento
		# do aparelho (política Famílias da Google Play).
		var text := ""
		for permission in REMOVED_PERMISSIONS:
			text += '<uses-permission android:name="%s" tools:node="remove"/>\n' % permission
		return text
