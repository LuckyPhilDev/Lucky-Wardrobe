[Join the Discord](https://discord.gg/87HRHcAYP)

# Lucky's Better Wardrobe

Transmog the sets Blizzard won't let you: hundreds of extra dungeon, quest, and event sets, incomplete sets made wearable, and a collection journal that finally does what you want.

A continuation of Better Wardrobe and Transmog by SLOKnightfall.

## Features

### Collection Journal

- **Extra sets**: An Extra tab adds hundreds of sets the default list leaves out, including dungeon, questing, event, and recolor sets, each with completion counts and collected highlighting.
- **Visual view**: Click the eye icon to swap the set list for a grid of previews, the same layout you get at the transmog vendor.
- **Favourites**: Star the extra sets you care about so they float to the top.
- **Sorting**: Use Filter to sort the Sets and Extra Sets lists by completion in ascending or descending order. Ascending completion focuses on the closest sets first, with larger sets first when they need the same number of pieces.
- **Filter by source**: Under Filter > Sources, narrow either set list to where the sets actually come from. Sets covers raid, PvP, covenant, heritage, cosmetic, dungeon, and trading post, while Extra Sets covers classic, quest, dungeon, recolor, garrison, island expedition, warfronts, holiday, and trading post. Cosmetic gathers the outfit collections any class can wear, so you can browse class armour without them in the way.
- **Hide what you don't want**: Right-click any appearance or set to hide it. Hidden lists are per character and can be copied between characters or reset in one click.
- **Collection List**: Build a running list of appearances you're chasing. Tracked appearances get a book icon in the journal, and a check mark once you learn them.
- **Shopping list**: Shift-click the Collection List icon for a breakdown of every item that unlocks each tracked appearance and how to get it. With TradeSkillMaster installed, vendor, profession, and world drop items show prices.
- **TSM group export**: Turn the shopping list into a TradeSkillMaster group, sorted by appearance.
- **Item substitution**: Swap any piece in a set for a different appearance, useful when an item has left the game or you simply prefer another look.
- **Other armour types and classes**: View sets outside your own armour weight or class, with clear indicators on sets flagged for someone else.

### Set Tracker

- **Finish a set here**: Enter a dungeon or raid and a list opens showing the sets you are close to completing whose missing pieces drop there, closest to done first. Each entry names the pieces still to find, and hovering one shows which boss holds each and whether it needs a different difficulty. Click a set to open it in your appearances. Both the standard sets and the Extra sets are covered.
- **Loot alerts**: Loot a piece of a set you are close to finishing, anywhere in the world, and the addon says so with a sound, a chat line, or both. The piece lights up on the instance list if it is open. Items the catalyst could turn into an appearance you are missing get a quieter alert of their own.
- **Pieces you already hold the makings of**: A piece you are missing is stamped with a catalyst mark when you are carrying or wearing something the catalyst would turn into it, so a set reads as closer to done than the collected count alone says. Hover the piece to see which item would make it. Requires: Transmog Upgrade Master.
- **Set how close counts**: Choose how incomplete a set can be and still count, so the list and the alerts stay as narrow or as thorough as you like. Sets from the tier you are currently raiding are left out, since you will finish that one by turning up, and you can ask for them back.

### Transmog Vendor

- **Bigger preview window**: More room to see what you're building.
- **Incomplete sets**: Set how many missing pieces you'll tolerate and those sets become available, with the option to ignore specific slots. Toggle between the full set and the pieces you actually own.
- **Combine sets**: Pick a base set, then shift-click other sets to fill its empty slots from lookalikes or different raid difficulties.
- **Auto-hide missing pieces**: Empty slots on an incomplete set can be set to hidden automatically.
- **Unlimited saved outfits**: Outfits past Blizzard's cap of 20 are saved by the addon and appear in the normal outfit list.
- **Situation presets**: Save the situations you've picked for an outfit under a name, then apply the whole lot to another outfit in one click. Presets that include a specialisation stay on the class that has it. Delete them from the same menu.
- **Situation detail on outfits**: Show the values you've chosen on each outfit in the list, and hover an outfit for a tooltip with its full situation breakdown.
- **Randomizer**: Click the dice to roll a random set of armour appearances from your collection, or hold it down to keep rolling until you see something you like.

### Tooltips

- **Set completion**: Item tooltips show which set an item belongs to and how much of that set you've collected, with a full piece list or just the pieces you're missing.
- **Appearance preview**: A model preview of the item, with an option to keep it rotating.

## Installation

Extract the release zip into `World of Warcraft/_retail_/Interface/AddOns/`.

Lucky's Utils is required. Release packages include it automatically, along with the Source Data companion folder that holds the extra set database.

## Usage

1. Open the **Collections Journal** (Shift+P) and go to **Appearances**.
2. Use the **Extra** tab for sets outside Blizzard's list, and the eye icon to switch between list and visual view.
3. Right-click any set to hide it, substitute a piece, or queue it for the vendor.
4. At a transmog vendor, raise the missing-piece allowance in settings to make incomplete sets wearable, and shift-click a second set to fill the gaps.
5. Adjust everything via `/bw` or **Options > AddOns > Lucky's Better Wardrobe**.

## Slash Commands

| Command | Action |
|---|---|
| `/bw` | Open the settings panel |
| `/bw sets` | Show the sets you can finish where you are standing |
| `/betterwardrobe` | Alias for `/bw` |

A keybinding for the set list is available under **Sets You Can Finish Here** in the game's Key Bindings screen.

## Minimap Button

A minimap button opens your appearances with a left-click, the sets you can finish in your current instance with a shift-click, and these settings with a right-click. Drag it to reposition it, or hide it in settings. The addon compartment button opens your appearances too if you prefer a tidier minimap.

## Settings

Open settings with `/bw` or **Options > AddOns > Lucky's Better Wardrobe**.

- **General**: Ignore class restrictions on sets and appearances, show or hide the minimap button, and turn on dev mode for troubleshooting. Also shows version info and links to Lucky Phil's other addons.
- **Transmog Window**: Keep your active tab at the transmog NPC when switching outfits, and choose how much situation detail appears on saved outfits.
- **Set Tracker**: Choose how many pieces a set can still be missing and count as close to done, whether to include the tier you are currently raiding, which is left out by default, and whether missing pieces carry the catalyst mark. Set whether the list opens by itself in a dungeon or raid and how long it holds the middle of the screen, and whether looting a piece alerts you with a sound, a chat line, or both.

## Author

Lucky Phil
