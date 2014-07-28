return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0,

	LrToolkitIdentifier = 'com.mikeboers.lightroom.export.flask',
	LrPluginName = "Flask",
	
	LrExportServiceProvider = {
		title = "Flask",
		file = 'FlaskPublishServiceProvider.lua',
	},
	
	LrMetadataProvider = 'FlaskMetadataDefinition.lua',
	
	VERSION = {
		major=0,
		minor=1,
		revision=0,
		build=0,
	},

}
