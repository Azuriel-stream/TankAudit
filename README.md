# TankAudit

**TankAudit** is a lightweight, context-aware auditing tool designed specifically for Tanks in Vanilla (1.12) and Turtle WoW. It monitors your self-buffs, stances, group buffs, and consumables, alerting you only when you are unprepared for combat.

## Key Features

* **Smart Context Awareness:** The auditing bar automatically hides when you are playing solo and out of combat to keep your interface clean. It instantly wakes up when you target an enemy, enter combat, or join a group.
* **One-Click Actions:** Buttons are interactive!
    * **Self-Buffs:** Left-click to auto-cast missing buffs (e.g., *Battle Shout*, *Thorns*, *Righteous Fury*, *Bear Form*).
    * **Consumables:** Left-click missing Food or Weapon Enchants to instantly open your bags.
    * **Group Requests:** Left-click missing raid buffs (e.g., *Fortitude*) to send a polite request to the group/raid chat.
* **Solo Mode:** Intelligently suppresses "hardcore" requirements (like Weapon Oils, Food, or Defensive Stance) when you are playing solo, so you can quest in peace.
* **Dynamic UI:** The button bar is centered, scalable, and movable. It grows and shrinks dynamically based on how many alerts are active.

## Installation

### Turtle WoW Launcher / GitAddonsManager
1.  Open either application.
2.  Click the **Add** button.
3.  Paste the url: `https://github.com/Azuriel-stream/TankAudit`
4.  Download and keep up to date.

### Manual Installation
1.  Download the latest **.zip** file from the Releases page.
2.  Extract the contents.
3.  Ensure the folder is named `TankAudit` (remove `-main` or version numbers if present).
4.  Move the folder to your `\World of Warcraft\Interface\AddOns\` directory.

## Configuration

Type `/taudit` to open the configuration panel.

* **Button Scale:** Resize the UI to fit your screen.
* **Position:** Move the bar using X/Y coordinates (or simply drag the invisible anchor while in config mode).
* **Test Mode:** Shows dummy buttons so you can configure the layout without being unbuffed.
* **Toggles:** Enable/Disable checks for Food, Healthstones, or specific buff categories.

## Tracked Buffs & Mechanics

TankAudit scans your character, your inventory, and your group roster to determine exactly what you need.

### Class Abilities
The addon automatically detects your class and tracks essential tanking mechanics:
* **Self Buffs & Stances:** Alerts you if you are missing critical maintenance buffs (e.g., *Righteous Fury*, *Lightning Shield*) or are in the wrong Stance/Form for tanking (e.g., *Defensive Stance*, *Bear Form*).
* **Group Utility:** Monitors powerful buffs provided by your party members (e.g., *Fortitude*, *Mark of the Wild*, *Blessings*, *Thorns*) and lets you request them with a click.
* **Smart Filtering:** * Automatically hides alerts for buffs you cannot receive (e.g., prevents Paladin Aura alerts if the Paladin is in a different subgroup).
    * **Passive Detection:** Intelligently detects if a Protection Paladin is present by watching for *Blessing of Sanctuary* on teammates before asking for it.

### General / Consumables
* **Food:** Checks for "Well Fed" status (suppressed when solo) and warns when < 60s remains.
* **Weapon Buffs:** Checks for Sharpening Stones / Wizard Oils / Rockbiter (suppressed when solo) and warns when < 60s remains.
* **Healthstone:** Checks your bags if a Warlock is present in the group/raid.

## Tips
* **Leveling Friendly:** The addon checks your spellbook before alerting. It won't yell at a low-level Druid for missing *Bear Form* or a Warrior for missing *Defensive Stance* if you haven't visited the trainer to learn them yet.
* **Low Friction:** The UI is designed to be invisible when you are doing your job correctly. If the screen is empty, you are ready to pull.