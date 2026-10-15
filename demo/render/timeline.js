// What the film adds to the pictures of the display: captions, what the hands do, and the end card. It reads the whole film once,
// because a caption that fades out has to know when its time is up, and then answers for any frame.
//
// None of this is Arbor's doing, and none of it is drawn on the display.

const Timeline = (() => {
  const clamp = (value) => Math.min(Math.max(value, 0), 1);
  // Gentle at both ends.
  const ease = (value) => { const t = clamp(value); return t * t * (3 - 2 * t); };

  function make(film, frames) {
    const fps = film.fps;
    const seconds = (s) => Math.round(s * fps);

    // Captions: from the frame a text first shows to the frame it is replaced or cleared.
    const captions = [];
    frames.forEach((frame, n) => {
      const text = (frame.marks || {}).caption;
      const last = captions[captions.length - 1];
      if (last && last.end === undefined && last.text !== text) last.end = n;
      if (text && (!last || last.end !== undefined)) captions.push({ text, start: n, follows: !!last && last.end === n });
    });

    // A note: `mark note <text>`, a quiet line under the caption, for what has to be said and is not the story.
    const notes = [];
    frames.forEach((frame, n) => {
      const text = (frame.marks || {}).note;
      const last = notes[notes.length - 1];
      if (last && last.end === undefined && last.text !== text) last.end = n;
      if (text && (!last || last.end !== undefined)) notes.push({ text, start: n });
    });

    // For every frame in which the menu is open: the title of the row that is chosen from it in the end.
    const chosen = {};
    frames.forEach((frame, n) => {
      const pressed = frame.menu && frame.pointer.down && frame.menu.rows.find((r) => r.highlighted);
      if (!pressed) return;
      // Known with hindsight, it is said from the menu's first frame on: nobody can read a menu on a phone.
      for (let i = n; i >= 0 && frames[i].menu; i -= 1) chosen[i] = pressed.title;
    });

    // Hands: spans of frames with something to show at the right of the band.
    const hands = [];
    const open = () => hands[hands.length - 1];
    frames.forEach((frame, n) => {
      const keys = frame.keys;
      if (keys) {
        // Modifier keys held by themselves have no key.
        const names = keys.key === undefined ? [...keys.modifiers] : [...keys.modifiers, keys.key];
        const last = open();
        const id = names.join('+');
        // The same shortcut again within a second: the caps stay and go down once more.
        if (last && last.id === id && (last.until >= n - 1 || (keys.modifiers.length && n - last.until <= seconds(1)))) {
          last.until = n;
        } else if (!keys.modifiers.length && keys.key && keys.key.length === 1 && last && last.typing && n - last.until < seconds(0.8)) {
          // Letters typed one after the other stand side by side, as a word being spelt.
          if (last.lastKeyAt !== n - 1 || last.lastKey !== keys.key) last.keys = [...last.keys, keys.key];
          last.lastKeyAt = n;
          last.lastKey = keys.key;
          last.until = n;
        } else {
          hands.push({
            id, keys: names, start: n, until: n, held: keys.key === undefined, typing: !keys.modifiers.length && !!keys.key && keys.key.length === 1, lastKeyAt: n, lastKey: keys.key,
          });
        }
        if (open().typing) open().lastKeyAt = n;
      }
      // A choice from the menu: the words of the row that is chosen, from the moment the pointer comes to it, since nobody can read a
      // menu on a phone. `chosen` was worked out beforehand: for each frame with the menu open, the row its visit ends on.
      const row = chosen[n];
      if (row) {
        const last = open();
        if (last && last.text === row && last.until >= n - 1) last.until = n;
        else hands.push({ text: row, menu: true, start: n, until: n });
      }
    });
    // What was shown stays for a moment after the hands have let go, unless the next thing wants the place.
    hands.forEach((span, index) => {
      // A modifier key held by itself goes with the finger: shown for longer it would say that it is still down.
      const linger = seconds(span.menu ? 1.8 : span.held ? 0.3 : 1.5);
      const next = hands[index + 1];
      // Nor does it outstay the caption it was shown under: it has faded when the next one comes.
      const change = captions.find((c) => c.start > span.until);
      // Nor the next thing the hands do: keys that stand while the button goes down say that they belong to the drag.
      const press = span.keys ? frames.findIndex((frame, n) => n > span.until + seconds(0.5) && frame.pointer.down) : -1;
      span.end = Math.min(press < 0 ? Infinity : press - seconds(0.25), span.until + linger, next ? next.start - (next.keys && !next.typing ? seconds(0.35) : 0) : Infinity, change ? Math.max(change.start - seconds(0.25), span.until + seconds(0.5)) : Infinity);
    });

    // Presses: the frames at which the button went down, and where.
    const presses = [];
    frames.forEach((frame, n) => {
      // Not on a row of the menu: the menu goes with the click, and the ring would be left standing on whatever lay under it. The row's own
      // highlight says what is chosen.
      if (frame.pointer.down && (n === 0 || !frames[n - 1].pointer.down) && !(n > 0 && frames[n - 1].menu)) presses.push({ n, at: frame.pointer.at });
    });

    // "Look here": `mark look item`, Arbor's menu bar item wherever it is, or `mark look <x> <y>`: for what is too small to be noticed on
    // a phone. From the frame the mark first shows.
    const looks = [];
    frames.forEach((frame, n) => {
      const value = (frame.marks || {}).look;
      const before = n > 0 ? (frames[n - 1].marks || {}).look : undefined;
      if (!value || value === before) return;
      if (value !== 'item') return looks.push({ n, at: value.split(' ').map(Number) });
      if (!frame.menuBar) throw new Error(`frame ${n}: look at Arbor's menu bar item, which is not there`);
      const [x, y, width, height] = frame.menuBar.frame;
      looks.push({ n, at: [x + width / 2, y + height / 2] });
    });

    // An app that wants attention: `mark bounce.<App> 1` makes its icon hop in the Dock, as macOS has it, three times from then on.
    const bounces = [];
    frames.forEach((frame, n) => {
      for (const name of Object.keys(frame.marks || {})) {
        if (name.startsWith('bounce.') && !(n > 0 && (frames[n - 1].marks || {})[name])) bounces.push({ n, app: name.slice(7) });
      }
    });

    // The end card: marks called card.1, card.2 … of the form `<kind> <text>`, each from the frame it first shows.
    const card = [];
    frames.forEach((frame, n) => {
      for (const [name, value] of Object.entries(frame.marks || {})) {
        if (!name.startsWith('card.') || card.some((line) => line.name === name)) continue;
        const [kind, ...words] = value.split(' ');
        card.push({ name, order: Number(name.slice(5)), kind, text: words.join(' '), start: n });
      }
    });
    card.sort((a, b) => a.order - b.order);
    const styles = {
      mark: { height: 180 }, title: { height: 110, size: 92, weight: 700, colour: '#fff' },
      sub: { height: 66, size: 46, weight: 600, colour: '#fff' },
      line: { height: 66, size: 40, weight: 400, colour: 'rgba(255,255,255,0.78)' },
      lead: { height: 70, size: 30, weight: 400, colour: 'rgba(255,255,255,0.6)' },
      link: { height: 70, size: 50, weight: 650, colour: 'rgb(110,220,155)' },
    };
    const total = card.reduce((sum, line) => sum + styles[line.kind].height, 0);
    let y = (1080 - total - 54) / 2;
    for (const line of card) {
      const style = styles[line.kind];
      Object.assign(line, style, { y: y + style.height / 2 + (line.kind === 'line' ? 34 : line.kind === 'lead' ? 62 : line.kind === 'link' ? 54 : 0) });
      y += style.height;
    }

    function at(n) {
      const shownCaptions = [];
      for (const c of captions) {
        const end = c.end === undefined ? Infinity : c.end;
        const arrive = ease((n - c.start - (c.follows ? seconds(0.18) : 0)) / seconds(0.3));
        const leave = n < end ? 1 : 1 - ease((n - end) / seconds(0.18));
        const alpha = arrive * leave;
        if (alpha > 0) shownCaptions.push({ text: c.text, alpha, rise: (1 - arrive) * 14 });
      }
      const shownNotes = [];
      for (const note of notes) {
        const alpha = ease((n - note.start) / seconds(0.4)) * (note.end === undefined || n < note.end ? 1 : 1 - ease((n - note.end) / seconds(0.3)));
        if (alpha > 0) shownNotes.push({ text: note.text, alpha });
      }
      let shownHands = null;
      for (const [index, span] of hands.entries()) {
        // Keys are shown a moment before they go down, as fingers find them first, so that press and result can be told apart.
        const before = hands[index - 1];
        const lead = span.keys && !span.typing ? Math.min(seconds(0.35), Math.max(span.start - (before ? before.until + 1 : 0), 0)) : 0;
        if (n < span.start - lead || n >= span.end + seconds(0.25)) continue;
        const alpha = ease((n - span.start + lead + 1) / seconds(0.07)) * (n < span.end ? 1 : 1 - ease((n - span.end) / seconds(0.25)));
        shownHands = {
          keys: span.keys, text: span.text && (span.menu ? `Arbor’s menu  ›  ${span.text}` : span.text), alpha, typing: !!span.typing,
          // A tap is over in a tenth of a second; the cap stays down for three, so that it is seen.
          down: frames.slice(Math.max(n - seconds(0.22), 0), n + 1).some((frame) => frame.keys),
        };
        // A word being spelt shows only the letters typed so far.
        if (span.typing) shownHands.keys = span.keys.slice(0, lettersBy(span, n));
      }
      let shownCard = null;
      if (card.length && n >= card[0].start) {
        shownCard = {
          dim: ease((n - card[0].start) / seconds(0.6)),
          lines: card.map((line) => {
            const arrive = ease((n - line.start - seconds(0.2)) / seconds(0.5));
            return { ...line, alpha: arrive, rise: (1 - arrive) * 18 };
          }),
        };
      }
      const pressed = presses.findLast((press) => press.n <= n && n - press.n < seconds(0.45));
      const press = pressed ? { at: pressed.at, age: (n - pressed.n) / seconds(0.45) } : null;
      const looked = looks.findLast((look) => look.n <= n && n - look.n < seconds(1.8));
      const look = looked ? { at: looked.at, age: (n - looked.n) / seconds(1.8) } : null;
      const bounce = {};
      for (const hop of bounces) {
        const t = (n - hop.n) / seconds(0.62);
        if (t >= 0 && t < 3) bounce[hop.app] = Math.abs(Math.sin(Math.PI * (t % 1)));
      }
      return { captions: shownCaptions, notes: shownNotes, hands: shownHands, card: shownCard, press, look, bounce };
    }

    // How many letters of a typed word were down by frame n.
    function lettersBy(span, n) {
      let count = 0;
      let was = null;
      for (let i = span.start; i <= Math.min(n, span.until); i += 1) {
        const key = frames[i].keys ? frames[i].keys.key : null;
        if (key && key !== was) count += 1;
        was = key;
      }
      return Math.max(count, 1);
    }

    return { at, captions, notes, hands, card };
  }

  return { make };
})();

if (typeof module !== 'undefined') module.exports = Timeline;
