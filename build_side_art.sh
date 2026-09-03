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
import android.view.ViewTreeObserver;
import android.widget.FrameLayout;
import android.widget.ImageView;
'''
marker = 'import android.content.Intent;\n'
if 'import android.graphics.drawable.ColorDrawable;' not in s:
    if marker not in s:
        raise SystemExit('MicroActivity import marker not found')
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
setup_code = '''setContentView(view);

setupSideArt();
'''
if 'setupSideArt();' not in s:
    if setup_marker not in s:
        raise SystemExit('MicroActivity setContentView marker not found')
    s = s.replace(setup_marker, setup_code, 1)

method_marker = 'public void lockNightMode() {\n'
method = '''private void setupSideArt() {
    View root = binding.getRoot();

    // The complete emulator window must remain black outside the portrait game area.
    root.setBackgroundColor(Color.BLACK);
    binding.displayableContainer.setBackgroundColor(Color.BLACK);
    binding.overlayView.setBackgroundColor(Color.TRANSPARENT);
    getWindow().setBackgroundDrawable(new ColorDrawable(Color.BLACK));
    getWindow().getDecorView().setBackgroundColor(Color.BLACK);

    if (!(root instanceof ViewGroup)) {
        return;
    }

    sideArtContainer = new FrameLayout(this);
    sideArtContainer.setBackgroundColor(Color.BLACK);
    sideArtContainer.setClickable(false);
    sideArtContainer.setFocusable(false);

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
    leftSideArt.setBackgroundColor(Color.TRANSPARENT);
    rightSideArt.setBackgroundColor(Color.TRANSPARENT);
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

    View game = binding.displayableContainer.getChildCount() > 0
            ? binding.displayableContainer.getChildAt(0) : null;

    int gameLeft = 0;
    int gameRight = rootWidth;
    if (game != null && game.getWidth() > 0 && game.getHeight() > 0) {
        int[] rootPos = new int[2];
        int[] gamePos = new int[2];
        root.getLocationOnScreen(rootPos);
        game.getLocationOnScreen(gamePos);
        gameLeft = Math.max(0, Math.min(rootWidth, gamePos[0] - rootPos[0]));
        gameRight = Math.max(gameLeft, Math.min(rootWidth, gameLeft + game.getWidth()));
    } else {
        int gameWidth = Math.min(rootHeight * 3 / 4, rootWidth);
        gameLeft = (rootWidth - gameWidth) / 2;
        gameRight = gameLeft + gameWidth;
    }

    FrameLayout.LayoutParams left = (FrameLayout.LayoutParams) leftSideArt.getLayoutParams();
    left.width = gameLeft;
    left.height = rootHeight;
    left.leftMargin = 0;
    left.topMargin = 0;
    left.gravity = Gravity.TOP | Gravity.START;
    leftSideArt.setLayoutParams(left);

    FrameLayout.LayoutParams right = (FrameLayout.LayoutParams) rightSideArt.getLayoutParams();
    right.width = rootWidth - gameRight;
    right.height = rootHeight;
    right.leftMargin = gameRight;
    right.topMargin = 0;
    right.gravity = Gravity.TOP | Gravity.START;
    rightSideArt.setLayoutParams(right);

    sideArtContainer.bringToFront();
}

'''
if 'private void setupSideArt()' not in s:
    if method_marker not in s:
        raise SystemExit('MicroActivity method marker not found')
    s = s.replace(method_marker, method + method_marker, 1)

line_marker = 'binding.displayableContainer.addView(next.getDisplayableView());\n'
line_replacement = line_marker + '\t\tpositionSideArt();\n\t\tbinding.getRoot().post(MicroActivity.this::positionSideArt);\n'
if 'MicroActivity.this::positionSideArt' not in s:
    if line_marker not in s:
        raise SystemExit('MicroActivity displayable add marker not found')
    s = s.replace(line_marker, line_replacement, 1)

p.write_text(s)
PY
