// The scenery of the demo film: a desktop of our own drawing for Arbor's real code to move windows on.
//
// Everything here is painted with canvas paths: wallpaper, menu bar, Dock, icons, windows with their contents
// and the pointer. There is no artwork of anybody else's in it, no image, no network and no dependency.
//
// All coordinates are points, origin top left, y down; the caller has already scaled the context. Nothing
// depends on chance or on the clock: the same arguments paint the same pixels. Every function leaves the
// context as it found it. See gallery.html for all of it on one page.

const Scenery = (() => {
  'use strict';

  const sans = "'Inter', sans-serif";
  const display = "'Inter Display', 'Inter', sans-serif";
  const mono = "'DejaVu Sans Mono', monospace";

  // Chosen to differ in lightness as well as in hue (L* 18, 43, 44, 56, 75, 84; the two that are close are
  // blue and magenta), so that they stay apart for the three common kinds of colour blindness.
  const apps = {
    Browser: { colour: '#2460d8' },
    Mail: { colour: '#55c4ee' },
    Terminal: { colour: '#2b2d33' },
    Chat: { colour: '#b02f92' },
    Notes: { colour: '#ffc93c' },
    Call: { colour: '#36993f' },
  };

  const windowRadius = 17;
  const titleBarHeight = 28;

  const ink = { strong: '#1d1d1f', body: '#3b3b40', soft: '#85858c', faint: '#b7b7bd' };
  const hairline = 'rgba(0,0,0,0.09)';
  const people = {
    Ana: '#dd7a55', Ben: '#4a86cf', Mia: '#2f9e86', Tom: '#8d6fd1', Eva: '#c9a227', Leo: '#5b8f3a',
    Ida: '#c75d8c', Sam: '#5f7f95', Zoe: '#d0663f', Max: '#3f8fa8', Kim: '#9a7b4f',
  };

  // ------------------------------------------------------------------------------------------- small tools

  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const font = (weight, size, family = sans) => `${weight} ${size}px ${family}`;

  function channels(hex) {
    return [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));
  }

  function mix(from, to, share) {
    const a = channels(from), b = channels(to);
    return `rgb(${a.map((value, i) => Math.round(value + (b[i] - value) * share)).join(',')})`;
  }

  function fade(hex, alpha) {
    return `rgba(${channels(hex).join(',')},${alpha})`;
  }

  // Shadows and filters ignore the context's transform, so whoever uses them has to know the scale.
  function scaleOf(ctx) {
    const t = ctx.getTransform();
    return Math.hypot(t.a, t.b) || 1;
  }

  function offscreen(width, height) {
    if (typeof OffscreenCanvas !== 'undefined') return new OffscreenCanvas(width, height);
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    return canvas;
  }

  // A canvas that will not change any more is cheaper to paint from as a bitmap: a canvas is copied every time.
  function settled(canvas) {
    return canvas.transferToImageBitmap ? canvas.transferToImageBitmap() : canvas;
  }

  // Adds a rectangle with circular corners to the current path.
  function roundedRect(ctx, x, y, w, h, r) {
    const k = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.moveTo(x + k, y);
    ctx.arcTo(x + w, y, x + w, y + h, k);
    ctx.arcTo(x + w, y + h, x, y + h, k);
    ctx.arcTo(x, y + h, x, y, k);
    ctx.arcTo(x, y, x + w, y, k);
    ctx.closePath();
  }

  // The same with corners that ease into the straight edges instead of starting all at once. Each corner begins
  // 1.4 radii from the tip, and its handles are set so that it passes where the circle of that radius would:
  // an outline drawn with roundedRect around it stays within a fraction of a point.
  function smoothRect(ctx, x, y, w, h, r) {
    const a = Math.max(0, Math.min(r * 1.4, w / 2, h / 2)), c = a * 0.225;
    ctx.moveTo(x + a, y);
    ctx.lineTo(x + w - a, y);
    ctx.bezierCurveTo(x + w - c, y, x + w, y + c, x + w, y + a);
    ctx.lineTo(x + w, y + h - a);
    ctx.bezierCurveTo(x + w, y + h - c, x + w - c, y + h, x + w - a, y + h);
    ctx.lineTo(x + a, y + h);
    ctx.bezierCurveTo(x + c, y + h, x, y + h - c, x, y + h - a);
    ctx.lineTo(x, y + a);
    ctx.bezierCurveTo(x, y + c, x + c, y, x + a, y);
    ctx.closePath();
  }

  function box(ctx, x, y, w, h, fill) {
    if (w <= 0 || h <= 0) return;
    ctx.fillStyle = fill;
    ctx.fillRect(x, y, w, h);
  }

  function pill(ctx, x, y, w, h, r, fill) {
    if (w <= 0 || h <= 0) return;
    ctx.beginPath();
    roundedRect(ctx, x, y, w, h, r);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  function disc(ctx, cx, cy, r, fill) {
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  // Strokes a run of x, y pairs with round ends and joins: most of the little glyphs are made of these.
  function strokes(ctx, colour, width, ...runs) {
    ctx.beginPath();
    for (const run of runs) {
      ctx.moveTo(run[0], run[1]);
      for (let i = 2; i < run.length; i += 2) ctx.lineTo(run[i], run[i + 1]);
    }
    ctx.strokeStyle = colour;
    ctx.lineWidth = width;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();
  }

  function vertical(ctx, y0, y1, ...stops) {
    const gradient = ctx.createLinearGradient(0, y0, 0, y1);
    stops.forEach((colour, i) => gradient.addColorStop(i / (stops.length - 1), colour));
    return gradient;
  }

  // -------------------------------------------------------------------------------------------------- text

  // Windows change size in every frame of a move, so text is wrapped and cut anew each time. Measuring is the
  // dear part; the texts are few, so every width is measured once and kept.
  const widths = new Map();
  const prefixes = new Map();

  function widthOf(ctx, face, text) {
    const key = face + '\n' + text;
    let width = widths.get(key);
    if (width === undefined) {
      ctx.font = face;
      width = ctx.measureText(text).width;
      widths.set(key, width);
    }
    return width;
  }

  function wrap(ctx, face, text, room) {
    const space = widthOf(ctx, face, ' ');
    const lines = [];
    let line = '', used = 0;
    for (const word of text.split(' ')) {
      const width = widthOf(ctx, face, word);
      if (line && used + space + width > room) {
        lines.push(line);
        line = word;
        used = width;
      } else {
        used += line ? space + width : width;
        line = line ? line + ' ' + word : word;
      }
    }
    if (line) lines.push(line);
    return lines;
  }

  // The text, or as much of it as fits with an ellipsis after it.
  function cut(ctx, face, text, room) {
    if (widthOf(ctx, face, text) <= room) return text;
    const key = face + '\n' + text;
    let upTo = prefixes.get(key);
    if (!upTo) {
      ctx.font = face;
      upTo = Array.from(text, (_, i) => ctx.measureText(text.slice(0, i + 1)).width);
      prefixes.set(key, upTo);
    }
    const left = room - widthOf(ctx, face, '…');
    let count = 0;
    while (count < upTo.length && upTo[count] <= left) count += 1;
    return count ? text.slice(0, count).trimEnd() + '…' : '';
  }

  // y is the baseline.
  function say(ctx, text, x, y, face, colour, align = 'left') {
    ctx.font = face;
    ctx.fillStyle = colour;
    ctx.textAlign = align;
    ctx.fillText(text, x, y);
  }

  function sayCut(ctx, text, x, y, room, face, colour) {
    if (room > 8) say(ctx, cut(ctx, face, text, room), x, y, face, colour);
  }

  // Wrapped lines from the baseline y on; returns the baseline the next line would have. Lines below `floor`
  // are counted but not painted: nobody would see them.
  function paragraph(ctx, text, x, y, room, face, colour, leading, floor) {
    for (const line of wrap(ctx, face, text, Math.max(room, 40))) {
      if (y - leading < floor) say(ctx, line, x, y, face, colour);
      y += leading;
    }
    return y;
  }

  function avatar(ctx, name, cx, cy, r) {
    disc(ctx, cx, cy, r, people[name] || ink.soft);
    say(ctx, name[0], cx, cy + r * 0.36, font(600, Math.round(r * 10) / 10), '#ffffff', 'center');
  }

  // ------------------------------------------------------------------------------------------------- icons

  // Each glyph is drawn in a square of 100 units, the icon's coloured shape. `side` is the icon's size in
  // points: small icons drop their fine parts and thicken their lines.
  const glyphs = {
    Browser(ctx, colour, side) {
      const small = side < 28, width = small ? 8 : 5.5;
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = width;
      ctx.beginPath();
      ctx.arc(50, 50, 29, 0, Math.PI * 2);
      ctx.moveTo(63, 50);
      ctx.ellipse(50, 50, 13, 29, 0, 0, Math.PI * 2);
      ctx.stroke();
      strokes(ctx, '#ffffff', width, [21, 50, 79, 50]);
      if (!small) strokes(ctx, '#ffffff', 4.5, [26, 35, 74, 35], [26, 65, 74, 65]);
    },
    Mail(ctx, colour, side) {
      pill(ctx, 19, 29, 62, 42, 7, '#ffffff');
      strokes(ctx, mix(colour, '#003a5c', 0.55), side < 28 ? 6.5 : 4.5, [24, 35, 50, 55, 76, 35]);
    },
    Terminal(ctx, colour, side) {
      const width = side < 28 ? 9.5 : 7.5;
      strokes(ctx, '#ffffff', width, [25, 33, 43, 49, 25, 65], [51, 68, 76, 68]);
    },
    Chat(ctx, colour, side) {
      pill(ctx, 18, 23, 64, 44, 17, '#ffffff');
      ctx.beginPath();
      ctx.moveTo(30, 58);
      ctx.quadraticCurveTo(31, 73, 23, 81);
      ctx.quadraticCurveTo(41, 79, 52, 62);
      ctx.closePath();
      ctx.fill();
      if (side >= 28) for (const cx of [36, 50, 64]) disc(ctx, cx, 45, 4.4, colour);
    },
    Notes(ctx, colour, side) {
      const dark = '#5c4200';
      if (side < 28) {
        strokes(ctx, dark, 9, [27, 32, 55, 32], [27, 51, 73, 51], [27, 70, 73, 70]);
      } else {
        strokes(ctx, dark, 8, [26, 30, 54, 30]);
        strokes(ctx, dark, 5, [26, 47, 74, 47], [26, 60, 74, 60], [26, 73, 60, 73]);
      }
    },
    Call(ctx, colour, side) {
      pill(ctx, 17, 32, 46, 36, 9, '#ffffff');
      if (side >= 28) disc(ctx, 40, 50, 8.5, colour);
      ctx.beginPath();
      ctx.moveTo(70, 46);
      ctx.lineTo(81, 38);
      ctx.lineTo(81, 62);
      ctx.lineTo(70, 54);
      ctx.closePath();
      ctx.fillStyle = '#ffffff';
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 5;
      ctx.lineJoin = 'round';
      ctx.fill();
      ctx.stroke();
    },
  };

  function icon(ctx, app, x, y, side) {
    const colour = (apps[app] || apps.Terminal).colour;
    const shape = side * 0.8, left = x + side * 0.1, top = y + side * 0.1, scale = scaleOf(ctx);
    ctx.save();
    ctx.beginPath();
    smoothRect(ctx, left, top, shape, shape, shape * 0.225);
    ctx.shadowColor = 'rgba(0,0,0,0.26)';
    ctx.shadowBlur = side * 0.045 * scale;
    ctx.shadowOffsetY = side * 0.018 * scale;
    const light = mix(colour, '#ffffff', 0.24), deep = mix(colour, '#000000', 0.1);
    ctx.fillStyle = vertical(ctx, top, top + shape, light, colour, deep);
    ctx.fill();
    ctx.shadowColor = 'transparent';
    if (side >= 32) {
      // A rim of light, so that the dark icon does not sink into a dark ground.
      ctx.beginPath();
      const rim = shape * 0.012;
      smoothRect(ctx, left + rim / 2, top + rim / 2, shape - rim, shape - rim, shape * 0.225 - rim / 2);
      ctx.strokeStyle = vertical(ctx, top, top + shape, 'rgba(255,255,255,0.42)', 'rgba(255,255,255,0.06)');
      ctx.lineWidth = rim;
      ctx.stroke();
    }
    ctx.translate(left, top);
    ctx.scale(shape / 100, shape / 100);
    if (glyphs[app]) glyphs[app](ctx, colour, side);
    ctx.restore();
  }

  // --------------------------------------------------------------------------------------------- wallpaper

  // A ridge through evenly spaced heights (shares of the picture's height) from a tenth of the width before
  // the left edge to a tenth after the right one, filled down to the bottom.
  function ridge(ctx, width, height, heights, top, bottom) {
    const last = heights.length - 1, step = (width * 1.2) / last;
    let x = -width * 0.1;
    ctx.beginPath();
    ctx.moveTo(x, heights[0] * height);
    for (let i = 0; i < last; i += 1) {
      const before = heights[Math.max(i - 1, 0)], from = heights[i], to = heights[i + 1];
      const after = heights[Math.min(i + 2, last)];
      ctx.bezierCurveTo(
        x + step / 3, (from + (to - before) / 6) * height,
        x + (step * 2) / 3, (to - (after - from) / 6) * height,
        x + step, to * height);
      x += step;
    }
    ctx.lineTo(x, height);
    ctx.lineTo(-width * 0.1, height);
    ctx.closePath();
    ctx.fillStyle = vertical(ctx, Math.min(...heights) * height, height, top, bottom);
    ctx.fill();
  }

  function paintWallpaper(ctx, width, height) {
    // The sky is laid in bands as the hills are: one gradient over so large a field would show steps once the
    // film is compressed.
    box(ctx, 0, 0, width, height, vertical(ctx, 0, height * 0.3, '#4786ae', '#5593b7'));
    ridge(ctx, width, height * 0.7, [0.2, 0.26, 0.2, 0.13, 0.17, 0.25, 0.28], '#619dbd', '#74abc3');
    ridge(ctx, width, height * 0.7, [0.47, 0.4, 0.42, 0.5, 0.47, 0.4, 0.38], '#84b5c6', '#9cc3c9');
    ridge(ctx, width, height * 0.7, [0.6, 0.66, 0.7, 0.64, 0.6, 0.63, 0.68], '#b7cec9', '#dfd5bf');
    ridge(ctx, width, height * 0.7, [0.84, 0.8, 0.78, 0.82, 0.8, 0.78, 0.8], '#e9cdb0', '#f1c49e');
    const sunX = width * 0.7, sunY = height * 0.56;
    const glow = ctx.createRadialGradient(sunX, sunY, 0, sunX, sunY, height * 0.5);
    glow.addColorStop(0, 'rgba(255,232,196,0.7)');
    glow.addColorStop(0.4, 'rgba(255,222,184,0.26)');
    glow.addColorStop(1, 'rgba(255,214,170,0)');
    box(ctx, 0, 0, width, height, glow);
    disc(ctx, sunX, sunY, height * 0.075, '#ffefd2');
    ridge(ctx, width, height, [0.6, 0.55, 0.6, 0.63, 0.57, 0.6, 0.64], '#a9c0c4', '#8fb2b8');
    ridge(ctx, width, height, [0.62, 0.68, 0.7, 0.63, 0.67, 0.71, 0.66], '#86adb3', '#6c9ca3');
    ridge(ctx, width, height, [0.8, 0.75, 0.72, 0.78, 0.8, 0.73, 0.72], '#649aa0', '#4d888f');
    ridge(ctx, width, height, [0.8, 0.86, 0.9, 0.85, 0.82, 0.87, 0.92], '#47848b', '#376f77');
    ridge(ctx, width, height, [0.99, 0.95, 0.93, 0.97, 1.0, 0.95, 0.9], '#306871', '#285a63');
  }

  // Painted once for each size and scale. A film asks for one or two; should somebody ask for many, the
  // oldest go.
  const wallpapersKept = new Map();

  function wallpaper(ctx, width, height) {
    const scale = scaleOf(ctx), key = `${width} ${height} ${scale}`;
    let kept = wallpapersKept.get(key);
    if (!kept) {
      const canvas = offscreen(Math.round(width * scale), Math.round(height * scale));
      const own = canvas.getContext('2d');
      own.scale(canvas.width / width, canvas.height / height);
      paintWallpaper(own, width, height);
      kept = settled(canvas);
      if (wallpapersKept.size >= 4) wallpapersKept.delete(wallpapersKept.keys().next().value);
      wallpapersKept.set(key, kept);
    }
    ctx.save();
    ctx.drawImage(kept, 0, 0, width, height);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------------------- window shadows

  // A blurred shadow the size of a large window costs more than all the rest of a frame. The blur depends only
  // on the scale and on whether the window has the focus, so it is painted once around a small window and then
  // laid around any window in eight pieces: four corners as they are, four edges stretched.
  const shadowsKept = new Map();
  const shadowMiddle = 4;

  function shadowPieces(scale, focused) {
    const key = `${scale} ${focused}`;
    let kept = shadowsKept.get(key);
    if (kept) return kept;
    // A wide soft shadow says how far the window floats above the rest, a tight one draws its edge.
    const layers = focused
      ? [{ blur: 34, drop: 13, alpha: 0.46 }, { blur: 5, drop: 1, alpha: 0.18 }]
      : [{ blur: 18, drop: 6, alpha: 0.22 }, { blur: 4, drop: 1, alpha: 0.1 }];
    const outside = Math.ceil((layers[0].blur * 1.4 + layers[0].drop) * scale);
    const inside = Math.ceil((windowRadius + layers[0].blur) * scale);
    const body = inside * 2 + shadowMiddle, size = body + outside * 2, away = size * 2;
    const canvas = offscreen(size, size);
    const own = canvas.getContext('2d');
    for (const { blur, drop, alpha } of layers) {
      // The window itself is drawn off the canvas, so that only its shadow lands on it.
      own.shadowColor = `rgba(0,0,0,${alpha})`;
      own.shadowBlur = blur * scale;
      own.shadowOffsetX = away;
      own.shadowOffsetY = drop * scale;
      own.beginPath();
      smoothRect(own, outside - away, outside, body, body, windowRadius * scale);
      own.fill();
    }
    kept = { canvas: settled(canvas), outside, inside, size };
    shadowsKept.set(key, kept);
    return kept;
  }

  function castShadow(ctx, w) {
    const t = ctx.getTransform(), scale = t.a;
    const { canvas, outside, inside, size } = shadowPieces(scale, Boolean(w.focused));
    // Whole pixels, or the seams between the pieces would show as faint lines.
    const x0 = Math.round(t.e + w.x * scale), x1 = Math.round(t.e + (w.x + w.width) * scale);
    const y0 = Math.round(t.f + w.y * scale), y1 = Math.round(t.f + (w.y + w.height) * scale);
    const inX = Math.min(inside, (x1 - x0) >> 1), inY = Math.min(inside, (y1 - y0) >> 1);
    const cornerX = outside + inX, cornerY = outside + inY, farX = size - cornerX, farY = size - cornerY;
    const wide = x1 - x0 - inX * 2, tall = y1 - y0 - inY * 2, mid = outside + inside;
    // The edges reach only two pixels under the window: what lies deeper is never seen.
    const rim = outside + 2;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(canvas, 0, 0, cornerX, cornerY, x0 - outside, y0 - outside, cornerX, cornerY);
    ctx.drawImage(canvas, farX, 0, cornerX, cornerY, x1 - inX, y0 - outside, cornerX, cornerY);
    ctx.drawImage(canvas, 0, farY, cornerX, cornerY, x0 - outside, y1 - inY, cornerX, cornerY);
    ctx.drawImage(canvas, farX, farY, cornerX, cornerY, x1 - inX, y1 - inY, cornerX, cornerY);
    if (wide > 0) {
      ctx.drawImage(canvas, mid, 0, shadowMiddle, rim, x0 + inX, y0 - outside, wide, rim);
      ctx.drawImage(canvas, mid, size - rim, shadowMiddle, rim, x0 + inX, y1 - 2, wide, rim);
    }
    if (tall > 0) {
      ctx.drawImage(canvas, 0, mid, rim, shadowMiddle, x0 - outside, y0 + inY, rim, tall);
      ctx.drawImage(canvas, size - rim, mid, rim, shadowMiddle, x1 - 2, y0 + inY, rim, tall);
    }
    ctx.restore();
  }

  // ----------------------------------------------------------------------------------------- window chrome

  function lights(ctx, w, dark) {
    const colours = w.focused ? ['#f1625b', '#f4bd40', '#43c552'] : Array(3).fill(dark ? '#4b4d55' : '#d3d3d7');
    colours.forEach((colour, i) => {
      disc(ctx, w.x + 20 + i * 20, w.y + 14, 6, colour);
      ctx.strokeStyle = dark ? 'rgba(0,0,0,0.25)' : 'rgba(0,0,0,0.1)';
      ctx.lineWidth = 0.5;
      ctx.stroke();
    });
  }

  // The three buttons, and the title centred between `left` and `right` unless the buttons are in its way.
  function titleBar(ctx, w, { dark = false, left = w.x, right = w.x + w.width } = {}) {
    lights(ctx, w, dark);
    const face = font(600, 13), from = Math.max(left + 12, w.x + 74), to = right - 12;
    if (to - from < 24) return;
    const text = cut(ctx, face, w.title || w.app, to - from), width = widthOf(ctx, face, text);
    const colour = dark ? (w.focused ? '#e6e6ea' : '#8b8c94') : (w.focused ? '#38383c' : '#a3a3a9');
    say(ctx, text, clamp((left + right - width) / 2, from, to - width), w.y + 18.6, face, colour);
  }

  // A selected row is tinted with the app's colour only in the window that has the focus.
  function selection(w, strength = 0.16) {
    return w.focused ? fade(apps[w.app].colour, strength) : 'rgba(0,0,0,0.065)';
  }

  // ----------------------------------------------------------------------------------------------- Browser

  const page = {
    site: 'trees.example',
    address: 'trees.example/growing',
    links: ['Guides', 'Species', 'Seasons', 'About'],
    kicker: 'FIELD GUIDE',
    heading: 'How a tree grows',
    byline: 'A short guide for patient gardeners',
    sections: [
      [null, 'A tree does not hurry. In its first year most of the work happens below the ground, where fine '
        + 'roots spread out in search of water long before the first branch appears.'],
      ['Roots first', 'Plant in autumn, while the soil is still warm. Dig a hole twice as wide as the pot and '
        + 'no deeper. Water well, then leave it alone: roots grow best when they have to look for a drink.'],
      ['Then the crown', 'From the third year the trunk thickens and the crown opens. Cut only what is dead or '
        + 'crossing. Each cut is a choice the tree has to live with for a long time.'],
      ['Shade for someone else', 'An oak planted today will be at its best in a hundred years. That is the '
        + 'quiet pleasure of it: you plant for people you will never meet.'],
    ],
  };

  function tree(ctx, x, ground, size) {
    const trunk = size * 0.05;
    ctx.beginPath();
    ctx.moveTo(x - trunk * 1.5, ground);
    ctx.lineTo(x - trunk * 0.7, ground - size * 0.6);
    ctx.lineTo(x + trunk * 0.7, ground - size * 0.6);
    ctx.lineTo(x + trunk * 1.5, ground);
    ctx.closePath();
    ctx.fillStyle = '#80603f';
    ctx.fill();
    const crown = [[-0.2, 0.56, 0.19, 1], [0.21, 0.58, 0.18, 1], [0, 0.76, 0.24, 0], [-0.1, 0.62, 0.17, 0]];
    for (const [dx, up, r, deep] of crown) {
      disc(ctx, x + dx * size, ground - up * size, r * size, deep ? '#3f8a5a' : '#55a56c');
    }
  }

  // The picture on the page: four ages of a tree. It keeps its proportions, as a picture on a page does.
  function growth(ctx, x, y, w, h) {
    ctx.save();
    ctx.beginPath();
    roundedRect(ctx, x, y, w, h, 12);
    ctx.clip();
    box(ctx, x, y, w, h, vertical(ctx, y, y + h, '#d6e9f0', '#f8ecd9'));
    disc(ctx, x + w * 0.13, y + h * 0.27, h * 0.1, '#f7cf7a');
    ctx.translate(x, y);
    ridge(ctx, w, h, [0.62, 0.52, 0.6, 0.66, 0.56], '#c3dcc6', '#b2d2b8');
    ridge(ctx, w, h, [0.8, 0.84, 0.8, 0.78, 0.82], '#8cc08d', '#79b07e');
    const ground = h * 0.84;
    strokes(ctx, '#4b9a62', h * 0.014, [w * 0.14, ground, w * 0.14, ground - h * 0.07]);
    for (const turn of [-1, 1]) {
      ctx.beginPath();
      const leafX = w * 0.14 + turn * h * 0.03;
      ctx.ellipse(leafX, ground - h * 0.085, h * 0.036, h * 0.017, turn * -0.5, 0, Math.PI * 2);
      ctx.fillStyle = '#55a56c';
      ctx.fill();
    }
    tree(ctx, w * 0.33, ground, h * 0.3);
    tree(ctx, w * 0.55, ground, h * 0.5);
    tree(ctx, w * 0.8, ground, h * 0.76);
    ctx.restore();
  }

  function browser(ctx, w) {
    const { x, y, width, height } = w, bottom = y + height, bars = titleBarHeight + 36;
    box(ctx, x, y, width, height, '#ffffff');

    // The page, from its own header down.
    const edge = clamp(width * 0.05, 16, 40), top = y + bars;
    disc(ctx, x + edge + 7, top + 21, 7, '#55a56c');
    box(ctx, x + edge + 6, top + 21, 2, 9, '#80603f');
    sayCut(ctx, page.site, x + edge + 22, top + 27, width - edge * 2 - 60, font(600, 14), ink.strong);
    if (width >= 600) {
      let right = x + width - edge;
      for (const link of [...page.links].reverse()) {
        say(ctx, link, right, top + 27, font(500, 13), ink.soft, 'right');
        right -= widthOf(ctx, font(500, 13), link) + 24;
      }
    } else {
      const r = x + width - edge;
      strokes(ctx, ink.soft, 1.5, [r - 16, top + 18, r, top + 18], [r - 16, top + 23, r, top + 23],
        [r - 16, top + 28, r, top + 28]);
    }
    box(ctx, x, top + 44, width, 1, 'rgba(0,0,0,0.06)');

    const column = Math.min(580, width - edge * 2), left = x + (width - column) / 2;
    const big = clamp(Math.round(column / 15), 22, 40);
    let line = top + 44 + clamp(column * 0.07, 24, 44);
    say(ctx, page.kicker, left, line, font(700, 11), '#3f8a5a');
    line += big * 0.8 + 12;
    const title = font(700, big, display);
    line = paragraph(ctx, page.heading, left, line, column, title, ink.strong, big * 1.12, bottom);
    line += 28 - big * 1.12;
    line = paragraph(ctx, page.byline, left, line, column, font(400, 14), ink.soft, 20, bottom) + 4;
    const tall = clamp(column * 0.4, 92, 250);
    if (line < bottom) growth(ctx, left, line, column, tall);
    line += tall + 34;
    const size = column < 360 ? 13.5 : 15, leading = Math.round(size * 1.55), lesser = font(700, 19, display);
    for (const [heading, text] of page.sections) {
      if (line - 30 > bottom) break;
      if (heading) {
        line = paragraph(ctx, heading, left, line + 8, column, lesser, ink.strong, 25, bottom) + 2;
      }
      line = paragraph(ctx, text, left, line, column, font(400, size), ink.body, leading, bottom) + 12;
    }

    // The bars go on last: the page would scroll under them.
    box(ctx, x, y, width, bars, '#f1f2f4');
    box(ctx, x, y + bars, width, 1, 'rgba(0,0,0,0.1)');
    titleBar(ctx, w);
    const roomy = width >= 440, middle = y + titleBarHeight + 14, tool = w.focused ? '#5d5d64' : '#a9a9af';
    const field = Math.min(480, width - (roomy ? 190 : 28)), fieldX = x + (width - field) / 2;
    pill(ctx, fieldX, middle - 13, field, 26, 8, 'rgba(0,0,0,0.06)');
    const face = font(400, 12.5), address = cut(ctx, face, page.address, field - 24);
    say(ctx, address, x + width / 2, middle + 4.5, face, w.focused ? ink.body : ink.soft, 'center');
    if (roomy) {
      strokes(ctx, tool, 1.8, [x + 27, middle - 5.5, x + 21.5, middle, x + 27, middle + 5.5]);
      strokes(ctx, ink.faint, 1.8, [x + 50, middle - 5.5, x + 55.5, middle, x + 50, middle + 5.5]);
      const r = x + width - 24;
      strokes(ctx, tool, 1.6, [r - 5.5, middle, r + 5.5, middle], [r, middle - 5.5, r, middle + 5.5]);
      ctx.beginPath();
      roundedRect(ctx, r - 37, middle - 3, 9, 9, 2.5);
      roundedRect(ctx, r - 33, middle - 6.5, 9, 9, 2.5);
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  // -------------------------------------------------------------------------------------------------- Mail

  const mail = {
    boxes: [['Inbox', 2], ['Drafts', 0], ['Sent', 0], ['Archive', 0], ['Bin', 0]],
    messages: [
      ['Ana', '9:32', 'Orchard plan for spring', 'I drew the rows again with more room for the pears.', false],
      ['Ben', '9:10', 'Seed order', 'The beans and the squash are in. Still waiting for the leeks.', true],
      ['Mia', '8:47', 'Saturday at the allotment', 'Who brings the wheelbarrow? I can bring soup.', true],
      ['Tom', 'Tue', 'Photos of the big oak', 'Taken from the hill at seven in the morning.', false],
      ['Eva', 'Tue', 'Compost delivery', 'They can come on Thursday or on Friday, before noon.', false],
      ['Leo', 'Mon', 'Rain barrel', 'It holds two hundred litres and it is already full.', false],
      ['Ida', 'Mon', 'Hedge along the path', 'Hornbeam keeps its leaves in winter, so I vote for it.', false],
      ['Sam', 'Sun', 'Key of the tool shed', 'I left it under the blue pot, as always.', false],
      ['Zoe', 'Sun', 'Bird boxes', 'Three are taken already, one of them by a very loud wren.', false],
      ['Max', 'Sat', 'October in the garden', 'Leaves, leaf mould and what to do with too many apples.', false],
      ['Kim', 'Fri', 'Thanks for the apples', 'We made eleven jars. Two of them are yours.', false],
    ],
    body: [
      'Hello,',
      'I drew the rows again with more room for the pears. If we move the path a little to the east, every '
        + 'tree gets sun until the evening.',
      'The two old apple trees stay where they are. Ben thinks they have ten good years left, and nobody '
        + 'wants to argue with the blackbirds.',
      'Could you look at the plan before Saturday? Then we can mark the places with sticks while the ground '
        + 'is soft.',
      'Ana',
    ],
  };

  function mailList(ctx, w, x, width) {
    const bottom = w.y + w.height, accent = mix(apps.Mail.colour, '#004a78', 0.45);
    say(ctx, 'Inbox', x + 22, w.y + 52, font(700, 17, display), ink.strong);
    if (width >= 200) say(ctx, '2 unread', x + width - 18, w.y + 52, font(400, 11.5), ink.soft, 'right');
    let top = w.y + 66;
    mail.messages.forEach(([from, time, subject, preview, unread], i) => {
      if (top < bottom) {
        if (i === 0) pill(ctx, x + 8, top, width - 16, 64, 10, selection(w, 0.24));
        else if (i > 1) box(ctx, x + 22, top, width - 40, 1, 'rgba(0,0,0,0.06)');
        if (unread) disc(ctx, x + 13, top + 17, 3.5, accent);
        const room = width - 40;
        say(ctx, time, x + width - 18, top + 21, font(400, 11.5), ink.soft, 'right');
        sayCut(ctx, from, x + 22, top + 21, room - 44, font(600, 13), ink.strong);
        sayCut(ctx, subject, x + 22, top + 38, room, font(400, 12.5), ink.body);
        sayCut(ctx, preview, x + 22, top + 54, room, font(400, 12), ink.soft);
      }
      top += 64;
    });
  }

  // What is attached to the letter: a little plan of the orchard, rows of trees beside a path.
  function orchardPlan(ctx, x, y) {
    ctx.save();
    ctx.beginPath();
    roundedRect(ctx, x, y, 176, 104, 10);
    ctx.clip();
    box(ctx, x, y, 176, 104, '#eef4e6');
    ctx.beginPath();
    ctx.moveTo(x + 156, y - 6);
    ctx.quadraticCurveTo(x + 126, y + 40, x + 150, y + 84);
    ctx.strokeStyle = '#e0d2b4';
    ctx.lineWidth = 9;
    ctx.stroke();
    for (let row = 0; row < 3; row += 1) {
      const green = row ? '#7fbb83' : '#5ba36f';
      for (let at = 0; at < 5; at += 1) disc(ctx, x + 22 + at * 23, y + 17 + row * 21, 6.5, green);
    }
    box(ctx, x, y + 76, 176, 28, '#ffffff');
    box(ctx, x, y + 76, 176, 1, hairline);
    say(ctx, 'orchard-plan.pdf', x + 12, y + 94, font(500, 11.5), ink.body);
    ctx.restore();
    ctx.beginPath();
    roundedRect(ctx, x + 0.5, y + 0.5, 175, 103, 9.5);
    ctx.strokeStyle = 'rgba(0,0,0,0.12)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  function mailLetter(ctx, w, x, width) {
    const bottom = w.y + w.height, edge = clamp(width * 0.06, 18, 40), left = x + edge;
    const column = Math.min(620, width - edge * 2), [from, time, subject] = mail.messages[0];
    let line = w.y + titleBarHeight + 34;
    avatar(ctx, from, left + 18, line - 4, 18);
    say(ctx, from, left + 46, line - 7, font(600, 14), ink.strong);
    say(ctx, 'to me', left + 46, line + 10, font(400, 12), ink.soft);
    say(ctx, time, x + width - edge, line - 7, font(400, 12), ink.soft, 'right');
    line += 52;
    line = paragraph(ctx, subject, left, line, column, font(700, 22, display), ink.strong, 27, bottom);
    box(ctx, left, line - 10, width - edge * 2, 1, 'rgba(0,0,0,0.07)');
    line += 18;
    for (const text of mail.body) {
      line = paragraph(ctx, text, left, line, column, font(400, 13.5), ink.body, 21, bottom) + 10;
    }
    if (line < bottom) orchardPlan(ctx, left, line);
  }

  function mailWindow(ctx, w) {
    const { x, y, width, height } = w;
    const boxes = width >= 980 ? 176 : 0, reading = width >= 520;
    const list = reading ? clamp((width - boxes) * 0.36, 236, 330) : width;
    box(ctx, x, y, width, height, '#ffffff');
    if (boxes) {
      box(ctx, x, y, boxes, height, '#e8eef2');
      box(ctx, x + boxes - 1, y, 1, height, hairline);
      say(ctx, 'MAILBOXES', x + 20, y + 54, font(600, 10.5), ink.soft);
      mail.boxes.forEach(([name, count], i) => {
        const top = y + 64 + i * 30;
        if (i === 0) pill(ctx, x + 10, top, boxes - 20, 28, 8, selection(w, 0.3));
        ctx.beginPath();
        roundedRect(ctx, x + 20, top + 8.5, 14, 11, 2.5);
        ctx.strokeStyle = i === 0 ? ink.body : ink.soft;
        ctx.lineWidth = 1.4;
        ctx.stroke();
        say(ctx, name, x + 43, top + 18.6, font(i === 0 ? 600 : 400, 13), ink.body);
        if (count) say(ctx, String(count), x + boxes - 22, top + 18.6, font(500, 12), ink.soft, 'right');
      });
    }
    if (reading) {
      box(ctx, x + boxes, y, list, height, '#f6f8fa');
      box(ctx, x + boxes + list - 1, y, 1, height, hairline);
      mailLetter(ctx, w, x + boxes + list, width - boxes - list);
    }
    mailList(ctx, w, x + boxes, list);
    const tools = width - boxes - list >= 380 ? 110 : 0, right = x + width;
    if (tools) {
      // Answer, put away, write a new one.
      const colour = w.focused ? '#5d5d64' : '#a9a9af', cy = y + 15, r = right - 6;
      strokes(ctx, colour, 1.5, [r - 88, cy - 4.5, r - 93, cy, r - 88, cy + 4.5]);
      ctx.beginPath();
      ctx.moveTo(r - 92.5, cy);
      ctx.quadraticCurveTo(r - 80, cy - 1, r - 79.5, cy + 6);
      ctx.stroke();
      ctx.beginPath();
      roundedRect(ctx, r - 63, cy - 6, 14, 4.5, 1.2);
      ctx.stroke();
      strokes(ctx, colour, 1.5, [r - 61.5, cy - 1.5, r - 61.5, cy + 6, r - 50.5, cy + 6, r - 50.5, cy - 1.5],
        [r - 58, cy + 1.8, r - 54, cy + 1.8]);
      strokes(ctx, colour, 1.5, [r - 27, cy + 1, r - 19, cy - 7],
        [r - 24, cy - 5.5, r - 32, cy - 5.5, r - 32, cy + 6, r - 20.5, cy + 6, r - 20.5, cy + 2]);
    }
    titleBar(ctx, w, { left: reading ? x + boxes + list : x, right: right - tools });
  }

  // ---------------------------------------------------------------------------------------------- Terminal

  const prompt = [['~/arbor', 'path'], [' $ ', 'dim']];
  const passed = (name) => [['  ok  ', 'good'], [name, 'plain']];
  const session = [
    [...prompt, ['make check', 'plain']],
    [['[1/3] Compiling ArborCore', 'dim']],
    [['[2/3] Compiling ArborKit', 'dim']],
    [['[3/3] Linking arbor-sim', 'dim']],
    [['Build complete', 'good'], [' (41.2 s)', 'dim']],
    [['  core ............... 2214 passed', 'plain']],
    [['  controller ......... 3345 passed', 'plain']],
    [['5559 tests passed', 'good'], [', 0 failed', 'plain']],
    [],
    [...prompt, ['make sim', 'plain']],
    [['+------------+------------+', 'dim']],
    [['|            |  Terminal  |', 'dim']],
    [['|  Browser   +------------+', 'dim']],
    [['|            |  Chat      |', 'dim']],
    [['+------------+------------+', 'dim']],
    [],
    [...prompt, ['ls', 'plain']],
    [['Makefile  README.md  Sources  Tests  docs  scripts', 'plain']],
    [],
    [...prompt, ['make scenarios', 'plain']],
    passed('a window docks at the left edge'),
    passed('a second one docks beside it'),
    passed('a third one docks under the second'),
    passed('loose windows stay on the Desktop'),
    passed('framing a window fills the view'),
    passed('stepping out shows its group'),
    passed('show everything brings all of it back'),
    passed('a window kept in view stays in front'),
    passed('a held view does not move'),
    passed('undo takes back an arrangement'),
    passed('quitting puts every window back'),
    [['11 scenarios passed', 'good']],
    [],
    prompt,
  ];
  const sessionColours = { plain: '#d9dbe1', dim: '#8d919c', good: '#7fd48b', path: '#7db7f0' };

  function terminal(ctx, w) {
    const { x, y, width, height } = w, face = font(400, 12, mono);
    box(ctx, x, y, width, height, '#1e1f24');
    let line = y + titleBarHeight + 20;
    for (const parts of session) {
      if (line - 14 > y + height) break;
      let at = x + 14;
      for (const [text, kind] of parts) {
        say(ctx, text, at, line, face, sessionColours[kind]);
        at += widthOf(ctx, face, text);
      }
      if (parts === prompt) {
        // A terminal that does not have the keyboard shows its cursor hollow.
        if (w.focused) box(ctx, at, line - 11.5, 7.5, 15, '#d9dbe1');
        ctx.strokeStyle = '#8d919c';
        ctx.lineWidth = 1;
        if (!w.focused) ctx.strokeRect(at + 0.5, line - 11, 6.5, 14);
      }
      line += 17;
    }
    box(ctx, x, y, width, titleBarHeight, '#2b2c33');
    box(ctx, x, y + titleBarHeight, width, 1, 'rgba(0,0,0,0.35)');
    titleBar(ctx, w, { dark: true });
  }

  // -------------------------------------------------------------------------------------------------- Chat

  const chat = {
    rooms: [['garden', 0], ['orchard', 2], ['tools', 0], ['lunch', 0]],
    friends: ['Ana', 'Ben', 'Mia', 'Tom'],
    talk: [
      ['Ana', 'Good morning! The ground is soft at last.'],
      ['Ben', 'Then Saturday it is.'],
      ['Ana', 'The pears are here. Twelve of them!'],
      [null, 'Twelve? We said eight.'],
      ['Ana', 'They were small. They looked lonely.'],
      ['Ben', 'I can dig four more holes on Saturday.'],
      [null, 'Bring the long spade then. Mine is bent.'],
      ['Mia', 'Soup for everyone at one. Pumpkin.'],
      ['Tom', 'Is the wheelbarrow still at my place?'],
      [null, 'Yes. And it has a flat tyre.'],
      ['Tom', 'Then I bring the pump as well.'],
      ['Mia', 'See you all at ten.'],
    ],
  };

  function chatSideBar(ctx, w, width) {
    const { x, y, height } = w, deep = mix(apps.Chat.colour, '#000000', 0.25);
    box(ctx, x, y, width, height, '#f1eef4');
    box(ctx, x + width - 1, y, 1, height, hairline);
    say(ctx, 'ROOMS', x + 18, y + 54, font(600, 10.5), ink.soft);
    let top = y + 63;
    chat.rooms.forEach(([name, waiting], i) => {
      if (i === 0) pill(ctx, x + 8, top, width - 16, 28, 8, selection(w));
      const colour = i === 0 && w.focused ? deep : ink.body;
      say(ctx, '#', x + 19, top + 18.6, font(500, 13), i === 0 && w.focused ? deep : ink.soft);
      sayCut(ctx, name, x + 32, top + 18.6, width - 70, font(i === 0 || waiting ? 600 : 400, 13), colour);
      if (waiting) {
        pill(ctx, x + width - 36, top + 6, 20, 16, 8, apps.Chat.colour);
        say(ctx, String(waiting), x + width - 26, top + 18, font(600, 10.5), '#ffffff', 'center');
      }
      top += 30;
    });
    say(ctx, 'PEOPLE', x + 18, top + 24, font(600, 10.5), ink.soft);
    top += 33;
    chat.friends.forEach((name, i) => {
      avatar(ctx, name, x + 25, top + 14, 8);
      sayCut(ctx, name, x + 40, top + 18.6, width - 70, font(400, 13), ink.body);
      disc(ctx, x + width - 24, top + 14, 3.5, i < 3 ? '#43b556' : '#c9c9cf');
      top += 30;
    });
  }

  function chatWindow(ctx, w) {
    const { x, y, width, height } = w, colour = apps.Chat.colour;
    const side = width >= 420 ? clamp(width * 0.26, 132, 210) : 0;
    const left = x + side, pane = width - side, edge = clamp(pane * 0.04, 10, 24), faces = pane >= 300;
    box(ctx, x, y, width, height, '#ffffff');

    // The newest message sits above the field, as in any chat, so the talk is laid out from the bottom up and
    // stops where the title bar begins.
    const face = font(400, 13.5), indent = faces ? 36 : 0;
    const room = Math.max(60, Math.min(400, (pane - edge * 2 - indent) * 0.78) - 24);
    let floor = y + height - 56;
    for (let i = chat.talk.length - 1; i >= 0 && floor > y + titleBarHeight; i -= 1) {
      const [name, text] = chat.talk[i], lines = wrap(ctx, face, text, room);
      const first = i === 0 || chat.talk[i - 1][0] !== name, lastOfRun = i === chat.talk.length - 1
        || chat.talk[i + 1][0] !== name;
      const wide = Math.max(...lines.map((line) => widthOf(ctx, face, line))) + 24;
      const tall = lines.length * 19 + 13, top = floor - tall;
      const at = name ? left + edge + indent : x + width - edge - wide, words = name ? ink.strong : '#ffffff';
      pill(ctx, at, top, wide, tall, 16, name ? '#eeeef2' : colour);
      lines.forEach((line, n) => say(ctx, line, at + 12, top + 20 + n * 19, face, words));
      if (name && faces && lastOfRun) avatar(ctx, name, left + edge + 13, floor - 13, 13);
      floor = top - 4;
      if (first) {
        if (name) {
          say(ctx, name, at + 12, floor - 2, font(500, 11), ink.soft);
          floor -= 14;
        }
        floor -= 8;
      }
    }

    box(ctx, left, y, pane, titleBarHeight, '#ffffff');
    box(ctx, left, y + titleBarHeight, pane, 1, 'rgba(0,0,0,0.07)');
    box(ctx, left, y + height - 50, pane, 50, '#ffffff');
    const fieldY = y + height - 44, fieldWidth = pane - edge * 2;
    pill(ctx, left + edge, fieldY, fieldWidth, 32, 16, '#f3f3f6');
    ctx.strokeStyle = 'rgba(0,0,0,0.08)';
    ctx.lineWidth = 1;
    ctx.stroke();
    sayCut(ctx, 'Message #garden', left + edge + 14, fieldY + 20.8, fieldWidth - 56, font(400, 13), ink.faint);
    const send = left + edge + fieldWidth - 16;
    disc(ctx, send, fieldY + 16, 11, w.focused ? colour : '#c9c9cf');
    strokes(ctx, '#ffffff', 1.8, [send, fieldY + 21, send, fieldY + 11.5],
      [send - 4, fieldY + 15, send, fieldY + 11, send + 4, fieldY + 15]);
    if (side) chatSideBar(ctx, w, side);
    titleBar(ctx, w, { left });
  }

  // ------------------------------------------------------------------------------------------------- Notes

  const notes = {
    list: [
      ['Field notes', 'Water the young pears'],
      ['Shopping', 'Twine, two hinges, oil'],
      ['Books to read', 'The one about hedges'],
      ['Ideas for the shed', 'A window to the south'],
      ['Pumpkin soup', 'One onion, one pumpkin'],
      ['Birds seen', 'Wren, jay, two robins'],
      ['Rain this month', 'Four wet days so far'],
      ['Letter to Ida', 'About the hornbeam hedge'],
      ['Names for the cat', 'Moss, Acorn, Bramble'],
      ['Tool shed', 'The key is under the pot'],
      ['Seeds to swap', 'Beans for squash'],
      ['Winter jobs', 'Oil the handles'],
    ],
    heading: 'Field notes',
    edited: 'Edited this morning',
    tasks: [
      [true, 'Water the young pears'],
      [true, 'Mend the gate'],
      [false, 'Order mulch for the beds'],
      [false, 'Sharpen the long spade'],
      [false, 'Ask Tom about the wheelbarrow'],
      [false, 'Plant garlic before the first frost'],
    ],
    more: [
      ['Seen today', 'Two jays burying acorns by the wall. Frost on the roof of the shed, gone by nine. The '
        + 'old apple tree still has its leaves.'],
      ['Next week', 'Mark the places for the pears with sticks. Move the path a little to the east. Ask Mia '
        + 'for the recipe.'],
      ['The old wall', 'Warm until late in the evening. A fig might like it there, or the bench. Measure it '
        + 'before buying either.'],
      ['Not to forget', 'The water is turned off at the end of the month. Empty the barrel before that and '
        + 'bring the hose inside.'],
    ],
  };

  function notesWindow(ctx, w) {
    const { x, y, width, height } = w, bottom = y + height, amber = apps.Notes.colour;
    const side = width >= 620 ? clamp(width * 0.24, 180, 240) : 0;
    box(ctx, x, y, width, height, '#fffdf4');
    if (side) {
      box(ctx, x, y, side, height, '#f8f2dd');
      box(ctx, x + side - 1, y, 1, height, hairline);
      notes.list.forEach(([name, start], i) => {
        const top = y + 40 + i * 54;
        if (top > bottom) return;
        if (i === 0) pill(ctx, x + 8, top, side - 16, 52, 10, selection(w, 0.5));
        else if (i > 1) box(ctx, x + 20, top - 1, side - 40, 1, 'rgba(0,0,0,0.06)');
        sayCut(ctx, name, x + 20, top + 22, side - 40, font(600, 13), ink.strong);
        sayCut(ctx, start, x + 20, top + 40, side - 40, font(400, 12), '#8f8a78');
      });
    }
    const pane = width - side, edge = clamp(pane * 0.07, 18, 56), left = x + side + edge;
    const column = Math.min(600, pane - edge * 2);
    let line = y + titleBarHeight + 30;
    say(ctx, cut(ctx, font(400, 11.5), notes.edited, column), left, line, font(400, 11.5), '#a39d88');
    const title = font(700, 26, display);
    line = paragraph(ctx, notes.heading, left, line + 32, column, title, ink.strong, 31, bottom);
    line += 4;
    for (const [done, text] of notes.tasks) {
      if (line - 20 > bottom) break;
      ctx.beginPath();
      ctx.arc(left + 9, line - 4.5, 8, 0, Math.PI * 2);
      if (done) {
        ctx.fillStyle = amber;
        ctx.fill();
        strokes(ctx, '#5c4200', 1.8, [left + 5.5, line - 4.5, left + 8, line - 1.5, left + 12.5, line - 7.5]);
      } else {
        ctx.strokeStyle = '#cfc8ae';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
      const colour = done ? '#a39d88' : ink.body;
      line = paragraph(ctx, text, left + 28, line, column - 28, font(400, 14), colour, 20, bottom) + 9;
    }
    line += 20;
    for (const [heading, text] of notes.more) {
      if (line - 20 > bottom) break;
      line = paragraph(ctx, heading, left, line, column, font(700, 16, display), ink.strong, 24, bottom);
      line = paragraph(ctx, text, left, line, column, font(400, 14), ink.body, 21, bottom) + 16;
    }
    titleBar(ctx, w, { left: x + side });
  }

  // -------------------------------------------------------------------------------------------------- Call

  const callers = {
    Mia: { skin: '#eebd98', shade: '#d9a37c', hair: '#4b2e26', jumper: '#f0c04f', long: true },
    Tom: { skin: '#c88f68', shade: '#b07a55', hair: '#241c1a', jumper: '#e9e4da', long: false },
  };

  function caller(ctx, x, y, w, h, name, from, to) {
    if (w <= 0 || h <= 0) return;
    ctx.save();
    ctx.beginPath();
    roundedRect(ctx, x, y, w, h, 13);
    ctx.clip();
    const ground = ctx.createLinearGradient(x, y, x + w * 0.4, y + h);
    ground.addColorStop(0, from);
    ground.addColorStop(1, to);
    box(ctx, x, y, w, h, ground);
    // The picture of a camera fills its pane without being squeezed: the figure grows with the smaller side.
    const unit = Math.min(w * 1.2, h * 1.15, 600), cx = x + w / 2, base = y + h;
    // A person in a few flat shapes: a jumper, a neck, hair behind the head if it is long, the head, hair on top, a face.
    const look = callers[name] || callers.Mia;
    const r = unit * 0.15, hy = base - unit * 0.5;
    const reach = unit * 0.38, neck = base - unit * 0.3;
    ctx.fillStyle = look.jumper;
    ctx.beginPath();
    ctx.moveTo(cx - reach, base + 1);
    ctx.bezierCurveTo(cx - reach, base - unit * 0.2, cx - unit * 0.22, neck, cx, neck);
    ctx.bezierCurveTo(cx + unit * 0.22, neck, cx + reach, base - unit * 0.2, cx + reach, base + 1);
    ctx.closePath();
    ctx.fill();
    if (look.long) {
      ctx.fillStyle = look.hair;
      ctx.beginPath();
      roundedRect(ctx, cx - r * 1.22, hy - r * 1.1, r * 2.44, r * 2.75, r * 1.1);
      ctx.fill();
    }
    ctx.fillStyle = look.shade;
    ctx.fillRect(cx - r * 0.36, hy + r * 0.6, r * 0.72, r * 0.95);
    disc(ctx, cx, hy, r, look.skin);
    ctx.fillStyle = look.hair;
    ctx.beginPath();
    ctx.arc(cx, hy, r * 1.04, Math.PI * (look.long ? 1.02 : 1.08), Math.PI * (look.long ? 1.98 : 1.92));
    ctx.quadraticCurveTo(cx + r * (look.long ? -0.1 : 0.2), hy - r * (look.long ? 0.75 : 0.55), cx - r * 1.02, hy - r * (look.long ? 0.06 : 0.25));
    ctx.closePath();
    ctx.fill();
    disc(ctx, cx - r * 0.36, hy + r * 0.08, r * 0.085, '#2a211d');
    disc(ctx, cx + r * 0.36, hy + r * 0.08, r * 0.085, '#2a211d');
    ctx.beginPath();
    ctx.arc(cx, hy + r * 0.28, r * 0.34, Math.PI * 0.18, Math.PI * 0.82);
    ctx.strokeStyle = '#2a211d';
    ctx.lineWidth = Math.max(r * 0.075, 0.8);
    ctx.lineCap = 'round';
    ctx.stroke();
    if (w >= 64 && h >= 44) {
      const face = font(600, 11.5), wide = widthOf(ctx, face, name) + 16;
      pill(ctx, x + 8, y + h - 28, wide, 20, 10, 'rgba(0,0,0,0.42)');
      say(ctx, name, x + 16, y + h - 13.8, face, '#ffffff');
    }
    ctx.restore();
  }

  function callWindow(ctx, w) {
    const { x, y, width, height } = w;
    box(ctx, x, y, width, height, '#17181c');
    const button = clamp(height * 0.085, 26, 44), around = clamp(height * 0.025, 7, 16), edge = 10;
    const top = y + titleBarHeight, tall = height - titleBarHeight - button - around * 2;
    const wide = width - edge * 2;
    if (wide > tall * 1.15) {
      const each = (wide - edge) / 2;
      caller(ctx, x + edge, top, each, tall, 'Mia', '#3d8f8a', '#2b5f86');
      caller(ctx, x + edge * 2 + each, top, each, tall, 'Tom', '#c07a5a', '#7c4a7d');
    } else {
      const each = (tall - edge) / 2;
      caller(ctx, x + edge, top, wide, each, 'Mia', '#3d8f8a', '#2b5f86');
      caller(ctx, x + edge, top + each + edge, wide, each, 'Tom', '#c07a5a', '#7c4a7d');
    }
    const r = button / 2, u = button / 40, apart = button * 1.4;
    const cx = x + width / 2, cy = y + height - around - r;
    disc(ctx, cx - apart, cy, r, '#34363d');
    disc(ctx, cx, cy, r, '#34363d');
    disc(ctx, cx + apart, cy, r, '#e5484d');
    // A microphone, a camera and a receiver laid down.
    pill(ctx, cx - apart - 3.2 * u, cy - 9.5 * u, 6.4 * u, 12.5 * u, 3.2 * u, '#ffffff');
    ctx.beginPath();
    ctx.arc(cx - apart, cy - 2 * u, 6.8 * u, Math.PI * 0.05, Math.PI * 0.95);
    ctx.moveTo(cx - apart, cy + 5 * u);
    ctx.lineTo(cx - apart, cy + 9 * u);
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1.8 * u;
    ctx.lineCap = 'round';
    ctx.stroke();
    pill(ctx, cx - 9.5 * u, cy - 6 * u, 13 * u, 12 * u, 3 * u, '#ffffff');
    ctx.beginPath();
    ctx.moveTo(cx + 5 * u, cy - 1.5 * u);
    ctx.lineTo(cx + 9.5 * u, cy - 5 * u);
    ctx.lineTo(cx + 9.5 * u, cy + 5 * u);
    ctx.lineTo(cx + 5 * u, cy + 1.5 * u);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx + apart, cy + 9 * u, 11 * u, Math.PI * 1.25, Math.PI * 1.75);
    ctx.lineWidth = 5 * u;
    ctx.stroke();
    titleBar(ctx, w, { dark: true });
  }

  // ------------------------------------------------------------------------------------------- the windows

  const contents = {
    Browser: { paint: browser },
    Mail: { paint: mailWindow },
    Terminal: { paint: terminal, dark: true },
    Chat: { paint: chatWindow },
    Notes: { paint: notesWindow },
    Call: { paint: callWindow, dark: true },
  };

  function plainWindow(ctx, w) {
    box(ctx, w.x, w.y, w.width, w.height, '#ffffff');
    box(ctx, w.x, w.y, w.width, titleBarHeight, '#f1f2f4');
    titleBar(ctx, w);
  }

  function paintWindow(ctx, w) {
    if (!(w.width > 0 && w.height > 0)) return;
    const kind = contents[w.app] || { paint: plainWindow };
    ctx.save();
    ctx.textBaseline = 'alphabetic';
    castShadow(ctx, w);
    ctx.save();
    ctx.beginPath();
    smoothRect(ctx, w.x, w.y, w.width, w.height, windowRadius);
    ctx.clip();
    kind.paint(ctx, w);
    ctx.restore();
    if (kind.dark) {
      // Dark windows get a thread of light inside the dark hairline, or their edge is lost on a dark ground.
      ctx.beginPath();
      smoothRect(ctx, w.x + 1.5, w.y + 1.5, w.width - 3, w.height - 3, windowRadius - 1.5);
      ctx.strokeStyle = 'rgba(255,255,255,0.1)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }
    ctx.beginPath();
    smoothRect(ctx, w.x + 0.5, w.y + 0.5, w.width - 1, w.height - 1, windowRadius - 0.5);
    ctx.strokeStyle = kind.dark ? 'rgba(0,0,0,0.42)' : 'rgba(0,0,0,0.18)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();
  }

  // ---------------------------------------------------------------------------------------------- menu bar

  function menuBar(ctx, width, height, opts = {}) {
    const { app = 'Browser', clock = '9:41', slotWidth = 26 } = opts;
    const middle = height / 2, baseline = middle + 4.7, colour = 'rgba(0,0,0,0.86)';
    ctx.save();
    ctx.textBaseline = 'alphabetic';
    box(ctx, 0, 0, width, height, 'rgba(255,255,255,0.55)');
    box(ctx, 0, height, width, 0.5, 'rgba(0,0,0,0.1)');

    // Our own mark: a diamond with soft corners.
    ctx.save();
    ctx.translate(24, middle);
    ctx.rotate(Math.PI / 4);
    pill(ctx, -5, -5, 10, 10, 2.6, colour);
    ctx.restore();

    let at = 46;
    say(ctx, app, at, baseline, font(600, 13), colour);
    at += widthOf(ctx, font(600, 13), app) + 20;
    for (const menu of ['File', 'Edit', 'View', 'Window', 'Help']) {
      say(ctx, menu, at, baseline, font(400, 13), colour);
      at += widthOf(ctx, font(400, 13), menu) + 20;
    }

    let right = width - 16;
    say(ctx, clock, right, baseline, font(500, 13), colour, 'right');
    right -= widthOf(ctx, font(500, 13), clock) + 16;

    // Two little sliders.
    for (const [knob, cy] of [[right - 4.5, middle - 3.5], [right - 10.5, middle + 3.5]]) {
      strokes(ctx, colour, 1.5, [right - 15, cy, right, cy]);
      disc(ctx, knob, cy, 2.8, '#1f1f22');
    }
    right -= 15 + 17;

    // A lens.
    ctx.beginPath();
    ctx.arc(right - 8, middle - 1.2, 4.6, 0, Math.PI * 2);
    ctx.strokeStyle = colour;
    ctx.lineWidth = 1.6;
    ctx.stroke();
    strokes(ctx, colour, 1.8, [right - 4.6, middle + 2.3, right - 1.4, middle + 5.6]);
    right -= 13 + 17;

    // Signal: a dot with two arcs over it.
    disc(ctx, right - 8, middle + 4.6, 1.7, colour);
    for (const r of [5.2, 9.4]) {
      ctx.beginPath();
      ctx.arc(right - 8, middle + 4.6, r, Math.PI * 1.26, Math.PI * 1.74);
      ctx.strokeStyle = colour;
      ctx.lineWidth = 1.9;
      ctx.lineCap = 'round';
      ctx.stroke();
    }
    right -= 16 + 17;

    // A battery, four fifths full.
    ctx.beginPath();
    roundedRect(ctx, right - 24.5, middle - 5.5, 22, 11, 3.4);
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.lineWidth = 1;
    ctx.stroke();
    pill(ctx, right - 23, middle - 4, 15, 8, 2, colour);
    pill(ctx, right - 1.6, middle - 2, 1.6, 4, 0.8, 'rgba(0,0,0,0.5)');
    right -= 25 + 12;

    ctx.restore();
    return { slot: { x: right - slotWidth, y: (height - 22) / 2, width: slotWidth, height: 22 } };
  }

  // -------------------------------------------------------------------------------------------------- Dock

  // What lies behind the Dock shows through as if through frosted glass. That part of the picture is read back,
  // made four times smaller, blurred there (a quarter of the blur on a sixteenth of the pixels) and painted
  // back at full size. Nothing beyond the display is read: around it is the film's own ground, which no Dock
  // could see.
  let frostKept = null;

  function frost(ctx, frame, radius, displayWidth, displayHeight) {
    if (typeof ctx.filter !== 'string') return;
    const t = ctx.getTransform(), scale = t.a, spill = 24;
    const left = Math.max(0, frame.x - spill), top = Math.max(0, frame.y - spill);
    const sx = Math.round(t.e + left * scale), sy = Math.round(t.f + top * scale);
    const sw = Math.round(t.e + Math.min(displayWidth, frame.x + frame.width + spill) * scale) - sx;
    const sh = Math.round(t.f + Math.min(displayHeight, frame.y + frame.height + spill) * scale) - sy;
    if (sw <= 0 || sh <= 0) return;
    const margin = 12, w = Math.ceil(sw / 4), h = Math.ceil(sh / 4);
    if (!frostKept || frostKept.key !== `${sw} ${sh}`) {
      const little = () => offscreen(w + margin * 2, h + margin * 2);
      const sheets = [offscreen(sw, sh), little(), little()];
      frostKept = { key: `${sw} ${sh}`, sheets, pens: sheets.map((sheet) => sheet.getContext('2d')) };
    }
    const [full, small, soft] = frostKept.sheets, [fullPen, smallPen, softPen] = frostKept.pens;
    fullPen.putImageData(ctx.getImageData(sx, sy, sw, sh), 0, 0);
    // First stretched over the margin as well, so that the blur finds like colours there and not emptiness.
    smallPen.drawImage(full, 0, 0, small.width, small.height);
    smallPen.drawImage(full, margin, margin, w, h);
    softPen.filter = `blur(${((13 * scale) / 4).toFixed(2)}px) saturate(1.5)`;
    softPen.drawImage(small, 0, 0);
    ctx.save();
    ctx.beginPath();
    smoothRect(ctx, frame.x, frame.y, frame.width, frame.height, radius);
    ctx.clip();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(soft, margin, margin, w, h, sx, sy, w * 4, h * 4);
    ctx.restore();
  }

  function dock(ctx, displayWidth, displayHeight, opts = {}) {
    const { apps: names = Object.keys(apps), running = [], badges = {}, bounce = {} } = opts;
    const side = 48, gap = 6, inset = 8, radius = 20;
    const frame = {
      x: (displayWidth - (names.length * (side + gap) - gap + inset * 2)) / 2,
      y: displayHeight - 6 - 64,
      width: names.length * (side + gap) - gap + inset * 2,
      height: 64,
    };
    ctx.save();
    ctx.textBaseline = 'alphabetic';
    frost(ctx, frame, radius, displayWidth, displayHeight);
    ctx.beginPath();
    smoothRect(ctx, frame.x, frame.y, frame.width, frame.height, radius);
    ctx.fillStyle = 'rgba(255,255,255,0.42)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,0.12)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.beginPath();
    smoothRect(ctx, frame.x + 1, frame.y + 1, frame.width - 2, frame.height - 2, radius - 1);
    ctx.strokeStyle = 'rgba(255,255,255,0.3)';
    ctx.stroke();

    const icons = {};
    names.forEach((name, i) => {
      const place = { x: frame.x + inset + i * (side + gap), y: frame.y + 6, width: side, height: side };
      const top = place.y - 18 * clamp(bounce[name] || 0, 0, 1);
      icons[name] = place;
      icon(ctx, name, place.x, top, side);
      if (running.includes(name)) {
        disc(ctx, place.x + side / 2, frame.y + frame.height - 5, 1.8, 'rgba(0,0,0,0.62)');
      }
      if (badges[name]) {
        const text = String(badges[name]), face = font(600, 11.5);
        const wide = Math.max(19, widthOf(ctx, face, text) + 11), cx = place.x + side - 7;
        pill(ctx, cx - wide / 2, top - 1.5, wide, 19, 9.5, '#ee4b45');
        say(ctx, text, cx, top + 12.2, face, '#ffffff', 'center');
      }
    });
    ctx.restore();
    return { frame, icons };
  }

  // ----------------------------------------------------------------------------------------------- pointer

  // Life size, tip or centre at 0, 0; drawn 1.3 times as large, since it has to be found on a telephone.
  const arrow = [0, 0, 0, 14.4, 3.4, 11.3, 5.7, 16.7, 8.2, 15.6, 5.9, 10.4, 10.4, 10.4];
  const doubleArrow = [-10, 0, -5.4, -4.8, -5.4, -1.5, 5.4, -1.5, 5.4, -4.8, 10, 0, 5.4, 4.8, 5.4, 1.5,
    -5.4, 1.5, -5.4, 4.8];

  function pointer(ctx, x, y, opts = {}) {
    const { down = false, kind = 'arrow' } = opts, scale = scaleOf(ctx);
    const outline = kind === 'arrow' ? arrow : doubleArrow;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(1.3 * (down ? 0.92 : 1), 1.3 * (down ? 0.92 : 1));
    if (kind === 'resizeUpDown') ctx.rotate(Math.PI / 2);
    ctx.beginPath();
    ctx.moveTo(outline[0], outline[1]);
    for (let i = 2; i < outline.length; i += 2) ctx.lineTo(outline[i], outline[i + 1]);
    ctx.closePath();
    ctx.lineJoin = 'round';
    ctx.lineWidth = 2.6;
    ctx.strokeStyle = '#ffffff';
    ctx.shadowColor = 'rgba(0,0,0,0.4)';
    ctx.shadowBlur = (down ? 2.5 : 4) * scale;
    ctx.shadowOffsetY = (down ? 0.8 : 1.6) * scale;
    ctx.stroke();
    ctx.shadowColor = 'transparent';
    ctx.lineWidth = 0.6;
    ctx.strokeStyle = ctx.fillStyle = '#111113';
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  return {
    apps,
    windowRadius,
    titleBarHeight,
    icon,
    wallpaper,
    window: paintWindow,
    menuBar,
    dock,
    pointer,
    roundedRect,
    smoothRect,
  };
})();

if (typeof module !== 'undefined') module.exports = Scenery;
