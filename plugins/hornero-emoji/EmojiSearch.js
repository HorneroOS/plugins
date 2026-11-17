.pragma library

// Pure emoji search over the generated EmojiData.qml table (Unicode 16.0).
// Line format: emoji|name|group|five skin-tone variants (light to dark).
// Shared by the launcher provider and the dashboard picker; no I/O.

var TONE_ORDER = ["default", "light", "medium-light", "medium", "medium-dark", "dark"];
var GROUP_LABEL = {
    "smileys": "Smileys & emotion",
    "people": "People & body",
    "nature": "Animals & nature",
    "food": "Food & drink",
    "travel": "Travel & places",
    "activities": "Activities",
    "objects": "Objects",
    "symbols": "Symbols",
    "flags": "Flags"
};

function parse(raw) {
    var entries = [];
    var lines = String(raw).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("|");
        if (parts.length < 3 || parts[0] === "" || parts[1] === "")
            continue;
        entries.push({
            "char": parts[0],
            "name": parts[1],
            "group": parts[2],
            "tones": parts[3] ? parts[3].split(",") : [],
            "lower": parts[1].toLowerCase()
        });
    }
    return entries;
}

// The emoji to show or copy for an entry under the person's skin tone.
function glyphFor(entry, tone) {
    var index = TONE_ORDER.indexOf(tone) - 1;
    if (index >= 0 && entry.tones.length === 5)
        return entry.tones[index];
    return entry.char;
}

function _score(entry, terms) {
    var total = 0;
    for (var i = 0; i < terms.length; i++) {
        var term = terms[i];
        var name = entry.lower;
        var at = name.indexOf(term);
        var s;
        if (name === term)
            s = 0;
        else if (at === 0)
            s = 1;
        else if (at > 0 && name.charAt(at - 1) === " ")
            s = 2;
        else if (at > 0)
            s = 4;
        else if (entry.group.indexOf(term) === 0)
            s = 6;
        else
            return -1;
        total += s;
    }
    return total;
}

// Ranked entries for a query (all words must match the name, a word
// start beats an inner match, the group name matches as a last resort).
// An empty query returns the first entries in Unicode order.
function search(entries, query, limit) {
    var text = String(query || "").trim().toLowerCase();
    var max = Math.max(1, limit | 0);
    if (text === "")
        return entries.slice(0, max);
    var terms = text.split(/\s+/);
    var scored = [];
    for (var i = 0; i < entries.length; i++) {
        var score = _score(entries[i], terms);
        if (score >= 0)
            scored.push({"score": score, "index": i});
    }
    scored.sort(function (a, b) {
        return a.score - b.score || a.index - b.index;
    });
    return scored.slice(0, max).map(function (item) {
        return entries[item.index];
    });
}

function rowsFor(entries, query, tone, limit, showGroup, groupLabel) {
    return search(entries, query, limit).map(function (entry) {
        var glyph = glyphFor(entry, tone);
        return {
            "text": glyph,
            "title": glyph + "  " + entry.name,
            "subtitle": showGroup ? groupLabel(entry.group) : ""
        };
    });
}
