# What the real Accessibility layer was heard to report

`heard.jsonl` is written by `make mac-on-linux` (`scripts/mac-on-linux/README.md`): the calls of `WindowSystemEvents` that the real `AXWindowSystem` made, in order, in every story and on the rude walk, on the model of a Mac. It is where the model below the seam meets the stand-ins at
the seam: whoever keeps a fake `WindowSystem` can hold what it sends against what the real layer has been heard to send, and see which of its orders the real layer never produced.

Everything is a function of the sources and the stories, so the file is committed. **A run of everything holds it against what it hears; if it is out of date the run rewrites it and fails that once.** Look at the difference (it says what a change to the layer did to what the controller hears) and commit it. It goes out of date by what was reported, not by `ms`: the milliseconds move with every change to the controller's timing, and for
them alone the file is left as it is, with a line that says so. To refresh them, delete the file and run again.
Runs with `--only`, `--seeds` or `REF=` leave it alone.

One JSON object to a line. No frame, no title, no name of an app.

**A story**

```json
{"heard":["appeared 102","focused 102"],"manners":"as told","ms":[515,519],"storey":1,"story":"a window opens in a running app"}
```

| | |
|---|---|
| `story` | Its name, which says what rudeness it is told with |
| `storey` | 1: the layer alone. 2: the real controller on top, whose own calls (`setFrame`, `focus`) then have their echoes among what is heard |
| `heard` | From `start()` on. The kind, and the window's number: `appeared`, `found`, `destroyed`, `focused`, `changed` (with ` user` behind the number if `userInitiated`), `replaced` old new, `dragBegan`, `dragMoved`, `dragEnded`, `dragCancelled`, `resizeBegan`, `resizeEnded`; and without a window `keyboardMoved`, `pressed`, `displaysChanged`, `refused`. `applicationActivated` is not the layer's and is left out |
| `ms` | As long as `heard`: milliseconds of the model's time since `start()`. Calls with the same number, or a few apart, come of one thing that happened |

**The walk**, one line for each kind of manners, over the usual seeds

| | |
|---|---|
| `pairs` | Which kind was followed directly by which, sorted: `focused > destroyed other`. `same`: about the same window; `other`: about another; `-`: one of the two is about none |
| `repeats` | How often a call came twice in a row word for word, by kind: what gets past the layer's own care to say a thing once |

The model does what has been seen on a Mac or guessed. An order that is missing here may still come from a real Mac; one that is here has come out of the real layer's code.
