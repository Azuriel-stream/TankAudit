# TankAudit

**TankAudit** is a smart, context-aware buff and consumable monitor designed specifically for Tanks in Vanilla WoW (1.12) and Turtle WoW.

Unlike generic buff monitors that just check for a static list of spells, TankAudit analyzes your **Raid Roster**, **Subgroup**, **Combat Status**, and **Location** to determine exactly what you are missing. It then provides a simple, clickable interface to request those buffs from your teammates using immersive roleplay-style chat messages.

## Features

### 🧠 Smart Roster Analysis
TankAudit scans your group composition to prevent useless alerts:
* **Class Aware:** It won't ask for *Power Word: Fortitude* if there is no Priest in the group.
* **Subgroup Aware:** It only tracks *Blood Pact* if a Warlock is in your specific party subgroup.
* **Paladin Scaling:** Automatically adjusts required Blessings based on the number of Paladins in the raid (e.g., if you have 2 Paladins, it only checks for your Top 2 priority blessings).
* **Role Aware:** Filters out useless buffs (e.g., *Arcane Intellect* is ignored for Warriors).

### ⚔️ Combat & Context Logic
* **Solo Mode:** Completely silent when you are alone and out of combat to reduce clutter.
* **Combat Mode:** Switches to "Survival Mode" in combat—ignoring food/flasks but alerting you to critical missing buffs (like *Battle Shout* or *Bear Form*) and dispellable debuffs.
* **Consumables:** Tracks Food, Flasks/Elixirs, and Weapon Enchants (Sharpening Stones/Oils/Rockbiter), but suppresses these alerts during combat.

### 💬 One-Click Request System
When a buff is missing, a clickable icon appears on your screen.
* **Click to Ask:** Sends a message to Party or Raid chat requesting the specific buff.
* **RP Flavor:** Uses randomized, roleplay-friendly messages (e.g., *"Druid, cover me in Thorns!"*) to keep chat interesting.
* **Anti-Spam:** Built-in throttle prevents you from spamming chat if you click multiple times.
* **Local Alerts:** Self-buffs (like *Weapon Stones* or *Well Fed*) display a local red warning message to you instead of spamming the raid.

### 🛡️ Supported Classes
Fully supports all Vanilla tanking classes, including Turtle WoW hybrids:
* **Warrior** (Battle Shout, Consumables)
* **Druid** (Bear Form, Thorns, Omen of Clarity)
* **Paladin** (Righteous Fury, Auras, Holy Shield)
* **Shaman** (Rockbiter Weapon, Lightning Shield, Shield Specialization)

## Installation

1.  Download the **TankAudit** folder.
2.  Place the folder into your World of Warcraft AddOns directory:
    `.../World of Warcraft/Interface/AddOns/TankAudit/`
3.  Launch the game.

## Usage

### Slash Commands
* `/taudit` - Displays the addon status and version.
* `/taudit config` - Opens the **Configuration Panel**.
* `/taudit debug` - Prints current buff textures to the chat frame (useful for debugging spell IDs).

### Configuration Panel
Access the settings via `/taudit config`.
* **General:** Enable/Disable the entire addon.
* **Filters:** Toggle specific alert categories (Consumables, Group Buffs, Self Buffs, Healthstones).
* **Visuals:** Adjust the scale of the request buttons.
* **Paladin Priority:** Reorder your preferred Blessings. The addon will use this list to determine which blessings to check for based on available Paladins.

## Interaction
* **Missing Buff:** Icon appears **Grey**. Click to request.
* **Expiring Buff (< 2 min):** Icon appears **Colored** with a timer. Click to announce expiration.
* **Expiring Self-Buff (< 30s):** Icon appears for short-duration buffs like *Battle Shout* to ensure 100% uptime.

## Author
**Azuriel**

*Developed for the Vanilla WoW community.*