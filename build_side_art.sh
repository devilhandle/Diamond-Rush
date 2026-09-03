#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/j2me-loader"
python3 - <<'PY'
from pathlib import Path
p = Path('app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()

imports = '''import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.ImageView;
'''
marker = 'import android.content.Intent;\n'
if 'import android.graphics.BitmapFactory;' not in s:
    if marker not in s:
        raise SystemExit('MicroActivity import marker not found')
    s = s.replace(marker, marker + imports, 1)

field_marker = 'private String appPath;\n'
fields = '''private ImageView leftSideArt;
private ImageView rightSideArt;
'''
if 'private ImageView leftSideArt;' not in s:
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
    if (!(root instanceof ViewGroup)) {
        return;
    }

    root.setBackgroundColor(Color.BLACK);

    FrameLayout container = new FrameLayout(this);
    container.setBackgroundColor(Color.TRANSPARENT);
    container.setClickable(false);
    container.setFocusable(false);

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
    leftSideArt.setClickable(false);
    rightSideArt.setClickable(false);
    leftSideArt.setFocusable(false);
    rightSideArt.setFocusable(false);

    container.addView(leftSideArt, new FrameLayout.LayoutParams(1, 1));
    container.addView(rightSideArt, new FrameLayout.LayoutParams(1, 1));

    ((ViewGroup) root).addView(container, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT));

    root.post(this::positionSideArt);
}

private void positionSideArt() {
    if (leftSideArt == null || rightSideArt == null || binding == null) {
        return;
    }

    View root = binding.getRoot();
    int rootWidth = root.getWidth();
    int rootHeight = root.getHeight();
    if (rootWidth <= 0 || rootHeight <= 0) {
        root.post(this::positionSideArt);
        return;
    }

    View game = binding.displayableContainer.getChildCount() > 0
            ? binding.displayableContainer.getChildAt(0) : null;
    int gameWidth = game != null ? game.getWidth() : Math.min(rootHeight * 3 / 4, rootWidth);
    if (gameWidth <= 0) {
        gameWidth = Math.min(rootHeight * 3 / 4, rootWidth);
    }

    int sideWidth = Math.max(0, (rootWidth - gameWidth) / 2);

    FrameLayout.LayoutParams left = (FrameLayout.LayoutParams) leftSideArt.getLayoutParams();
    left.width = sideWidth;
    left.height = rootHeight;
    left.leftMargin = 0;
    left.topMargin = 0;
    left.gravity = Gravity.START | Gravity.TOP;
    leftSideArt.setLayoutParams(left);

    FrameLayout.LayoutParams right = (FrameLayout.LayoutParams) rightSideArt.getLayoutParams();
    right.width = sideWidth;
    right.height = rootHeight;
    right.leftMargin = rootWidth - sideWidth;
    right.topMargin = 0;
    right.gravity = Gravity.START | Gravity.TOP;
    rightSideArt.setLayoutParams(right);
}

'''
if 'private void setupSideArt()' not in s:
    if method_marker not in s:
        raise SystemExit('MicroActivity method marker not found')
    s = s.replace(method_marker, method + method_marker, 1)

line_marker = 'binding.displayableContainer.addView(next.getDisplayableView());\n'
line_replacement = line_marker + 'positionSideArt();\n\tbinding.getRoot().post(MicroActivity.this::positionSideArt);\n'
if 'MicroActivity.this::positionSideArt' not in s:
    if line_marker not in s:
        raise SystemExit('MicroActivity displayable add marker not found')
    s = s.replace(line_marker, line_replacement, 1)

p.write_text(s)
PY
