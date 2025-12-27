# TankAudit

**TankAudit** is a lightweight, context-aware auditing tool designed specifically for Tanks in Vanilla (1.12) and Turtle WoW. It monitors your self-buffs, stances, debuffs, group buffs, and consumables, alerting you only when you are unprepared for combat.

## Key Features

* **Smart Context Awareness:** The auditing bar automatically hides when you are playing solo and out of combat to keep your interface clean. It instantly wakes up when you target an enemy, enter combat, or join a group.

* **Context-Aware Gratitude (v1.4.0):**
    * When you request a buff (e.g., *Kings*) and receive it shortly after, your character will automatically thank the specific player who cast it in chat (e.g., *"Thanks for the [Blessing of Kings], PaladinBob!"*).

* **Consumable Tracking Modes:**
    * **Level 1 (Default):** Tracks Food only.
    * **Level 2:** Tracks Food + Elixirs (Flasks count as Elixirs).
    * **Level 3:** Tracks Food + Flasks (Hardcore mode).

* **Debuff & Unwanted Buff Monitor:**
    * **Smart Dispel:** Alerts you to Magic, Curse, Poison, or Disease effects only if your group has a class capable of dispelling them.
    * **Salvation Canceller:** Automatically detects *Blessing of Salvation* on you (a tank's nightmare) and displays a red warning button. Clicking the button instantly cancels the buff.

* **One-Click Actions:** Buttons are interactive!
    * **Self-Buffs:** Left-click to auto-cast missing buffs (e.g., *Battle Shout*, *Righteous Fury*, *Bear Form*).
    * **Consumables:** Left-click missing Food/Elixirs to instantly open your bags.
    * **Group Requests:** Left-click missing raid buffs (e.g., *Fortitude*) to send a polite request to chat with **clickable spell links**.

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
* **Consumable Mode:** Choose between tracking Food Only, Elixirs, or Flasks.
* **Button Scale:** Resize the UI to fit your screen.
* **Position:** Move the bar using X/Y coordinates.
* **Paladin Priority:** Drag and drop blessings to set your preferred request order.

## Tracked Buffs & Mechanics

TankAudit scans your character, your inventory, and your group roster to determine exactly what you need.

### Class Abilities
* **Warrior:** Battle Shout, Defensive Stance.
* **Druid:** Mark of the Wild, Thorns, Bear Form.
* **Paladin:** Righteous Fury, Paladin Auras (Devotion or Retribution), Blessings (Kings, Might, Light, Sanctuary). *Supports Greater Blessings.*
* **Shaman:** Lightning Shield, Rockbiter Weapon.
* **Priest/Mage:** Fortitude, Spirit, Intellect.

### Smart Filtering
* **Solo Mode:** Intelligently suppresses "hardcore" requirements (like Weapon Oils or Food) when you are playing solo.
* **Role Detection:** Detects if a Protection Paladin is present (by watching for *Blessing of Sanctuary*) to avoid asking Holy Paladins for tank buffs.
* **Level Awareness:** Knows that a Level 20 Paladin cannot yet cast *Cleanse*, preventing false alerts for Magic debuffs in low-level dungeons.