"""Backport the pinned iosMath 0.9.5 sources to pre-subscripting Foundation."""
from pathlib import Path
import hashlib
import json
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else "vendor/iosMath") / "iosMath"
expected = json.loads(Path(__file__).with_name("iosmath-0.9.5-sha256.json").read_text())
for filename, digest in expected.items():
    if hashlib.sha256((root / filename).read_bytes()).hexdigest() != digest:
        raise SystemExit(f"Unexpected iosMath source: {filename}; review before patching")
# Receivers inspected in this exact dependency version; C arrays are not rewritten.
receivers = {
    "lib/MTMathListIndex.m": ("", "ranges"),
    "lib/MTMathList.m": ("", "row _cells rowArray _alignments self.alignments"),
    "lib/MTMathListBuilder.m": ("spaceToCommands styleToCommands", "delims rows table.cells row cell.atoms"),
    "lib/MTMathAtomFactory.m": ("aliases commands dict accents delims fontStyles textToCommands mutableDict",
                              "rows table.cells row"),
    "render/MTFontManager.m": ("self.nameToFontMap", ""),
    "render/internal/MTFontMathTable.m": (
        "_mathTable consts variants italics accents assemblyTable assemblyInfo partInfo", ""),
    "render/MTMathListDisplay.m": ("", "offsets"),
    "render/internal/MTTypesetter.m": ("", "spaceArray variants offsetsRv accent.innerList.atoms row cols"),
}
helper = """#import <Foundation/Foundation.h>
static inline void MTLegacyArraySet(NSMutableArray *array, NSUInteger index, id value) {
    if (index == [array count]) [array addObject:value];
    else [array replaceObjectAtIndex:index withObject:value];
}
static inline void MTLegacyDictionarySet(NSMutableDictionary *dict, id key, id value) {
    if (value) [dict setObject:value forKey:key];
    else [dict removeObjectForKey:key];
}
"""
(root / "lib/MTLegacyCollections.h").write_text(helper, encoding="utf-8", newline="\n")
for filename, (dicts, arrays) in receivers.items():
    path = root / filename
    text = path.read_text(encoding="utf-8")
    assert "MTLegacyCollections.h" not in text, "Apply only to fresh iosMath 0.9.5"
    if filename == "lib/MTMathListBuilder.m":
        text = text.replace("rows[currentRow][currentCol] = firstList;",
                            "MTLegacyArraySet([rows objectAtIndex:currentRow], currentCol, firstList);")
        text = text.replace("rows[currentRow][currentCol] = list;",
                            "MTLegacyArraySet([rows objectAtIndex:currentRow], currentCol, list);")
    if filename == "lib/MTMathAtomFactory.m":
        # Here 'delims' names both a dictionary and a locally scoped delimiter pair.
        for index in ("0", "1"):
            text = text.replace(f"delims[{index}]", f"[delims objectAtIndex:{index}]")
    if filename == "render/internal/MTTypesetter.m":
        text = text.replace("getInterElementSpaces()[leftIndex]",
                            "[getInterElementSpaces() objectAtIndex:leftIndex]")
        # Other methods use a C buffer with the same local name.
        text = text.replace("glyphs[0].shortValue", "[[glyphs objectAtIndex:0] shortValue]")
    if filename == "render/MTMathListDisplay.m":
        text = text.replace("glyphs[i].shortValue", "[[glyphs objectAtIndex:i] shortValue]")
    for names, getter, setter in (
        (dicts, "objectForKey", "MTLegacyDictionarySet"),
        (arrays, "objectAtIndex", "MTLegacyArraySet"),
    ):
        for name in names.split():
            pattern = r"(?<![\w.])" + re.escape(name) + r"\[([^\[\]\n]+)\]"
            # Writes may append at count; replaceObjectAtIndex alone is not equivalent.
            text = re.sub(pattern + r"\s*=\s*([^;\n]+);",
                          lambda m: f"{setter}({name}, {m[1]}, {m[2]});", text)
            text = re.sub(pattern, lambda m: f"[{name} {getter}:{m[1]}]", text)
    if filename == "render/MTMathListDisplay.m":
        # The original version check already selects computeDimensions: below iOS 6.
        old = "            CGRect bounds = CTLineGetBoundsWithOptions(_line, kCTLineBoundsUseGlyphPathBounds);"
        assert old in text
        text = text.replace(old, '#pragma clang diagnostic push\n'
                            '#pragma clang diagnostic ignored "-Wunguarded-availability"\n'
                            + old + '\n#pragma clang diagnostic pop')
    text = '#import "MTLegacyCollections.h"\n' + text
    path.write_text(text, encoding="utf-8", newline="\n")

label = root / "render/MTMathUILabel.m"
text = label.read_text(encoding="utf-8")
old = "[self invalidateIntrinsicContentSize];"
assert text.count(old) == 6
# Existing setNeedsLayout calls remain active on every OS. Auto Layout is optional.
text = text.replace(old, "if ([self respondsToSelector:@selector(invalidateIntrinsicContentSize)]) {\n"
                    "        [self performSelector:@selector(invalidateIntrinsicContentSize)];\n"
                    "    }")
label.write_text(text, encoding="utf-8", newline="\n")
print("Applied iosMath 0.9.5 legacy Foundation and layout compatibility patch")
