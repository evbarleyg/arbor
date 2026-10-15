// Paints one frame of a film written by `arbor-sim film` (docs/FILM.md).
//
// Everything on the drawn display that is Arbor's comes from the frame: where windows are, the shapes, colours and opacities of
// what Arbor draws. This file decides nothing about them; it copies what the app's own views do with the same models
// (Sources/ArborKit/UI), view by view, and each function below names the view it follows. The scenery (wallpaper, menu
// bar, Dock, what is inside the windows, the pointer) is `scenery.js`; the band under the display with the caption and the keys is the film's.

const Paint = (() => {
  const FONT = "Inter, 'DejaVu Sans', sans-serif";
  const font = (size, weight = 400) => `${weight} ${size}px ${FONT}`;

  // The picture: 1920 x 1080 with the display in the upper part and the band below it.
  const PICTURE = { width: 1920, height: 1080 };
  const SCREEN = { x: 160, y: 26, width: 1600, height: 900, radius: 18 };

  // macOS's label colours in light appearance.
  const LABEL = 'rgba(0,0,0,0.85)';
  // PanelLook.ink in the light look: `LABEL` is its main ink too, this its second.
  const SECOND_INK = 'rgba(0,0,0,0.65)';
  // PanelLook.Corner.panel.
  const PANEL_CORNER = 20;
  // What macOS fills a selected row with where the accent colour is its blue (NSColor.selectedContentBackgroundColor), read off
  // pictures of the real panel.
  const SELECTION = 'rgb(0,90,216)';
  const SECONDARY = 'rgba(0,0,0,0.5)';
  const TERTIARY = 'rgba(0,0,0,0.26)';
  const QUATERNARY = 'rgba(0,0,0,0.1)';
  const SEPARATOR = 'rgba(0,0,0,0.1)';

  const rounded = (ctx, x, y, w, h, r) => {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, Math.max(Math.min(r, w / 2, h / 2), 0));
  };

  const withAlpha = (ctx, alpha, draw) => {
    if (alpha <= 0) return;
    ctx.save();
    ctx.globalAlpha *= alpha;
    draw();
    ctx.restore();
  };

  // A translucent panel: what is behind it, blurred, under a wash of light grey. It stands for NSVisualEffectView, whose
  // materials are macOS's own. HUD and POPOVER are PanelGround's: `.hudWindow` and `.popover` in the light look with
  // PanelLook.veil over them, read off pictures of the real panels over white, black, red and blue. The menu's is chosen by eye.
  const HUD = 'rgba(236,236,236,0.74)';
  const POPOVER = 'rgba(236,236,236,0.8)';
  function material(ctx, [x, y, w, h], radius, wash = HUD) {
    const canvas = ctx.canvas;
    const m = ctx.getTransform();
    ctx.save();
    rounded(ctx, x, y, w, h, radius);
    ctx.clip();
    // Only the part of the picture that can reach the panel through the blur: blurring all of it takes ten times as long.
    const blur = 18 * m.a;
    const sx = Math.max(Math.floor(m.e + x * m.a - 3 * blur), 0), sy = Math.max(Math.floor(m.f + y * m.d - 3 * blur), 0);
    const sw = Math.min(Math.ceil(w * m.a + 6 * blur), canvas.width - sx), sh = Math.min(Math.ceil(h * m.d + 6 * blur), canvas.height - sy);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.filter = `blur(${blur}px) saturate(1.6)`;
    ctx.drawImage(canvas, sx, sy, sw, sh, sx, sy, sw, sh);
    ctx.filter = 'none';
    ctx.setTransform(m);
    ctx.fillStyle = wash;
    ctx.fillRect(x, y, w, h);
    ctx.restore();
    // The shadow comes after the panel and only round it: whatever is painted under the panel first is what the panel then blurs, and a plate there
    // made every panel as good as opaque. It is cast by a plate that is itself far outside the picture.
    const far = 20000, reach = 80;
    const round = new Path2D();
    round.rect(x - reach, y - reach, w + 2 * reach, h + 2 * reach);
    round.roundRect(x, y, w, h, radius);
    ctx.save();
    ctx.clip(round, 'evenodd');
    ctx.shadowColor = 'rgba(0,0,0,0.3)';
    ctx.shadowBlur = 24 * m.a;
    ctx.shadowOffsetX = far;
    ctx.shadowOffsetY = 8 * m.a;
    ctx.fillStyle = '#000';
    rounded(ctx, x - far / m.a, y, w, h, radius);
    ctx.fill();
    ctx.restore();
    // PanelOutlineView.
    ctx.save();
    ctx.strokeStyle = SEPARATOR;
    ctx.lineWidth = 1;
    rounded(ctx, x + 0.5, y + 0.5, w - 1, h - 1, radius - 0.5);
    ctx.stroke();
    ctx.restore();
  }

  // A panel that fades as a whole has to be painted apart and laid on, or its parts would show through each other.
  let spare = null;
  function layer(ctx, alpha, draw) {
    if (alpha >= 1) return draw(ctx);
    if (alpha <= 0) return;
    const canvas = ctx.canvas;
    if (!spare || spare.width !== canvas.width || spare.height !== canvas.height) {
      spare = new OffscreenCanvas(canvas.width, canvas.height);
    }
    const other = spare.getContext('2d');
    other.setTransform(1, 0, 0, 1, 0, 0);
    other.globalAlpha = 1;
    // It starts as a copy of the picture so far, for materials to blur, and only what `draw` changes is seen in the end
    // because the copy underneath is the same.
    other.clearRect(0, 0, canvas.width, canvas.height);
    other.drawImage(canvas, 0, 0);
    other.setTransform(ctx.getTransform());
    draw(other);
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = alpha;
    ctx.drawImage(spare, 0, 0);
    ctx.restore();
  }

  // MARK: What Arbor draws

  // BackdropLayer: the shape that darkens the wallpaper behind docked windows, and the hairline round the Desktop.
  function backdrop(ctx, shapes) {
    for (const shape of shapes || []) {
      if (shape.blur > 0) throw new Error('nothing here blurs the wallpaper behind docked windows, which these frames ask for');
      withAlpha(ctx, shape.opacity, () => {
        ctx.fillStyle = shape.fill;
        ctx.fill(new Path2D(shape.path));
        if (shape.desktopEdge) {
          ctx.strokeStyle = shape.desktopEdge.stroke;
          ctx.lineWidth = shape.desktopEdge.width;
          ctx.stroke(new Path2D(shape.desktopEdge.path));
        }
      });
    }
  }

  // TileDrawing.
  function tile(ctx, tile) {
    const plate = (p) => {
      const [, y, , h] = p.frame;
      const fill = ctx.createLinearGradient(0, y, 0, y + h);
      fill.addColorStop(0, p.top);
      fill.addColorStop(1, p.bottom);
      ctx.fillStyle = fill;
      ctx.fill(new Path2D(p.path));
      ctx.strokeStyle = p.border;
      ctx.lineWidth = p.borderWidth;
      ctx.stroke(new Path2D(p.borderPath));
    };
    const label = (l) => {
      const [x, y, w, h] = l.frame;
      ctx.font = font(l.size, l.strong ? 600 : 500);
      ctx.fillStyle = l.colour;
      ctx.textBaseline = 'middle';
      ctx.textAlign = l.align;
      ctx.fillText(fitted(ctx, l.text, w), l.align === 'center' ? x + w / 2 : x, y + h / 2 + 0.5);
    };
    withAlpha(ctx, tile.opacity, () => {
      ctx.translate(tile.frame[0], tile.frame[1]);
      if (tile.shadow) {
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.25)';
        ctx.shadowBlur = 18 * ctx.getTransform().a;
        ctx.shadowOffsetY = 6 * ctx.getTransform().a;
        ctx.fillStyle = tile.plate.bottom;
        ctx.fill(new Path2D(tile.plate.path));
        ctx.restore();
      }
      plate(tile.plate);
      tile.cells.forEach(plate);
      for (const icon of tile.icons) Scenery.icon(ctx, icon.app, ...icon.frame.slice(0, 3));
      if (tile.glyph) symbol(ctx, tile.glyph.symbol, tile.glyph.frame, tile.glyph.colour);
      if (tile.caption) label(tile.caption);
      if (tile.badge) {
        ctx.fillStyle = tile.badge.fill;
        ctx.fill(new Path2D(tile.badge.path));
        label(tile.badge.label);
      }
    });
  }

  // SeamView.draw.
  function gapHandle(ctx, handle) {
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.45)';
    ctx.shadowBlur = 2 * ctx.getTransform().a;
    ctx.shadowOffsetY = ctx.getTransform().a;
    ctx.fillStyle = handle.fill;
    ctx.fill(new Path2D(handle.path));
    ctx.restore();
  }

  // FocusRingPanel: each band is the area between two rounded rectangles.
  function ring(ctx, ring) {
    const band = (b) => {
      const [x, y, w, h] = b.frame;
      const t = b.thickness;
      ctx.beginPath();
      ctx.roundRect(x, y, w, h, b.radius);
      ctx.roundRect(x + t, y + t, w - 2 * t, h - 2 * t, b.innerRadius);
      ctx.fill('evenodd');
    };
    ctx.save();
    ctx.fillStyle = ring.colour;
    withAlpha(ctx, ring.flashOpacity, () => band(ring.flash));
    band(ring.line);
    ctx.restore();
  }

  const tinted = (colour, alpha) => colour.replace(/,[^,]*\)$/, `,${alpha})`);

  // AccentInk.mark: the accent colour at `fill`, a line of `width` in it just inside the edge, and inside that a second line, one point
  // wide, light inside a dark accent and dark inside a light one, so that one of the two shows on anything.
  function accentMark(ctx, [x, y, w, h], radius, fill, width, film) {
    const path = (inset) => rounded(ctx, x + inset, y + inset, w - 2 * inset, h - 2 * inset, Math.max(radius - inset, 0));
    const [r, g, b] = film.accent.match(/[\d.]+/g).map(Number);
    path(0);
    ctx.fillStyle = tinted(film.accent, fill);
    ctx.fill();
    path(width / 2);
    ctx.strokeStyle = film.accent;
    ctx.lineWidth = width;
    ctx.stroke();
    path(width + 0.5);
    ctx.strokeStyle = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 > 0.6 ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.55)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  // PreviewView.
  function preview(ctx, preview, film) {
    withAlpha(ctx, preview.opacity, () => accentMark(ctx, preview.frame, film.windowRadius, 0.18, 2, film));
  }

  // PeekOutlineView: the panel reaches 5 points outside the space, and the line is 4 points wide.
  function peek(ctx, [x, y, w, h], film) {
    const reach = 5;
    accentMark(ctx, [x - reach, y - reach, w + 2 * reach, h + 2 * reach], film.windowRadius + reach, 0.12, 4, film);
  }

  // Stage and StandIn: a picture of the desktop, the surface, and one stand-in per window. Without a picture of its window a
  // stand-in is its cover: the app's colour, a faint white border, the icon at 45% of the shorter side.
  function portrait(w, scale) {
    const [, , width, height] = w.frame;
    const canvas = new OffscreenCanvas(Math.max(Math.ceil(width * scale), 1), Math.max(Math.ceil(height * scale), 1));
    const ctx = canvas.getContext('2d');
    ctx.scale(scale, scale);
    Scenery.window(ctx, { app: w.app, title: w.title, x: 0, y: 0, width, height, focused: !!w.focused });
    return canvas;
  }

  function stage(ctx, stage, film, windows) {
    const [x, y, w, h] = stage.frame;
    layer(ctx, stage.opacity, (ctx) => {
      ctx.save();
      ctx.beginPath();
      ctx.rect(x, y, w, h);
      ctx.clip();
      Scenery.wallpaper(ctx, w, h);
      backdrop(ctx, stage.surfaces);
      for (const standIn of stage.standIns) {
        const [sx, sy, sw, sh] = standIn.frame;
        if (sw < 1 || sh < 1) continue;
        withAlpha(ctx, standIn.opacity, () => {
          const scale = ctx.getTransform().a;
          // The shadow alone, as the stand-in's layer has it, whatever lies on it: cast by a plate that is itself far outside the picture.
          const far = 20000;
          ctx.save();
          ctx.shadowColor = 'rgba(0,0,0,0.3)';
          ctx.shadowBlur = 28 * scale;
          ctx.shadowOffsetX = far;
          ctx.shadowOffsetY = 6 * scale;
          ctx.fillStyle = '#000';
          rounded(ctx, sx - far / scale, sy, sw, sh, 16);
          ctx.fill();
          ctx.restore();
          withAlpha(ctx, standIn.cover, () => {
            ctx.fillStyle = standIn.colour;
            rounded(ctx, sx, sy, sw, sh, 16);
            ctx.fill();
            ctx.strokeStyle = 'rgba(255,255,255,0.25)';
            ctx.lineWidth = 1;
            rounded(ctx, sx + 0.5, sy + 0.5, sw - 1, sh - 1, 15.5);
            ctx.stroke();
            const side = Math.min(sw, sh) * 0.45;
            Scenery.icon(ctx, standIn.app, sx + sw / 2 - side / 2, sy + sh / 2 - side / 2, side);
          });
          // With `windowPictures` on: a still picture of the window as it is now, at the size it has gone to, stretched over the stand-in.
          const real = standIn.picture > 0 && windows.find((w) => w.id === standIn.id);
          if (standIn.picture > 0 && !real) throw new Error(`nothing here has a picture of ${standIn.id}, which is gone`);
          if (real) withAlpha(ctx, standIn.picture, () => ctx.drawImage(portrait(real, scale), sx, sy, sw, sh));
        });
      }
      ctx.restore();
    });
  }

  // Text that is too long for its place ends in an ellipsis.
  function fitted(ctx, text, width) {
    if (ctx.measureText(text).width <= width) return text;
    let end = text.length;
    while (end > 0 && ctx.measureText(text.slice(0, end) + '…').width > width) end -= 1;
    return text.slice(0, end) + '…';
  }

  // HeadsUpPanel: what happened, and after a dot what to press next, lighter in weight but not in colour; centred, wrapped by words. Where
  // the line wraps the dot goes with the hint.
  function headsUp(ctx, line) {
    const padding = { x: 18, y: 10 };
    const runs = [{ text: line.text, font: font(15, 500), colour: LABEL }];
    if (line.hint) {
      runs.push({ text: '  ·\u00a0\u00a0', font: font(15, 400), colour: SECOND_INK });
      runs.push({ text: line.hint, font: font(15, 400), colour: LABEL });
    }
    const limit = line.maximumWidth - 2 * padding.x;
    const rows = [[]];
    let used = 0;
    for (const run of runs) {
      ctx.font = run.font;
      for (const word of run.text.split(/(?<= )(?=\S)/)) {
        const width = ctx.measureText(word).width;
        if (used + ctx.measureText(word.trimEnd()).width > limit && used > 0) {
          rows.push([]);
          used = 0;
        }
        rows[rows.length - 1].push({ ...run, text: word, width });
        used += width;
      }
    }
    const height = 19;
    const widths = rows.map((row) => row.reduce((sum, piece) => sum + piece.width, 0));
    const w = Math.ceil(Math.max(...widths)) + 2 * padding.x;
    const h = rows.length * height + 2 * padding.y;
    const x = Math.round(line.anchor[0] - w / 2);
    const y = Math.round(line.anchor[1] - h);
    layer(ctx, line.opacity, (ctx) => {
      // PanelLook.Corner.line: a capsule while it is one line of text.
      material(ctx, [x, y, w, h], Math.min(h / 2, PANEL_CORNER));
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      rows.forEach((row, index) => {
        let at = x + (w - widths[index]) / 2;
        for (const piece of row) {
          ctx.font = piece.font;
          ctx.fillStyle = piece.colour;
          ctx.fillText(piece.text, at, y + padding.y + index * height + height / 2 + 0.5);
          at += piece.width;
        }
      });
    });
  }

  // MinimapDrawing.
  function minimap(ctx, map, film) {
    layer(ctx, map.opacity, (ctx) => {
      material(ctx, map.frame, PANEL_CORNER);
      ctx.save();
      ctx.translate(map.frame[0], map.frame[1]);
      if (map.desktop) {
        const [x, y, w, h] = map.desktop;
        ctx.strokeStyle = `rgba(0,0,0,${0.85 * (map.desktopInView ? 0.6 : 0.3)})`;
        ctx.lineWidth = 1;
        rounded(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 2.5);
        ctx.stroke();
      }
      for (const item of map.items) {
        withAlpha(ctx, item.inView ? 1 : 0.45, () => {
          ctx.fillStyle = item.colour;
          rounded(ctx, ...item.frame, 2.5);
          ctx.fill();
        });
        const [ix, iy, iw, ih] = item.frame;
        if (item.inView || iw <= 2 || ih <= 2) continue;
        ctx.strokeStyle = 'rgba(0,0,0,0.255)'; // The main ink at outOfViewEdgeAlpha.
        ctx.lineWidth = 1;
        rounded(ctx, ix + 0.5, iy + 0.5, iw - 1, ih - 1, 2);
        ctx.stroke();
      }
      const [x, y, w, h] = map.highlight;
      rounded(ctx, x - 2, y - 2, w + 4, h + 4, 4.5);
      ctx.fillStyle = tinted(film.accent, 0.12);
      ctx.fill();
      ctx.strokeStyle = film.accent;
      ctx.lineWidth = 2;
      ctx.stroke();
      if (map.hover) {
        const [hx, hy, hw, hh] = map.hover;
        rounded(ctx, hx - 0.5, hy - 0.5, hw + 1, hh + 1, 3);
        ctx.strokeStyle = LABEL;
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
      if (map.caption) {
        const [cx, cy, cw, ch] = map.captionFrame;
        ctx.font = font(11, 500);
        ctx.fillStyle = LABEL;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(fitted(ctx, map.caption, cw), cx + cw / 2, cy + ch / 2);
      }
      ctx.restore();
    });
  }

  // Text with the matched characters set off, heavy and underlined, as FinderView.styled has it. Returns its width.
  function styled(ctx, text, ranges, x, y, size, weight, colour, limit) {
    let at = x;
    const marked = new Set();
    for (const [from, to] of ranges) for (let i = from; i < to; i += 1) marked.add(i);
    for (const [index, character] of [...text].entries()) {
      ctx.font = font(size, marked.has(index) ? 800 : weight);
      const width = ctx.measureText(character).width;
      if (at + width > limit) {
        ctx.fillStyle = colour;
        ctx.fillText('…', at, y);
        return at - x;
      }
      ctx.fillStyle = colour;
      ctx.fillText(character, at, y);
      if (marked.has(index)) ctx.fillRect(at, y + size * 0.5, width, 1);
      at += width;
    }
    return at - x;
  }

  // FinderPanel and FinderView.
  function goTo(ctx, palette, film, frame) {
    const [px, py, pw] = palette.panel;
    material(ctx, palette.panel, PANEL_CORNER, POPOVER);
    ctx.save();
    ctx.translate(px, py);
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const [fx, fy, , fh] = palette.field;
    const [, ly, , lh] = palette.list;
    // FinderLayout.glyph: 20 points, over the rows' icons, in the middle of the field's band. Our own glass, not macOS's symbol.
    const glass = { x: fx - 30 + 10, y: ly / 2 };
    ctx.strokeStyle = LABEL;
    ctx.lineWidth = 1.8;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.arc(glass.x - 1.5, glass.y - 1.5, 6, 0, 2 * Math.PI);
    ctx.moveTo(glass.x + 3, glass.y + 3);
    ctx.lineTo(glass.x + 7.5, glass.y + 7.5);
    ctx.stroke();
    ctx.font = font(22);
    ctx.fillStyle = palette.text ? LABEL : SECOND_INK;
    ctx.fillText(palette.text || palette.placeholder, fx + 2, fy + fh / 2 + 1);
    // The insertion point blinks about once a second, as every text field's does.
    if (Math.floor(frame.n / (film.fps * 0.53)) % 2 === 0) {
      ctx.fillStyle = film.accent;
      ctx.fillRect(fx + 2 + (palette.text ? ctx.measureText(palette.text).width + 1 : 0), fy + 2, 2, fh - 4);
    }
    if (lh > 0) {
      ctx.fillStyle = SEPARATOR;
      ctx.fillRect(0, ly, pw, 1);
    }
    for (const row of palette.rows) {
      const [x, y, w, h] = row.frame;
      const middle = y + h / 2;
      if (row.selected) {
        ctx.fillStyle = SELECTION;
        rounded(ctx, x, y, w, h, Math.max(PANEL_CORNER - x, 2)); // PanelLook.Corner.inside.
        ctx.fill();
      }
      const primary = row.selected ? '#fff' : LABEL;
      const faint = row.selected ? 'rgba(255,255,255,0.85)' : SECOND_INK;
      if (row.app !== undefined) {
        Scenery.icon(ctx, row.app, x + 10, middle - 12, 24);
      } else if (row.badge !== undefined) {
        ctx.fillStyle = row.selected ? 'rgba(255,255,255,0.25)' : QUATERNARY;
        rounded(ctx, x + 10, middle - 12, 24, 24, 6);
        ctx.fill();
        ctx.font = font(13, 600);
        ctx.fillStyle = primary;
        ctx.textAlign = 'center';
        ctx.fillText(row.badge, x + 22, middle + 0.5);
        ctx.textAlign = 'left';
      }
      ctx.font = font(11);
      const noteWidth = Math.min(Math.ceil(ctx.measureText(row.note).width) + 2, w * 0.45);
      ctx.fillStyle = faint;
      ctx.textAlign = 'right';
      ctx.fillText(fitted(ctx, row.note, noteWidth), x + w - 12, middle + 0.5);
      ctx.textAlign = 'left';
      const left = x + 44;
      const limit = x + w - 12 - noteWidth - 12;
      const used = styled(ctx, row.name, row.nameRanges, left, middle + 0.5, 13, 600, primary, limit);
      if (row.detail) {
        ctx.font = font(13);
        const gap = ctx.measureText('   ').width;
        styled(ctx, row.detail, row.detailRanges, left + used + gap, middle + 0.5, 13, 400, primary, limit);
      }
    }
    if (palette.message) {
      const [x, y, w, h] = palette.messageFrame;
      ctx.font = font(12);
      ctx.fillStyle = SECOND_INK;
      ctx.fillText(fitted(ctx, palette.message, w - 24), x + 12, y + h / 2);
    }
    ctx.restore();
  }

  // Signs of our own drawing where the app uses system symbols: the same meaning, not the same artwork.
  function symbol(ctx, name, [x, y, w, h], colour) {
    const cx = x + w / 2, cy = y + h / 2;
    ctx.save();
    ctx.strokeStyle = colour;
    ctx.fillStyle = colour;
    ctx.lineWidth = 1.6;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    switch (name) {
      case 'chevron.left':
      case 'chevron.right': {
        const d = name.endsWith('left') ? 1 : -1;
        ctx.beginPath();
        ctx.moveTo(cx + 2.5 * d, cy - 5);
        ctx.lineTo(cx - 2.5 * d, cy);
        ctx.lineTo(cx + 2.5 * d, cy + 5);
        ctx.stroke();
        break;
      }
      case 'ellipsis':
        for (const dx of [-5, 0, 5]) {
          ctx.beginPath();
          ctx.arc(cx + dx, cy, 1.5, 0, 2 * Math.PI);
          ctx.fill();
        }
        break;
      case 'menubar.dock.rectangle': {
        const s = Math.min(w / 16, h / 13, 2);
        ctx.lineWidth = 1.3 * Math.max(s, 1);
        rounded(ctx, cx - 7.5 * s, cy - 5.5 * s, 15 * s, 11 * s, 2.5 * s);
        ctx.stroke();
        ctx.fillRect(cx - 7 * s, cy - 3.6 * s, 14 * s, 1 * s);
        rounded(ctx, cx - 4 * s, cy + 1.6 * s, 8 * s, 2.2 * s, 1 * s);
        ctx.fill();
        break;
      }
      case 'lock.rectangle':
        ctx.lineWidth = 1.3;
        rounded(ctx, cx - 8, cy - 6, 16, 12, 2.5);
        ctx.stroke();
        rounded(ctx, cx - 3, cy - 0.8, 6, 4.6, 1);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(cx, cy - 1, 1.9, Math.PI, 0);
        ctx.stroke();
        break;
      case 'rectangle.split.3x1.fill':
        for (const dx of [-5.5, 0, 5.5]) {
          rounded(ctx, cx + dx - 2.3, cy - 5.5, 4.6, 11, 1);
          ctx.fill();
        }
        break;
      default:
        rounded(ctx, cx - 6, cy - 5, 12, 10, 2);
        ctx.stroke();
    }
    ctx.restore();
  }

  // ArborArtwork: a template image, which the menu bar shows in black on a light bar.
  function menuBarItem(ctx, item) {
    const ink = (opacity) => `rgba(0,0,0,${0.88 * opacity})`;
    const glyph = (g, cell, opacity) => {
      if (g.mark) {
        ctx.fillStyle = ink(opacity);
        for (const [x, y, w, h] of g.mark) {
          rounded(ctx, x, y, w, h, 1);
          ctx.fill();
        }
      } else if (g.digit !== undefined) {
        ctx.font = font(12, 600);
        ctx.fillStyle = ink(opacity);
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(String(g.digit), cell[0] + cell[2] / 2, cell[1] + cell[3] / 2 + 0.5);
      } else {
        symbol(ctx, g.symbol, cell, ink(opacity));
      }
    };
    ctx.save();
    if (item.open) {
      // macOS lays a soft highlight behind the item whose menu is open.
      ctx.fillStyle = 'rgba(0,0,0,0.1)';
      rounded(ctx, item.frame[0], item.frame[1], item.frame[2], item.frame[3], 5);
      ctx.fill();
    }
    if (item.icon) {
      glyph(item.icon, item.frame, item.dimmed ? 0.35 : 1);
    } else {
      for (const button of item.buttons) {
        if (button.current) {
          ctx.fillStyle = `rgba(0,0,0,${item.fill})`;
          rounded(ctx, ...button.chip, 5);
          ctx.fill();
        }
        glyph(button.glyph, button.cell, button.enabled ? 1 : 0.35);
      }
    }
    ctx.restore();
  }

  // The menu is macOS's to draw: rows of 13-point text, section headers smaller and grey, the row under the pointer in the accent colour.
  function menu(ctx, menu, film) {
    material(ctx, menu.frame, 10, 'rgba(246,246,246,0.86)');
    ctx.save();
    ctx.textBaseline = 'middle';
    for (const row of menu.rows) {
      const [x, y, w, h] = row.frame;
      if (row.kind === 'separator') {
        ctx.fillStyle = SEPARATOR;
        ctx.fillRect(x + 14, y + h / 2 - 0.5, w - 28, 1);
        continue;
      }
      if (row.highlighted) {
        ctx.fillStyle = film.accent;
        rounded(ctx, x + 5, y, w - 10, h, 5);
        ctx.fill();
      }
      const colour = row.highlighted ? '#fff' : row.kind === 'header' ? SECONDARY : row.enabled ? LABEL : TERTIARY;
      ctx.fillStyle = colour;
      ctx.textAlign = 'left';
      ctx.font = row.kind === 'header' ? font(11, 600) : font(13);
      ctx.fillText(row.title, x + (row.kind === 'header' ? 14 : 24), y + h / 2 + 0.5);
      if (row.ticked) {
        ctx.strokeStyle = colour;
        ctx.lineWidth = 1.6;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.beginPath();
        ctx.moveTo(x + 11, y + h / 2 + 0.5);
        ctx.lineTo(x + 14, y + h / 2 + 3.5);
        ctx.lineTo(x + 19, y + h / 2 - 3.5);
        ctx.stroke();
      }
      ctx.textAlign = 'right';
      if (row.shortcut) {
        ctx.fillStyle = row.highlighted ? '#fff' : row.enabled ? SECONDARY : TERTIARY;
        ctx.fillText(row.shortcut, x + w - 16, y + h / 2 + 0.5);
      } else if (row.submenu) {
        symbol(ctx, 'chevron.right', [x + w - 26, y, 12, h], colour);
      }
    }
    ctx.restore();
  }

  // MARK: The display

  // What a frame can hold and this file paints. A film must not leave out what Arbor shows: a key that is not here stops the painting.
  const PAINTED = new Set([
    'n', 't', 'marks', 'windows', 'backdrop', 'tiles', 'gapHandle', 'ring', 'preview', 'peek', 'stage', 'headsUp', 'minimap', 'goTo',
    'menuBar', 'menu', 'pointer', 'keys',
  ]);
  function unpainted(frame) {
    return Object.keys(frame).filter((key) => !PAINTED.has(key));
  }

  function display(ctx, film, frame, extras) {
    const strange = unpainted(frame);
    if (strange.length) throw new Error(`frame ${frame.n}: nothing here paints ${strange.join(', ')}`);
    const [, , width, height] = film.display.frame;
    const marks = frame.marks || {};
    Scenery.wallpaper(ctx, width, height);
    backdrop(ctx, frame.backdrop);
    (frame.tiles || []).forEach((t) => tile(ctx, t));
    if (frame.gapHandle) gapHandle(ctx, frame.gapHandle);
    for (const w of frame.windows) {
      const [x, y, ww, wh] = w.frame;
      // What is wholly off the display costs time and shows nothing.
      if (x < width + 60 && y < height + 60 && x + ww > -60 && y + wh > -60) {
        Scenery.window(ctx, { app: w.app, title: w.title, x, y, width: ww, height: wh, focused: !!w.focused });
      }
      // The ring sits directly above the window it surrounds, as if it were part of it.
      if (frame.ring && frame.ring.window === w.id) ring(ctx, frame.ring);
    }
    if (frame.preview) preview(ctx, frame.preview, film);
    if (frame.peek) peek(ctx, frame.peek, film);
    if (frame.stage) stage(ctx, frame.stage, film, frame.windows);

    const names = Object.keys(film.apps);
    const badges = {};
    for (const name of names) if (marks[`badge.${name}`]) badges[name] = Number(marks[`badge.${name}`]);
    Scenery.dock(ctx, width, height, { apps: names, running: names, badges, bounce: (extras && extras.bounce) || {} });
    const front = frame.windows.find((w) => w.focused);
    Scenery.menuBar(ctx, width, film.display.visible[1], {
      app: front ? front.app : 'Desktop', clock: marks.clock || '9:41', slotWidth: frame.menuBar ? frame.menuBar.frame[2] : 0,
    });
    if (frame.menuBar) menuBarItem(ctx, frame.menuBar);

    if (frame.minimap) minimap(ctx, frame.minimap, film);
    if (frame.headsUp) headsUp(ctx, frame.headsUp);
    if (frame.goTo) goTo(ctx, frame.goTo, film, frame);
    if (frame.menu) menu(ctx, frame.menu, film);
    // Two things on the display are the film's own: the ring of `lookHere`, which is painted last of all, and
    // a ring where the button went down, because a click cannot be seen.
    if (extras && extras.press) {
      const { at, age } = extras.press;
      withAlpha(ctx, Math.min((1 - age) * 1.5, 1), () => {
        ctx.beginPath();
        ctx.arc(at[0], at[1], 6 + 20 * (1 - (1 - age) * (1 - age)), 0, 2 * Math.PI);
        ctx.strokeStyle = 'rgba(0,0,0,0.7)';
        ctx.lineWidth = 6;
        ctx.stroke();
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 3;
        ctx.stroke();
      });
    }
    const kind = frame.gapHandle ? (frame.gapHandle.axis === 'horizontal' ? 'resizeLeftRight' : 'resizeUpDown') : 'arrow';
    Scenery.pointer(ctx, frame.pointer.at[0], frame.pointer.at[1], { down: frame.pointer.down, kind });
  }

  // A ring that widens three times round something too small to be noticed on a phone. In the picture's own pixels, over the frame of the
  // display, whose top edge would cut it.
  function lookHere(ctx, look, scale) {
    const x = SCREEN.x + look.at[0] * scale, y = SCREEN.y + look.at[1] * scale;
    for (const start of [0, 0.3, 0.6]) {
      const t = (look.age - start) / 0.4;
      if (t <= 0 || t >= 1) continue;
      withAlpha(ctx, Math.min((1 - t) * 1.6, 1), () => {
        ctx.beginPath();
        ctx.arc(x, y, 16 + 20 * (1 - (1 - t) * (1 - t)), 0, 2 * Math.PI);
        ctx.strokeStyle = 'rgba(0,0,0,0.55)';
        ctx.lineWidth = 7;
        ctx.stroke();
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 3.5;
        ctx.stroke();
      });
    }
  }

  // MARK: The band: the film's own words

  const KEYS = {
    ctrl: ['⌃', 'control'], opt: ['⌥', 'option'], shift: ['⇧', 'shift'], cmd: ['⌘', 'command'],
    return: ['↩', 'return'], escape: ['', 'esc'], space: ['', 'space'], left: ['←', ''], right: ['→', ''], up: ['↑', ''],
    down: ['↓', ''], tab: ['⇥', 'tab'],
  };

  const capWidth = (name) => (name === 'space' ? 190 : (KEYS[name] || ['', ''])[1] ? 112 : 92);

  // A key at rest stands a little proud and a shade darker; pressed, it is down and bright.
  function keyCap(ctx, x, y, name, alpha, down) {
    const [sign, word] = KEYS[name] || [name.length === 1 ? name.toUpperCase() : name, ''];
    const height = 92;
    const width = capWidth(name);
    withAlpha(ctx, alpha, () => {
      if (down) y += 4;
      ctx.fillStyle = down ? '#ffffff' : '#c9cad1';
      ctx.shadowColor = 'rgba(0,0,0,0.55)';
      ctx.shadowBlur = down ? 4 : 10;
      ctx.shadowOffsetY = down ? 1 : 5;
      rounded(ctx, x, y, width, height, 16);
      ctx.fill();
      ctx.shadowColor = 'transparent';
      ctx.fillStyle = '#1c1c1f';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      if (sign) {
        ctx.font = font(word ? 38 : 44, 500);
        ctx.fillText(sign, x + width / 2, y + (word ? 34 : height / 2 + 2));
      }
      if (word) {
        ctx.font = font(19, 500);
        ctx.fillStyle = sign ? '#45454c' : '#1c1c1f';
        ctx.fillText(word, x + width / 2, y + (sign ? 70 : height / 2 + 1));
      }
    });
    return width;
  }


  // What the hands do, at the right of the band, or round `centre` where there is one: `hands` comes from `Timeline.hands`.
  function hands(ctx, shown, y = SCREEN.y + SCREEN.height + 30, centre) {
    if (!shown) return;
    // As one picture: faded piece by piece, the dark signs are gone long before the caps they stand on.
    layer(ctx, shown.alpha, (ctx) => handsAtFullStrength(ctx, { ...shown, alpha: 1 }, y, centre));
  }

  function handsAtFullStrength(ctx, hands, y, centre) {
    const rightOf = (width) => (centre === undefined ? SCREEN.x + SCREEN.width : centre + width / 2);
    if (hands.keys) {
      // The keys of a shortcut are pressed together, which a plus sign says; letters that are typed stand side by side.
      const gap = hands.typing ? 12 : 40;
      const total = hands.keys.reduce((sum, name) => sum + capWidth(name) + gap, -gap);
      let x = rightOf(total) - total;
      hands.keys.forEach((name, index) => {
        x += keyCap(ctx, x, y, name, hands.alpha, hands.down && (!hands.typing || index === hands.keys.length - 1));
        if (!hands.typing && index < hands.keys.length - 1) {
          withAlpha(ctx, hands.alpha * 0.7, () => {
            ctx.font = font(34, 500);
            ctx.fillStyle = '#fff';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('+', x + gap / 2, y + 48);
          });
        }
        x += gap;
      });
    } else if (hands.text) {
      withAlpha(ctx, hands.alpha, () => {
        ctx.font = font(30, 500);
        const width = ctx.measureText(hands.text).width + 48;
        const right = rightOf(width);
        ctx.fillStyle = 'rgba(255,255,255,0.12)';
        rounded(ctx, right - width, y + 14, width, 64, 16);
        ctx.fill();
        ctx.fillStyle = '#fff';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(hands.text, right - width / 2, y + 47);
      });
    }
  }

  function caption(ctx, captions) {
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.font = font(56, 600);
    for (const { text, alpha, rise } of captions) {
      withAlpha(ctx, alpha, () => {
        ctx.fillStyle = '#fff';
        ctx.fillText(text, SCREEN.x + 4, SCREEN.y + SCREEN.height + 78 + rise);
      });
    }
  }

  // Under the caption, small and grey.
  function note(ctx, notes) {
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.font = font(28, 400);
    for (const { text, alpha } of notes) {
      withAlpha(ctx, alpha, () => {
        ctx.fillStyle = 'rgba(255,255,255,0.66)';
        ctx.fillText(text, SCREEN.x + 5, SCREEN.y + SCREEN.height + 130);
      });
    }
  }

  // How wide the caption and what the hands do are, in pixels: `audit.mjs` sees to it that they never meet.
  function bandWidths(ctx, extras) {
    ctx.font = font(56, 600);
    const words = extras.captions.filter((c) => c.alpha > 0.3).map((c) => ctx.measureText(c.text).width);
    ctx.font = font(28, 400);
    words.push(...extras.notes.filter((c) => c.alpha > 0.3).map((c) => ctx.measureText(c.text).width));
    let right = 0;
    if (extras.hands && extras.hands.alpha > 0.3) {
      if (extras.hands.keys) {
        const gap = extras.hands.typing ? 12 : 40;
        right = extras.hands.keys.reduce((sum, name) => sum + capWidth(name) + gap, -gap);
      } else {
        ctx.font = font(30, 500);
        right = ctx.measureText(extras.hands.text).width + 48;
      }
    }
    return { caption: Math.max(0, ...words), hands: right, room: SCREEN.width };
  }

  // MARK: The whole picture

  function ground(ctx) {
    const fill = ctx.createLinearGradient(0, 0, 0, PICTURE.height);
    fill.addColorStop(0, '#15171c');
    fill.addColorStop(1, '#0c0d10');
    ctx.fillStyle = fill;
    ctx.fillRect(0, 0, PICTURE.width, PICTURE.height);
  }

  // `extras` is what `Timeline.at(n)` makes of the film's marks: captions, hands, the end card.
  function picture(ctx, film, frame, extras) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    ground(ctx);
    const scale = SCREEN.width / film.display.frame[2];
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.6)';
    ctx.shadowBlur = 40;
    ctx.shadowOffsetY = 12;
    ctx.fillStyle = '#000';
    rounded(ctx, SCREEN.x, SCREEN.y, SCREEN.width, SCREEN.height, SCREEN.radius);
    ctx.fill();
    ctx.restore();
    ctx.save();
    rounded(ctx, SCREEN.x, SCREEN.y, SCREEN.width, SCREEN.height, SCREEN.radius);
    ctx.clip();
    ctx.translate(SCREEN.x, SCREEN.y);
    ctx.scale(scale, scale);
    display(ctx, film, frame, extras);
    ctx.restore();
    ctx.save();
    ctx.strokeStyle = 'rgba(255,255,255,0.14)';
    ctx.lineWidth = 1.5;
    rounded(ctx, SCREEN.x, SCREEN.y, SCREEN.width, SCREEN.height, SCREEN.radius);
    ctx.stroke();
    ctx.restore();
    if (extras) {
      if (extras.look) {
        // On the display, as if drawn on its glass: what reaches past its edge is cut.
        ctx.save();
        rounded(ctx, SCREEN.x, SCREEN.y, SCREEN.width, SCREEN.height, SCREEN.radius);
        ctx.clip();
        lookHere(ctx, extras.look, scale);
        ctx.restore();
      }
      caption(ctx, extras.captions);
      note(ctx, extras.notes);
      hands(ctx, extras.hands);
      if (extras.card) card(ctx, extras.card);
    }
  }

  // The display as wide as the canvas, and under it a strip for the keys, which are most of what the hands do: for the loop in the
  // README. `STRIP` is the strip's height in points of the display.
  const STRIP = 96;
  function displayOnly(ctx, film, frame, extras) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    const [, , width, height] = film.display.frame;
    const scale = ctx.canvas.width / width;
    ctx.scale(scale, scale);
    display(ctx, film, frame, extras);
    ctx.fillStyle = 'rgb(16,17,21)';
    ctx.fillRect(0, height, width, STRIP + 2);
    // A key cap is 92 high, and 4 lower while it is down.
    const caps = (STRIP - 24) / 96;
    ctx.translate(width / 2, height + 12);
    ctx.scale(caps, caps);
    hands(ctx, extras.hands, 0, 0);
  }

  // The end card: the display dims, then the mark, the name and the lines, one after the other.
  function card(ctx, card) {
    withAlpha(ctx, card.dim, () => {
      ctx.fillStyle = 'rgb(10,11,14)';
      ctx.fillRect(0, 0, PICTURE.width, PICTURE.height);
    });
    const cx = PICTURE.width / 2;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    card.lines.forEach((line) => {
      withAlpha(ctx, line.alpha, () => {
        if (line.kind === 'mark') return arborIcon(ctx, cx - 80, line.y - 80 + line.rise, 160);
        ctx.font = font(line.size, line.weight);
        ctx.fillStyle = line.colour;
        ctx.fillText(line.text, cx, line.y + line.rise);
      });
    });
  }

  // ArborArtwork.appIcon: the mark in white on green, on the usual grid for icons.
  function arborIcon(ctx, x, y, side) {
    const inset = side * 100 / 1024;
    const shape = side - 2 * inset;
    const fill = ctx.createLinearGradient(0, y + inset, 0, y + side - inset);
    fill.addColorStop(0, 'rgb(46,161,97)');
    fill.addColorStop(1, 'rgb(10,74,51)');
    ctx.fillStyle = fill;
    rounded(ctx, x + inset, y + inset, shape, shape, shape * 185.4 / 824);
    ctx.fill();
    // ArborGlyph.cells.
    const mark = Math.round(shape * 0.58);
    const gap = Math.max(Math.round(mark * 0.07), 1);
    const left = Math.round(x + side / 2 - mark / 2), top = Math.round(y + side / 2 - mark / 2);
    const leafWidth = Math.max(Math.round(((mark - gap) * 0.54 - gap) / 2), 0);
    const leftWidth = leafWidth * 2 + gap;
    const leafHeight = Math.max(Math.round((mark - gap) * 0.44), 0);
    const cells = [
      [left + leftWidth + gap, top, mark - leftWidth - gap, mark, 1],
      [left, top + leafHeight + gap, leftWidth, mark - gap - leafHeight, 0.92],
      [left, top, leafWidth, leafHeight, 0.8],
      [left + leafWidth + gap, top, leafWidth, leafHeight, 0.68],
    ];
    for (const [cx, cy, cw, ch, opacity] of cells) {
      ctx.fillStyle = `rgba(255,255,255,${opacity})`;
      rounded(ctx, cx, cy, cw, ch, mark * 0.045);
      ctx.fill();
    }
  }

  return { picture, displayOnly, bandWidths, unpainted, PICTURE, SCREEN, STRIP };
})();

if (typeof module !== 'undefined') module.exports = Paint;
