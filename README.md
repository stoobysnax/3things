# 3 Today

The three things you can't forget to do today. Nothing more.

- **3 Today**: today's must-dos, in order of importance. Never more than three. When one is done,
  the top Unscheduled task moves up.
- **Next**: everything for later, in three quiet sections:
  - **This week**: scheduled in the next 6 days, soonest first
  - **Later**: scheduled 7 or more days away
  - **Unscheduled**: no day yet
- **Done**: what you finished.

**Scheduling**: hover a task and click the calendar (or right-click → Schedule…). Pick Today,
Tomorrow, No date or any other day, and tick "Remind me at" for an optional time. Or just type it:
"tomorrow 9am", "mon", "fri 3pm", "in 3 days", "5 min", "9pm". A day holds at most 3 tasks.

**When the day changes**: anything left in 3 Today becomes **Missed**. Missed tasks sit greyed on a
soft tint below today's three, and at the top of Next. Click one to choose **Keep in today** or
**Move to Next**. Tasks scheduled for the new day move into 3 Today. (If the Mac was off on a
scheduled day, those tasks show up as missed rather than disappearing.)

**When something's full**: moving a task into a full 3 Today asks which task to swap with, or lets
you schedule it for another day instead. Scheduling a 4th task on a day shows that day's 3 so you
can swap one out. Whatever gets bumped goes to Unscheduled, and 3 Today asks whether to schedule it
for another day or leave it unscheduled.

Drag any task to any list: drop it on a list in the left column, or hold it there a moment to open
that list and drop it at an exact spot. Dropping into This week or Later takes the day of the task
you drop it next to. Drag to-dos out of Things (or any text) to create tasks. Double-click to rename.

**Alarms**: when a task's time comes, 3 Today plays a sound and shows a small window on top with
**Done** and **Dismiss**. A time on a 3 Today task rings every day until it's done; a time on a
scheduled task rings on its day. While the app is running it rings by itself (it stays in the menu
bar when you close the window); otherwise a macOS notification is used, so allow notifications.

⌘1, ⌘2 and ⌘3 switch between the lists. The moon button at the bottom left switches to dark mode.

**Menu bar**: the little 3 icon at the top of your screen shows today's 3; check one off in one click.

## Install (Mac)

```bash
curl -fsSL https://raw.githubusercontent.com/stoobysnax/3things/main/install.sh | bash
```

It downloads, builds and installs **3 Today** into Applications (replacing the old 3 Things app; your tasks carry over). The first time, macOS may ask to
install Apple's free Command Line Tools (not the Xcode app). Click Install, then run the command again.

## Project layout

- `Sources/ThreeThingsCore`: the rules (lists, scheduling, the day changing), typed dates and saving. No UI, so the iPhone app can share it.
- `Sources/ThreeThings`: the Mac app (SwiftUI).
- `Tests/ThreeThingsCoreTests`: tests for the list rules (`swift test`).

Your lists are saved in `~/Library/Application Support/3 Today/board.json`.
