# 3 Things

The three things you can't forget to do today. Nothing more.

- **3 Things**: today's must-dos, in order of importance. Never more than three.
- **Next**: what's waiting. When one of your 3 Things is done, the top of Next moves into the last slot.
- **Done**: what you finished.

Drag any item to any list: drop it on a list in the left column, or hold it there a moment to open
that list and drop it at an exact spot. Drag within a list to reorder. Right-click works too.
Double-click to rename.

When 3 Things is full, moving something in asks **which task to swap with**. One click swaps them:
the new task takes that exact position and the old one goes where the new one came from.

The moon button at the bottom left switches to dark mode.

**Alarms**: hover an item and click the bell to pick a time. An alarm only rings while the item is in
3 Things, and rings again the next day at the same time if it's still not done. An item in Next keeps
its time and starts ringing once it moves up.

⌘1, ⌘2 and ⌘3 switch between the lists.

**Menu bar**: the circled number at the top of your screen shows how many of today's 3 Things are left.
Click it to see them and check one off in one click. Closing the window keeps 3 Things in the menu bar.

## Install (Mac)

```bash
curl -fsSL https://raw.githubusercontent.com/stoobysnax/3things/main/install.sh | bash
```

It downloads, builds and installs **3 Things** into Applications. The first time, macOS may ask to
install Apple's free Command Line Tools (not the Xcode app). Click Install, then run the command again.

## Project layout

- `Sources/ThreeThingsCore`: the list rules and saving. No UI, so the iPhone app can share it.
- `Sources/ThreeThings`: the Mac app (SwiftUI).
- `Tests/ThreeThingsCoreTests`: tests for the list rules (`swift test`).

Your lists are saved in `~/Library/Application Support/3 Things/board.json`.
