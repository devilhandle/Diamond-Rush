#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/j2me-loader"
python3 - <<'PY'
from pathlib import Path
p = Path('app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()

# Imports needed by the custom side-control overlay.
for imp in [
    'import android.graphics.BitmapFactory;\n',
    'import android.graphics.Color;\n',
    'import android.graphics.drawable.ColorDrawable;\n',
    'import android.view.Gravity;\n',
    'import android.view.MotionEvent;\n',
    'import android.view.ViewTreeObserver;\n',
    'import android.widget.FrameLayout;\n',
    'import android.widget.ImageView;\n']:
    if imp not in s:
        s = s.replace('import android.content.Intent;\n', 'import android.content.Intent;\n' + imp, 1)

if 'private FrameLayout sideArtContainer;' not in s:
    marker = 'private String appPath;\n'
    if marker not in s: raise SystemExit('field marker not found')
    s = s.replace(marker, marker + '''private ImageView leftSideArt;\nprivate ImageView rightSideArt;\nprivate FrameLayout sideArtContainer;\nprivate ViewTreeObserver.OnGlobalLayoutListener sideArtLayoutListener;\n''', 1)

if 'setupSideArt();' not in s:
    marker = 'setContentView(view);\n'
    if marker not in s: raise SystemExit('setContentView marker not found')
    s = s.replace(marker, marker + '\nsetupSideArt();\n', 1)

if 'private void setupSideArt()' not in s:
    marker = 'public void lockNightMode() {\n'
    if marker not in s: raise SystemExit('method marker not found')
    method = r'''private void setupSideArt() {
    View root = binding.getRoot();
    root.setBackgroundColor(Color.BLACK);
    binding.displayableContainer.setBackgroundColor(Color.BLACK);
    binding.overlayView.setBackgroundColor(Color.TRANSPARENT);
    binding.overlayView.setAlpha(0.0f);
    getWindow().setBackgroundDrawable(new ColorDrawable(Color.BLACK));
    getWindow().getDecorView().setBackgroundColor(Color.BLACK);
    if (!(root instanceof ViewGroup)) return;

    sideArtContainer = new FrameLayout(this) {
        private final int[] pressedKeys = new int[20];

        private boolean hit(float x, float y, float cx, float cy, float rx, float ry) {
            float dx = (x - cx) / rx, dy = (y - cy) / ry;
            return dx * dx + dy * dy <= 1.0f;
        }

        private int keyFor(float x, float y) {
            int w = getWidth(), h = getHeight();
            if (w <= 0 || h <= 0) return 0;
            int gameWidth = Math.min(w, Math.round(h * 0.75f));
            int gameLeft = (w - gameWidth) / 2, gameRight = gameLeft + gameWidth;
            float ny = y / (float) h;

            if (x < gameLeft) {
                float px = x / (float) Math.max(1, gameLeft);
                // Pause: direct soft-left dispatch bypasses SoftBar command consumption.
                if (hit(px, ny, 0.34f, 0.41f, 0.10f, 0.09f)) return Canvas.KEY_SOFT_LEFT;
                if (hit(px, ny, 0.48f, 0.51f, 0.085f, 0.08f)) return Canvas.KEY_SOFT_RIGHT;
                if (hit(px, ny, 0.35f, 0.655f, 0.12f, 0.12f)) return Canvas.KEY_LEFT;
                if (hit(px, ny, 0.61f, 0.655f, 0.12f, 0.12f)) return Canvas.KEY_RIGHT;
                if (hit(px, ny, 0.48f, 0.81f, 0.12f, 0.12f)) return Canvas.KEY_DOWN;
                // UP target moved down onto the visible arrow instead of above it.
                if (hit(px, ny, 0.48f, 0.655f, 0.105f, 0.085f)) return Canvas.KEY_UP;
            } else if (x > gameRight) {
                float px = (x - gameRight) / (float) Math.max(1, w - gameRight);
                if (hit(px, ny, 0.41f, 0.63f, 0.14f, 0.14f)) return Canvas.KEY_NUM5;
                if (hit(px, ny, 0.46f, 0.80f, 0.14f, 0.14f)) return Canvas.KEY_STAR;
            }
            return 0;
        }

        private void press(int id, int key) {
            if (id < 0 || id >= pressedKeys.length || key == 0) return;
            Displayable d = MicroActivity.this.getCurrent();
            if (d instanceof Canvas) {
                pressedKeys[id] = key;
                Canvas c = (Canvas)d;
                // Soft keys are sent directly to the MIDP Canvas so SoftBar cannot consume them.
                if (key == Canvas.KEY_SOFT_LEFT || key == Canvas.KEY_SOFT_RIGHT) c.doKeyPressed(key);
                else c.postKeyPressed(key);
            }
        }

        private void release(int id) {
            if (id < 0 || id >= pressedKeys.length) return;
            int key = pressedKeys[id];
            if (key == 0) return;
            Displayable d = MicroActivity.this.getCurrent();
            if (d instanceof Canvas) {
                Canvas c = (Canvas)d;
                if (key == Canvas.KEY_SOFT_LEFT || key == Canvas.KEY_SOFT_RIGHT) c.doKeyReleased(key);
                else c.postKeyReleased(key);
            }
            pressedKeys[id] = 0;
        }

        @Override public boolean dispatchTouchEvent(MotionEvent e) {
            int a = e.getActionMasked(), i = e.getActionIndex(), id = e.getPointerId(i);
            if (a == MotionEvent.ACTION_DOWN || a == MotionEvent.ACTION_POINTER_DOWN) {
                int key = keyFor(e.getX(i), e.getY(i));
                if (key != 0) { press(id, key); return true; }
                return false;
            }
            if (a == MotionEvent.ACTION_UP || a == MotionEvent.ACTION_POINTER_UP) { release(id); return true; }
            if (a == MotionEvent.ACTION_CANCEL) {
                for (int n = 0; n < pressedKeys.length; n++) release(n);
                return true;
            }
            return false;
        }
    };

    sideArtContainer.setBackgroundColor(Color.TRANSPARENT);
    sideArtContainer.setClickable(false);
    sideArtContainer.setFocusable(false);
    sideArtContainer.setWillNotDraw(true);
    leftSideArt = new ImageView(this);
    rightSideArt = new ImageView(this);
    try (java.io.InputStream left = getAssets().open("side_left.png");
         java.io.InputStream right = getAssets().open("side_right.png")) {
        leftSideArt.setImageBitmap(BitmapFactory.decodeStream(left));
        rightSideArt.setImageBitmap(BitmapFactory.decodeStream(right));
    } catch (java.io.IOException e) { throw new RuntimeException("Side PNG load failed", e); }
    leftSideArt.setScaleType(ImageView.ScaleType.FIT_CENTER);
    rightSideArt.setScaleType(ImageView.ScaleType.FIT_CENTER);
    leftSideArt.setBackgroundColor(Color.BLACK);
    rightSideArt.setBackgroundColor(Color.BLACK);
    leftSideArt.setClickable(false); rightSideArt.setClickable(false);
    leftSideArt.setFocusable(false); rightSideArt.setFocusable(false);
    sideArtContainer.addView(leftSideArt, new FrameLayout.LayoutParams(1, 1));
    sideArtContainer.addView(rightSideArt, new FrameLayout.LayoutParams(1, 1));
    ((ViewGroup)root).addView(sideArtContainer, new ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    sideArtLayoutListener = this::positionSideArt;
    root.getViewTreeObserver().addOnGlobalLayoutListener(sideArtLayoutListener);
    root.post(this::positionSideArt);
    binding.overlayView.bringToFront();
}

private void positionSideArt() {
    if (sideArtContainer == null || leftSideArt == null || rightSideArt == null || binding == null) return;
    View root = binding.getRoot();
    int rw = root.getWidth(), rh = root.getHeight();
    if (rw <= 0 || rh <= 0) return;
    int gameWidth = Math.min(rw, Math.round(rh * 0.75f));
    int gameLeft = (rw - gameWidth) / 2, gameRight = gameLeft + gameWidth;
    FrameLayout.LayoutParams l = (FrameLayout.LayoutParams)leftSideArt.getLayoutParams();
    l.width = Math.max(0, gameLeft); l.height = rh; l.leftMargin = 0; l.topMargin = 0;
    l.gravity = Gravity.TOP | Gravity.START; leftSideArt.setLayoutParams(l);
    FrameLayout.LayoutParams r = (FrameLayout.LayoutParams)rightSideArt.getLayoutParams();
    r.width = Math.max(0, rw - gameRight); r.height = rh; r.leftMargin = gameRight; r.topMargin = 0;
    r.gravity = Gravity.TOP | Gravity.START; rightSideArt.setLayoutParams(r);
}

'''
    s = s.replace(marker, method + marker, 1)

line = 'binding.displayableContainer.addView(next.getDisplayableView());\n'
if 'MicroActivity.this::positionSideArt' not in s:
    if line not in s: raise SystemExit('displayable marker not found')
    s = s.replace(line, line + '''\t\tfor (int i = 0; i < binding.displayableContainer.getChildCount(); i++) {\n\t\t\tbinding.displayableContainer.getChildAt(i).setBackgroundColor(Color.BLACK);\n\t\t}\n\t\tpositionSideArt();\n\t\tbinding.getRoot().post(MicroActivity.this::positionSideArt);\n''', 1)

p.write_text(s)
PY