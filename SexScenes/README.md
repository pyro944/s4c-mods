# S4C: Sex Scenes

This mod allows the player to configure custom background images during S4C sex scenes
based on which characters are participating.

## Compatibility

- Tested on Strive: Conquest 0.11.0e.
- This mod has no dependencies.
- Theoretically compatible with tw_kennels, but as of this writing it cannot be tested.

## Installation

Copy the `SexScenes` folder to your mods directory.

- Windows: `%AppData%\Strive for Power 2\mods`
- Linux:  `~/.local/share/Strive for Power 2/mods`

## Configuration

Background images should have a 16:9 ratio (eg 1920x1080). Place them in the `bg` folder.

Participants in a scene are defined in the file name of the image. For example, a scene
involving Aire and Anastasia could be named:

```
scene1 [Aire, Anastasia].png
```

The only requirement is that there is one set of square brackets containing the names of the
participants, separated by commas (`,`).

You can also use placeholders if you don't want to use a specific name. For example, a scene
involving the male main character and Cali could be:

```
scene2 [MALE_MC, Cali].png
```

Supported placeholders are:

- `MALE_MC`
- `FEMALE_MC`
- `FUTA_MC`
- `ANY_MALE`
- `ANY_FEMALE`
- `ANY_FUTA`
