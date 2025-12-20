# TankAudit

**TankAudit** is a lightweight, context-aware auditing tool designed specifically for Tanks in Vanilla (1.12) and Turtle WoW. It monitors your self-buffs, stances, debuffs, group buffs, and consumables, alerting you only when you are unprepared for combat.

## Key Features

* **Smart Context Awareness:** The auditing bar automatically hides when you are playing solo and out of combat to keep your interface clean. It instantly wakes up when you target an enemy, enter combat, or join a group.

* **NEW: Debuff Monitor:**
    * Automatically detects active **Magic**, **Curse**, **Poison**, or **Disease** effects on you.
    * **Smart Dispel:** Only alerts you if a class capable of removing that specific debuff is present in your group (and high enough level to have learned the spell).
    * **Smart Actions:**
        * **Self-Dispel:** If *you* can remove the debuff (e.g., a Paladin with *Cleanse*), clicking the button casts the spell on yourself.
        * **Group Request:** If you need help, clicking the button sends a context-rich message to chat (e.g., *"I have [Immolate] (Magic) - Dispel me please!"*).

* **One-Click Actions:** Buttons are interactive!
    * **Self-Buffs:** Left-click to auto-cast missing buffs (e.g., *Battle Shout*, *Thorns*, *Righteous Fury*, *Bear Form*).
    * **Consumables:** Left-click missing Food or Weapon Enchants to instantly open your bags.
    * **Group Requests:** Left-click missing raid buffs (e.g., *Fortitude*) to send a polite request to the group/raid chat using **clickable spell links**.
    * **Solo Mode:** Intelligently suppresses "hardcore" requirements (like Weapon Oils, Food, or Defensive Stance) when you are playing solo.

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
* **Position:** Move the bar using X/Y coordinates.
* **Test Mode:** Shows dummy buttons so you can configure the layout.
* **Toggles:** Enable/Disable checks for Food, Healthstones, or specific buff categories.

## Tracked Buffs & Mechanics

TankAudit scans your character, your inventory, and your group roster to determine exactly what you need.

### Class Abilities
The addon automatically detects your class and tracks essential tanking mechanics:
* **Self Buffs & Stances:** Alerts for missing maintenance buffs (*Righteous Fury*, *Lightning Shield*) or wrong Stance/Form (*Defensive Stance*, *Bear Form*).
* **Group Utility:** Monitors buffs provided by party members (*Fortitude*, *Mark of the Wild*, *Blessings*) and allows one-click requests.
* **Smart Filtering:**
    * Automatically hides alerts for buffs you cannot receive.
    * Intelligently detects if a Protection Paladin is present by watching for *Blessing of Sanctuary* on teammates.
    * **Dispel Rules:** Knows that a Level 20 Paladin cannot yet cast *Cleanse*, preventing false alerts for Magic debuffs in low-level dungeons.

### General / Consumables
* **Food:** Checks for "Well Fed" status (suppressed when solo) and warns when < 60s remains.
* **Weapon Buffs:** Checks for Sharpening Stones / Wizard Oils / Rockbiter (suppressed when solo) and warns when < 60s remains.
* **Healthstone:** Checks your bags if a Warlock is present in the group/raid.

## Tips
* **Leveling Friendly:** The addon checks your spellbook (by Icon) before alerting. It won't yell at a low-level Druid for missing *Bear Form* if you haven't visited the trainer yet.
* **Low Friction:** The UI is designed to be invisible when you are doing your job correctly. If the screen is empty, you are ready to pull.