#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/j2me-loader"
python3 - <<'PY'
from pathlib import Path
p = Path('app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()

imports = '''import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.ViewTreeObserver;
import android.widget.FrameLayout;
import android.widget.ImageView;
'''
marker = 'import android.content.Intent;\n'
if 'import android.view.MotionEvent;' not in s:
    if marker not in s:
        raise SystemExit('MicroActivity import marker not found')
    old = '''import android.graphics.BitmapFactory;\nimport android.graphics.Color;\nimport android.graphics.drawable.ColorDrawable;\nimport android.view.Gravity;\nimport android.view.ViewTreeObserver;\nimport android.widget.FrameLayout;\nimport android.widget.ImageView;\n'''
    if old in s:
        s = s.replace(old, imports, 1)
    else:
        s = s.replace(marker, marker + imports, 1)

field_marker = 'private String appPath;\n'
fields = '''private ImageView leftSideArt;
private ImageView rightSideArt;
private FrameLayout sideArtContainer;
private ViewTreeObserver.OnGlobalLayoutListener sideArtLayoutListener;
'''
if 'private FrameLayout sideArtContainer;' not in s:
    if field_marker not in s:
        raise SystemExit('MicroActivity field marker not found')
    s = s.replace(field_marker, field_marker + fields, 1)

setup_marker = 'setContentView(view);\n'
if 'setupSideArt();' not in s:
    if setup_marker not in s:
        raise SystemExit('MicroActivity setContentView marker not found')
    s = s.replace(setup_marker, setup_marker + '\nsetupSideArt();\n', 1)

method_marker = 'public void lockNightMode() {\n'
method = '''private void setupSideArt() {
    View root = binding.getRoot();

    root.setBackgroundColor(Color.BLACK);
    binding.displayableContainer.setBackgroundColor(Color.BLACK);
    binding.overlayView.setBackgroundColor(Color.TRANSPARENT);
    binding.overlayView.setAlpha(0.0f);
    getWindow().setBackgroundDrawable(new ColorDrawable(Color.BLACK));
    getWindow().getDecorView().setBackgroundColor(Color.BLACK);

    if (!(root instanceof ViewGroup)) {
        return;
    }

    sideArtContainer = new FrameLayout(this) {
        @Override
        public boolean dispatchTouchEvent(MotionEvent event) {
            return false;
        }
    };
    // Transparent full-screen holder: it must never paint over the game.
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
    } catch (java.io.IOException e) {
        throw new RuntimeException("Side PNG load failed", e);
    }

    leftSideArt.setScaleType(ImageView.ScaleType.FIT_CENTER);
    rightSideArt.setScaleType(ImageView.ScaleType.FIT_CENTER);
    leftSideArt.setBackgroundColor(Color.BLACK);
    rightSideArt.setBackgroundColor(Color.BLACK);
    leftSideArt.setClickable(false);
    rightSideArt.setClickable(false);
    leftSideArt.setFocusable(false);
    rightSideArt.setFocusable(false);

    sideArtContainer.addView(leftSideArt, new FrameLayout.LayoutParams(1, 1));
    sideArtContainer.addView(rightSideArt, new FrameLayout.LayoutParams(1, 1));
    ((ViewGroup) root).addView(sideArtContainer, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT));

    sideArtLayoutListener = this::positionSideArt;
    root.getViewTreeObserver().addOnGlobalLayoutListener(sideArtLayoutListener);
    root.post(this::positionSideArt);

    // The transparent J2ME Loader overlay stays ABOVE the artwork so its
    // VirtualKeyboard continues to receive touch events. Its graphics remain
    // invisible because alpha is 0, while touch handling is still active.
    binding.overlayView.bringToFront();
}

private void positionSideArt() {
    if (sideArtContainer == null || leftSideArt == null || rightSideArt == null || binding == null) {
        return;
    }

    View root = binding.getRoot();
    int rootWidth = root.getWidth();
    int rootHeight = root.getHeight();
    if (rootWidth <= 0 || rootHeight <= 0) {
        return;
    }

    int gameWidth = Math.min(rootWidth, Math.round(rootHeight * 0.75f));
    int gameLeft = (rootWidth - gameWidth) / 2;
    int gameRight = gameLeft + gameWidth;

    FrameLayout.LayoutParams left = (FrameLayout.LayoutParams) leftSideArt.getLayoutParams();
    left.width = Math.max(0, gameLeft);
    left.height = rootHeight;
    left.leftMargin = 0;
    left.topMargin = 0;
    left.gravity = Gravity.TOP | Gravity.START;
    leftSideArt.setLayoutParams(left);

    FrameLayout.LayoutParams right = (FrameLayout.LayoutParams) rightSideArt.getLayoutParams();
    right.width = Math.max(0, rootWidth - gameRight);
    right.height = rootHeight;
    right.leftMargin = gameRight;
    right.topMargin = 0;
    right.gravity = Gravity.TOP | Gravity.START;
    rightSideArt.setLayoutParams(right);
}

'''
if 'private void setupSideArt()' not in s:
    if method_marker not in s:
        raise SystemExit('MicroActivity method marker not found')
    s = s.replace(method_marker, method + method_marker, 1)

line_marker = 'binding.displayableContainer.addView(next.getDisplayableView());\n'
line_replacement = line_marker + '''\t\tfor (int i = 0; i < binding.displayableContainer.getChildCount(); i++) {
\t\t\tbinding.displayableContainer.getChildAt(i).setBackgroundColor(Color.BLACK);
\t\t}
\t\tpositionSideArt();
\t\tbinding.getRoot().post(MicroActivity.this::positionSideArt);
'''
if 'MicroActivity.this::positionSideArt' not in s:
    if line_marker not in s:
        raise SystemExit('MicroActivity displayable add marker not found')
    s = s.replace(line_marker, line_replacement, 1)

p.write_text(s)
PY
