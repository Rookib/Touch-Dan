#!/usr/bin/env python3
"""Run actual production method bodies with Foundation mocks on macOS.

This checks state transitions and cleanup, not UIKit rendering or SpringBoard
compatibility. It neither builds the tweak package nor accesses any device.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def definition(source: str, marker: str) -> str:
    """Extract one complete C function/Objective-C method, including its body."""
    start = source.index(marker)
    opening = source.index("{", start)
    token = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[{}]')
    depth = 0
    for match in token.finditer(source, opening):
        if match.group() == "{":
            depth += 1
        elif match.group() == "}":
            depth -= 1
            if depth == 0:
                return source[start:match.end()]
    raise ValueError(f"Unterminated definition: {marker}")


main = (ROOT / "TouchDan.xm").read_text()
window = (ROOT / "TDNTouchVisualizer/Private/TDNTouchVisualizerWindow.m").read_text()
scene = (ROOT / "TDNTouchVisualizer/Private/UIWindowScene+TouchVisualizer.m").read_text()
template = (ROOT / "Tests/lifecycle-tests.m.in").read_text()

window_methods = [
    "- (void)setQuickPathEnabled:",
    "- (void)setMorphEnabled:",
    "- (void)setTouchVisualizationEnabled:",
    "- (void)resetTouchVisualization",
    "- (void)sendTouchEvent:",
    "- (void)removeInactiveFingerTips",
    "- (BOOL)hasAnyTouch",
    "- (void)_removeFingerTipWithHash:",
    "- (void)performMorphWithTouchView:",
]
sections = {
    "WINDOW_METHODS": "\n\n".join(definition(window, name) for name in window_methods),
    "SCENE_METHODS": "\n\n".join(definition(scene, name) for name in [
        "- (void)setTdn_touchVisualizerEnabled:", "- (BOOL)tdn_touchVisualizerEnabled"]),
    "GLOBALS": "\n".join(re.findall(r"^static BOOL _g\w+ = (?:NO|YES);", main, re.MULTILINE)),
    "STATE_FUNCTIONS": "\n\n".join(definition(main, name) for name in [
        "static BOOL IsEnabled(void)", "static BOOL ShouldKeepSystemGestureTouchStreamSending(void)",
        "static void ReloadStats(void)"]).replace("%c(SBReachabilityManager)", "SBReachabilityManager"),
    "BLOCK_LAYOUT": main[main.index("struct BlockDescriptor {"):main.index("static NSString *BlockSig")],
    "BLOCK_FUNCTION": definition(main, "static NSString *BlockSig"),
}
for key, value in sections.items():
    placeholder = "/* @" + key + "@ */"
    if template.count(placeholder) != 1:
        raise ValueError(f"Missing or duplicate template insertion point: {key}")
    template = template.replace(placeholder, value)

with tempfile.TemporaryDirectory(prefix="touch-dan-lifecycle-") as directory:
    directory = Path(directory)
    source_path = directory / "lifecycle-tests.m"
    executable = directory / "lifecycle-tests"
    source_path.write_text(template)
    subprocess.run([
        "xcrun", "--sdk", "macosx", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
        "-Wno-unused-parameter", "-framework", "Foundation", "-framework", "CoreGraphics",
        str(source_path), "-o", str(executable)
    ], check=True)
    subprocess.run([str(executable)], check=True)
