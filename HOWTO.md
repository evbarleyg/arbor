# A Mac far away, and a few things to do on it

You sit at a Mac you have never used. You see it only in pictures and you touch it only with its pointer and its keyboard, one
act at a time. It is a throwaway machine: nothing on it is anybody's, and you can break nothing that matters.

It is a plain Mac, as it comes. For the tasks use whatever macOS itself offers for arranging windows.

You will be given a few small tasks, one after the other, each with a time limit. Do them as somebody would who has just sat down:
look, try, look again. **Use only what you can see on that screen and what this page names.** (`check/` and LICENSE are only the filter that reads what you send.) Do not read the repository these files came
from, its other branches, its documentation on the web, or anything else about it: what is being measured is how it goes for
somebody who knows nothing. There is no trick and nobody is marking you: when something is hard to find, confusing or does what you did not ask
for, that is the finding. Say so.

## Looking and acting

    ./mac look                          the newest picture (screen.jpg in this folder) and a few lines: which task, how long is left
    ./mac ready                         the first thing to say: the clock starts

Open screen.jpg and look at it after every act. From `ready` on, first.jpg is the picture you saw first. Places are given in the picture's own pixels, x from the left, y from the top.

    ./mac click 200 300                 also: double-click, right-click
    ./mac click 200 300 holding cmd     with keys held: fn (the globe key), ctrl, opt, shift, cmd, joined by +
    ./mac move 200 300                  only move the pointer there, and let it rest
    ./mac drag 200 30 700 400           press at the first place, move to the second, rest a second, let go
    ./mac drag 200 30 700 400 holding shift
    ./mac drag 200 30 700 400 keep      do not let go yet: look at the picture, then
    ./mac release                       let go where the pointer is, or: ./mac release 710 400
    ./mac scroll 200 300 -3             turn the wheel there: three notches down (positive: up; 60 at most; a notch is a line or so); also: holding ctrl, opt
    ./mac key cmd+n                     one press; up to four, one after the other: ./mac key cmd+n cmd+w
    ./mac type "some words"             typed on the keyboard, to whatever has it
    ./mac wait 3                        do nothing for that many seconds (1 to 10), then look
    ./mac password                      when macOS asks for the account's password: you have none, it is typed for you

Keys: letters, digits, space return tab escape delete left right up down f1 to f12 and [ ] - = , . / ; ' ` \

Every act waits until the Mac has carried it out and its windows have come to rest, then fetches the next picture: ten seconds or so.

    ./mac done                          you think the task is done: on to the next. You are not told whether you were right
    ./mac giveup "why"                  you see no way: on to the next

## Saying what it is like

These cost no time and change nothing on the Mac. They are what the whole thing is for, so be generous with them, at the moment it happens:

    ./mac surprised "what happened, and what you had expected"
    ./mac stuck "what you are looking for and cannot find"
    ./mac wrong "what you did that turned out not to be the way"
    ./mac lookup "what you had to go and look up, and where you found it"      a key, a command, a word: in a menu, a help page, the README

**Everything you send is public, at once and for good.** Say nothing about yourself, about who started you or where you run: no names, no
addresses, no links, no paths, no ids. Only what you see on that Mac. Plain ASCII; a remark is at most 200 characters. `done`, `ready` and `password` stand alone.
