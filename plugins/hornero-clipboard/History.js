.pragma library

// In-memory clipboard history shared by the three surfaces of this
// extension (launcher provider, dashboard card, command handler). As a
// `.pragma library` module there is exactly one instance per shell
// process, so a command that clears the history empties the same list the
// launcher searches. NOTHING here ever touches the disk: the list lives and
// dies with the shell process (restart, disable and Clear all erase it).

var items = [];

function count() {
    return items.length;
}

function clear() {
    items = [];
}

function _terms(csv) {
    return String(csv || "").split(",").map(function (term) {
        return term.trim().toLowerCase();
    }).filter(function (term) {
        return term.length > 0;
    });
}

// Whether text may be recorded: non-blank, within the length limit and
// free of the person's excluded words (case-insensitive substrings).
function acceptable(text, maxChars, excludeCsv) {
    if (typeof text !== "string" || text.trim() === "")
        return false;
    if (text.length > maxChars)
        return false;
    var lower = text.toLowerCase();
    var terms = _terms(excludeCsv);
    for (var i = 0; i < terms.length; i++) {
        if (lower.indexOf(terms[i]) >= 0)
            return false;
    }
    return true;
}

// Mime types a clipboard offer advertises. Password managers mark secrets
// with x-kde-passwordManagerHint; such offers are never recorded.
function offerDecision(typesText, skipSensitive) {
    var types = String(typesText || "").split("\n").map(function (line) {
        return line.trim().toLowerCase();
    }).filter(function (line) {
        return line.length > 0;
    });
    var hasText = types.some(function (type) {
        return type === "text/plain" || type.indexOf("text/plain;") === 0 || type === "utf8_string" || type === "string" || type === "text";
    });
    if (!hasText)
        return "no-text";
    if (skipSensitive && types.indexOf("x-kde-passwordmanagerhint") >= 0)
        return "sensitive";
    return "ok";
}

// Records text at the front, moving an identical earlier entry up instead
// of duplicating it, and trims to `max` entries.
function add(text, nowMs, max) {
    items = items.filter(function (item) {
        return item.text !== text;
    });
    items.unshift({"text": text, "at": nowMs});
    if (items.length > max)
        items.length = Math.max(1, max);
}

function trim(max) {
    if (items.length > max)
        items.length = Math.max(1, max);
}

// Drops entries older than retentionMinutes (0 keeps them until the shell
// restarts or the history is cleared).
function purge(nowMs, retentionMinutes) {
    if (!(retentionMinutes > 0))
        return;
    var cutoff = nowMs - retentionMinutes * 60000;
    items = items.filter(function (item) {
        return item.at >= cutoff;
    });
}

// Newest first; a non-empty query keeps entries containing every word.
function search(query, limit) {
    var terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(function (term) {
        return term.length > 0;
    });
    var out = [];
    for (var i = 0; i < items.length && out.length < limit; i++) {
        var lower = items[i].text.toLowerCase();
        if (terms.every(function (term) {
            return lower.indexOf(term) >= 0;
        }))
            out.push(items[i]);
    }
    return out;
}

function ageLabelParts(nowMs, atMs) {
    var seconds = Math.max(0, Math.floor((nowMs - atMs) / 1000));
    if (seconds < 60)
        return {"unit": "now", "n": 0};
    if (seconds < 3600)
        return {"unit": "min", "n": Math.floor(seconds / 60)};
    return {"unit": "hour", "n": Math.floor(seconds / 3600)};
}
