This repository contains a set of REAPER scripts dedicated to algorithm composition, adaptive music, and interfacing with external software. They must be installed via ReaPack, using my repository link: 

```
https://raw.githubusercontent.com/daniellumertz/DanielLumertz-Scripts/master/index.xml
```

### Installation Steps:
0. Install [ReaPack](https://reapack.com) if you haven't already
1. Open REAPER
2. Go to Extensions → ReaPack → Import repositories...
3. Paste the repository URL above
4. Click OK and wait for the repository index to download
5. Go to Extensions → ReaPack → Browse packages to find and install the scripts

If you prefer to watch a video tutorial: https://www.youtube.com/watch?v=hucbceV7clg



## REAPER Scripts Highlights:

### Backup Manager (2025)
Backup Manager is a ReaScript designed to search for .rpp-bak files and delete them. It supports recursive folder scanning and includes an option to keep only the latest N backups in each directory. [More Info](https://forum.cockos.com/showthread.php?t=300616)

### Clouds (2025)
Clouds is a REAPER script designed for experimenting with texture generation. With it, you create a "Cloud Item" that stores settings and defines the texture's position. The texture is created by copying, granularizing, and randomizing a group of items (audio/MIDI/video). [More Info](https://forum.cockos.com/showthread.php?t=298170), [Video](https://www.youtube.com/watch?v=IWLGhHi0nnE)

### It's Gonna Phase (2024)
A script for experimenting with phasing, inspired by Steve Reich and Brian Eno methods.
[More Info](https://forums.cockos.com/showthread.php?t=289413)

### Adaptive Music Trilogy: Layers, ReaGoTo, Alternator (2023)
A set of 3 scripts for adaptive music techniques in REAPER: Layers, Horizontal Sequences, and Alternations. Dedicated to game music techniques and live music.
[More Info](https://forum.cockos.com/showthread.php?t=276313)

### Bartoker (2022)
Script dedicated to generate small compositions with a structure from Bartok's *Music for Children Nº3*. The user is encouraged to experiment with the parameters to diverge from the original composition. This approach for music generation reflects how I study my references: identifying and experimenting with structures, resources, and characteristics, rather than replicating a style.
[More Info](https://forum.cockos.com/showthread.php?p=2583193)

### MIDI Toolkit (2022)
A collection of 4 modules for manipulating MIDI parameters: Copy Paste, Rotator, Mapper, and Serializer. Designed for experimenting with parametric composition and serialism techniques.
[More Info](https://forum.cockos.com/showthread.php?t=272241)

### Markov Chains (2022)
A script for symbolic music generation using Markov chains algorithm. Generates variations of MIDI items using transition probabilities, allowing manipulation of pitch, interval, rhythm, measure position, and velocity.
[More Info](https://forum.cockos.com/showthread.php?p=2606674)

### Track Snapshot (2022)
A script to save and load track states in REAPER.
[More Info](https://forum.cockos.com/showthread.php?t=264124)

### Microrhythms (2022)
Based on Malcolm Braff's work, this script allows users to experiment with rhythm interpolation between equal divisions and user-defined ratios.
[More Info](https://forum.cockos.com/showthread.php?p=2575284)

### Fake Grids (2022)
A script to create a flexible grid by placing markers in REAPER, useful for complex time signatures or microrhythms.
[More Info](https://forum.cockos.com/showthread.php?t=272321)

### Item Sampler (2022)
A sequencer that places audio or MIDI items at MIDI notes. It can serve as a random sequencer to generate musical ideas.
[More Info](https://forum.cockos.com/showthread.php?t=262927)

### ReaShare (2022)
A script to share REAPER projects, tracks, and items by copying and pasting text, simplifying file sharing for quick collaboration or bug reporting.
[More Info](https://forum.cockos.com/showthread.php?p=2568492)

### MIDI Transfer (2021)
A script that assists in interfacing MIDI from external software to REAPER. Making external software act as a MIDI editor for REAPER. Useful for notation editors (MuseScore, Sibelius, Dorico) and algorithm composition frameworks.
[More Info](https://forum.cockos.com/showthread.php?t=248475)

### Sample Organizer (2021)
A script for organizing and grouping samples by cutting and placing them into designated positions. It's useful for sample pack creation and improvisation sessions.
[More Info](https://forum.cockos.com/showthread.php?t=255294)

### DL Functions (continuous work)
A set of functions I use for my scripts, feel free to use them



## Also on this repository:

### Lua Sockets Demo
Set of scripts to demonstrate the use of Lua Sockets in REAPER. [Thread](https://forum.cockos.com/showthread.php?p=2551512) [Video](https://www.youtube.com/watch?v=tIdAylKsvCE)

### Pitch Class Counter 
UI counting the pitch class of selected MIDI Notes. [More Info](https://forum.cockos.com/showthread.php?t=255427&highlight=pitch+class)

### Set Last Touched Parameter 
Set a MIDI CC as shortcut for this script, the MIDI CC will controll whichever FX parameter was last touched.

###  Item Clipboard History
Simillar to Windows Clipboard History. [More Info](https://forum.cockos.com/showthread.php?t=263986&highlight=Clipboard)

### MOD of BirdBird Envelope Palette
Mod of [BirdBird Envelope Palette](https://forum.cockos.com/showthread.php?p=2643774), this mod adds the feature for take envelopes. 

### Split Items in MIDI Notes
This script processes selected media items to split MIDI notes into individual items. It can optionally copy only note events, trim notes to item edges, and rename the resulting items based on their pitch. Each MIDI note is isolated into its own media item while maintaining timing and playback rate integrity.

### Multikey 
Script to add multikey functionality, simillar to VIM. Edit multikey_bind.txt to add your commands and actions. Forked from Lermerchand Script.

### Render Selected Items In New Tracks
For each selected item, render its track within the item's time range and place the resulting item on a new track.





