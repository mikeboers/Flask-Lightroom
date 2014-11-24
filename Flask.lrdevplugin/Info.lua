return {

	LrSdkVersion = 5.0,
	LrSdkMinimumVersion = 5.0,

	LrToolkitIdentifier = 'com.mikeboers.lightroom.export.flask',
	LrPluginName = "Flask",
	
	LrMetadataProvider = 'FlaskMetadata.lua',

	LrExportServiceProvider = {
		title = "Flask",
		file = 'FlaskPublishServiceProvider.lua',
	},

    LrLibraryMenuItems = {
        {
            title = "Discover Published Photos",
            file  = "FlaskDiscoverPhotos.lua",
        }, {
            title = "Development Sandbox",
            file  = "FlaskSandbox.lua",
        },
    },
	
	VERSION = {
		major =    0,
		minor =    1,
		revision = 0,
		build =    0,
	},

}
