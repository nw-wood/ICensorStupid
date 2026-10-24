# ICensorStupid (v2.0.0)

**Factorio 2.0 Mod** — Removes random backer names from newly built and existing **Labs**, **Roboports**, **Radars**, **Train stops**, and **Locomotives** across all surfaces.

> *"Because you don't want to be reminded of the existence of brownslurper420 while building a train network or laboratory farm."*

## Features (v2.0.0)
- Updated for **Factorio 2.0** (`base >= 2.0.0`).
- Automatically clears backer names on all existing surfaces upon game init, configuration changes, and cutscene completion.
- Clears backer names immediately when entities are built via:
  - Player construction (`on_built_entity`)
  - Construction robots (`on_robot_built_entity`)
  - Space platforms (`on_space_platform_built_entity`)
  - Scripts / ghosts (`script_raised_built`, `script_raised_revive`)
- Covers `lab`, `roboport`, `radar`, `train-stop`, and `locomotive` prototypes.

## Installation
Download `ICensorStupid_2.0.0.zip` from [GitHub Releases](https://github.com/nw-wood/ICensorStupid/releases) and place it in your Factorio `mods/` directory.

## License
Licensed under the [GNU General Public License v3.0](LICENSE.md).
