--@noindex
ToolTips = {
    create_item = 'This button will create a cloud Item.\nSelect a cloud item to set the parameters and generate clouds!',
    items = {
        head = 'Set which items will be copied.',
        set = 'Set items list to current item selection.',
        add = 'Add selected items to the list.',
        select = 'Select the items in the items list',
        w = 'Chance to choose this item.',
        x = 'Remove item from list.'
    },
    density = {
        density = {
            density = 'The average number of items generated per second by this cloud.\nRight-click to set this value in proportion to the grain size, if applicable.',
            density_ratio = '100% = Density is equivalent to put grains juxtaposed.\n200% = Density is equivalent to have each grain make a complete crossfade between previous and next.\n50% Density is equal to have a grain size gap between each item.',
            env = 'Enables a take envelope to control density over time.\nAt maximum position it will be the current density value.\nAt the lowest position it will be a minimum value, which can be set by right clicking this checkbox.'
        },
        dust = {
            dust = 'Dust affects the metric of item placement density.\nA dust value of 0 results in a steady arrangement of items.\nDust value of 1 introduces randomization within a range of 1 divided by the frequency in seconds.',
            env = 'Enables an take envelope to control dust over time.\nAt maximum position it will be the current dust value\nAt the lowest position it will be 0.'
        },
        max = 'Set the maximum number of simultaneous items.'
    },
    grains = {
        on = 'Turn on granulation of items.',
        size = {
            size = 'Set the size of each grain. Right click to set it in proportion to the density frequency.',
            size_ratio = '100% = Size is equivalent to put grains juxtaposed.\n200% = Size is equivalent to have each grain make a complete crossfade between previous and next.\n50% Size is equal to have a grain size gap between each item.',
            size_env = 'Enables an take envelope to control size over time.\nAt maximum position it will be the current size value.\nAt the lowest position it will be a minimum value, which can be set by right clicking this checkbox.'
        },
        size_drift = {
            on = 'Randomize the size of each grain',
            size_drift = 'Randomize the size of each grain, considering 100% equal to the grain size.',
            env = 'Enables an take envelope to set the size randomization over time.'
        },
        position = {
            on = 'Set a start position for each grain. If false position is random.',
            position = 'Set the position to start each item.',
            env = 'Enables an take envelope to set the position over time.'
 
        },
        position_drifts = {
            on = 'Randomize the position of each grain.',
            drifts = 'Set maximum and minimum values for randomizing the position of the take item.',
            env = 'Enables an take envelope to set the position drift over time.'
        },
        fade = 'To add fade-in fade-out. 100% means fade in and fade out side-by-side.'
    },
    midi ={
        head = 'Randomize parameters of the pasted items',
        solo_notes = 'If this option is ON it will generate items only where there are MIDI notes at the Cloud Item.\nNotes at the cloud item will randomize the items pitch, considering "MIDI center" as 0 transposition.\nOverlapped notes will be randomly chosen per item, velocity controls the weight of each note.',
        edo = 'How many notes per octave',
        center = 'Which MIDI note will be used to play the audio without any transposition.',
        a4 = 'Tuning of the A4 note',
        synth = 'The density is defined by the notes placed on the cloud item.\nEx: A4 will put 440 items/second\nIn synth mode you are obliged to use grains.\nMight be hard on resources, experimental feature.'
    },
    randomization = {
        volume  = {
            on = 'Add a random value, between min and max, to the volume of the item.',
            env = 'Enables a take envelope, that control the range of randomization over time. At maximum the range is what the user defined, at 0% the range is 0.'
        },
        pan= {
            on = 'Set a random value, between min and max, as the pan of the item.',
            env = 'Enables a take envelope, that control the range of randomization over time. At maximum the range is what the user defined, at 0% the range is 0.'
        },
        pitch= {
            on = 'Add a random value, between min and max, to the pitch of the item.',
            env = 'Enables a take envelope, that control the range of randomization over time. At maximum the range is what the user defined, at 0% the range is 0.'
        },
        playrate= {
            on = 'Multiply a random value, between min and max, with the playrate of each item.',
            env = 'Enables a take envelope, that control the range of playrate over time. At maximum the range is what the user defined, at 0% the range is 0.'
        },
        reverse = {
            on = 'Set the chance of each item be reversed',
            env= 'Enables a take envelope, that control the chance over time. At maximum the range is what the user defined, at 0% the chance is 0.'
        }
    },
    tracks = {
        head = 'Set which tracks items will be copied.',
        set = 'Set track list to current track selection.',
        add = 'Add selected tracks to the list.',
        select = 'Select the tracks in the tracks list',
        w = 'Chance to choose this track.',
        x = 'Remove track from list.'
    },
    buttons = {
        fix = 'Fixate selected cloud item at this interface. So you can unselect it.',
        copy = 'Copy settings of this cloud item.',
        paste = 'Paste settings to this cloud item.'
    }
}

    