local Lr = require 'Lr'


local log = Lr.Logger()
log:enable('print')

local share = Lr.View.share
local append = function(t, x) t[#t + 1] = x end



Lr.Tasks.startAsyncTask(function()
Lr.FunctionContext.callWithContext('FlaskSandbox', function(context)

    local catalog = Lr.Application:activeCatalog()

    local ui = Lr.View.osFactory()
    local props = Lr.Binding.makePropertyTable(context)
    
    local photo = catalog:getTargetPhoto()

    -- download the thumbnail
    local thumbnailUrl = 'http://localhost:8000/imgsizer/photos/2014-11-24/140927154446-2275-17.jpg?h=200&m=fit&q=90&v=VHKTVg&w=200&s=pJ_WwbWV4vUOrRdVRMpJs2jRBQg'
    local tempDir = Lr.PathUtils.getStandardFilePath('temp')
    local thumbnailPath = Lr.PathUtils.child(tempDir, Lr.MD5.digest(thumbnailUrl) .. '.jpg')

    local fh = io.open(thumbnailPath, 'r')
    if fh then
        fh:close()
    else
        local body, headers = Lr.Http.get(thumbnailUrl)
        if not body then return end
        local fh = io.open(thumbnailPath, 'w')
        fh:write(body)
        fh:close()
    end

    log:info('thumbnail', thumbnailPath)

    local size = photo:getRawMetadata('croppedDimensions')
    local target = 198
    if (size.width / target) < (size.height / target) then
        size.width = size.width * target / size.height
        size.height = target
    else
        size.height = size.height * target / size.width
        size.width = target
    end

    -- Create the contents for the dialog.
    local c = ui:row {

        bind_to_object = props,
        spacing = ui:control_spacing(),

        ui:column {

            spacing = ui:control_spacing(),

            width = 200,
            ui:static_text {
                title = photo:getFormattedMetadata("fileName"),
                place_horizontal=0.5,
            },
            ui:row {
                height = 200,
                place_horizontal=0.5,
                ui:column {
                    place_vertical=0.5,
                    place_horizontal=0.5,
                    ui:catalog_photo {
                        photo = photo,
                        width = size.width,
                        height = size.height,
                        frame_width = 1,
                    },
                },
            }
        },

        ui:column {
            
            width = 200,
            spacing = ui:control_spacing(),

            ui:static_text {
                title = photo:getFormattedMetadata("fileName"),
                place_horizontal=0.5,
            },

            ui:picture {
                value = thumbnailPath,
                width = 200,
                height = 200,
                frame_width = 1,
            },
        },

    }

    local res = Lr.Dialogs.presentModalDialog {
        title = "Dev Sandbox",
        contents = c,

        actionVerb = 'Link',
        cancelVerb = 'Skip',
        otherVerb = 'Cancel',
    }
    if res ~= 'ok' then return end




end)
end)

