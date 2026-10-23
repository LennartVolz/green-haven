class_name Icons
extends RefCounted
## Klare, einfarbig-freundliche Symbole als SVG (zur Laufzeit gerastert).
## So bleiben die Icons scharf auf allen Bildschirmdichten und es sind keine
## Bilddateien nötig.

const SVG := {
	"coin": '<circle cx="32" cy="32" r="26" fill="#F4C95D" stroke="#C99A2E" stroke-width="4"/><circle cx="32" cy="32" r="17" fill="none" stroke="#E0A93A" stroke-width="3"/><path d="M32 21c-8 4-10 12-6 21 8-2 12-11 6-21z" fill="#C99A2E"/>',
	"star": '<polygon points="32,5 40,24 60,26 45,39 49,59 32,48 15,59 19,39 4,26 24,24" fill="#F4C95D" stroke="#C99A2E" stroke-width="3" stroke-linejoin="round"/>',
	"heart": '<path d="M32 57C10 41 5 25 17 14c7-5 14-1 15 6 1-7 8-11 15-6 12 11 7 27-15 43z" fill="#E8587A" stroke="#B93C5C" stroke-width="3" stroke-linejoin="round"/>',
	"crate": '<rect x="6" y="20" width="52" height="38" rx="5" fill="#C28E5B" stroke="#8E6240" stroke-width="4"/><path d="M6 32h52M22 20v38M42 20v38" stroke="#8E6240" stroke-width="3"/><path d="M10 12h44l4 8H6z" fill="#D9A56E" stroke="#8E6240" stroke-width="3" stroke-linejoin="round"/>',
	"shop": '<path d="M5 26L11 8h42l6 18z" fill="#E0783A"/><path d="M5 26h54v7a9 9 0 01-18 0 9 9 0 01-18 0 9 9 0 01-18 0z" fill="#FFF6E0"/><rect x="10" y="36" width="44" height="22" fill="#C28E5B"/><rect x="25" y="42" width="14" height="16" fill="#8E6240"/>',
	"scroll": '<rect x="11" y="8" width="42" height="52" rx="7" fill="#FFF6E0" stroke="#8E6240" stroke-width="4"/><rect x="23" y="3" width="18" height="11" rx="4" fill="#8DB580" stroke="#6F9A63" stroke-width="2"/><path d="M20 28h24M20 38h24M20 48h14" stroke="#8DB580" stroke-width="5" stroke-linecap="round"/>',
	"paw": '<ellipse cx="32" cy="42" rx="15" ry="13" fill="#E8A87C"/><ellipse cx="13" cy="28" rx="6" ry="8" fill="#E8A87C"/><ellipse cx="25" cy="16" rx="6" ry="9" fill="#E8A87C"/><ellipse cx="39" cy="16" rx="6" ry="9" fill="#E8A87C"/><ellipse cx="51" cy="28" rx="6" ry="8" fill="#E8A87C"/>',
	"gear": '<circle cx="32" cy="32" r="21" fill="none" stroke="#8E6240" stroke-width="9" stroke-dasharray="9.4 6.4"/><circle cx="32" cy="32" r="17" fill="#C28E5B" stroke="#8E6240" stroke-width="3"/><circle cx="32" cy="32" r="7" fill="#FFF6E0"/>',
	"flag": '<path d="M15 6v54" stroke="#8E6240" stroke-width="5" stroke-linecap="round"/><path d="M18 9h32l-9 13 9 13H18z" fill="#8DB580" stroke="#6F9A63" stroke-width="3" stroke-linejoin="round"/>',
	"factory": '<rect x="8" y="28" width="48" height="30" fill="#C28E5B" stroke="#8E6240" stroke-width="3"/><path d="M3 30L32 11l29 19z" fill="#B5532F"/><rect x="42" y="8" width="9" height="16" fill="#9A6A4A"/><rect x="26" y="40" width="13" height="18" fill="#8E6240"/><rect x="12" y="36" width="9" height="9" fill="#CFE6EC"/>',
	"hammer": '<g transform="rotate(40 32 32)"><rect x="28" y="20" width="8" height="42" rx="3" fill="#8E6240"/><rect x="12" y="8" width="40" height="16" rx="4" fill="#A6A6A0" stroke="#7A7A74" stroke-width="3"/></g>',
	"close": '<path d="M16 16L48 48M48 16L16 48" stroke="#FFF6E0" stroke-width="9" stroke-linecap="round"/>',
	"check": '<path d="M13 34L27 47L51 17" stroke="#FFF6E0" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
	"plus": '<path d="M32 11v42M11 32h42" stroke="#FFF6E0" stroke-width="9" stroke-linecap="round"/>',
	"lock": '<rect x="13" y="28" width="38" height="29" rx="7" fill="#9A9A94"/><path d="M21 29v-8a11 11 0 0122 0v8" fill="none" stroke="#9A9A94" stroke-width="7"/><circle cx="32" cy="43" r="4" fill="#FFF6E0"/>',
	"clock": '<circle cx="32" cy="32" r="25" fill="#FFF6E0" stroke="#8E6240" stroke-width="5"/><path d="M32 16v17l11 7" stroke="#8E6240" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
	"leaf": '<path d="M10 54C8 28 24 10 54 10 56 38 40 56 10 54z" fill="#8DB580" stroke="#6F9A63" stroke-width="3" stroke-linejoin="round"/><path d="M12 52C26 38 36 28 48 16" stroke="#FFF6E0" stroke-width="3" fill="none" stroke-linecap="round"/>',
	"move": '<path d="M32 6l9 11H35v12h12v-6l11 9-11 9v-6H35v12h6l-9 11-9-11h6V35H17v6L6 32l11-9v6h12V17h-6z" fill="#FFF6E0"/>',
	"coins_sell": '<circle cx="24" cy="38" r="17" fill="#F4C95D" stroke="#C99A2E" stroke-width="3"/><circle cx="40" cy="26" r="17" fill="#F4C95D" stroke="#C99A2E" stroke-width="3"/>',
	"camera": '<path d="M20 16l4-7h16l4 7z" fill="#8E6240" stroke="#8E6240" stroke-width="3" stroke-linejoin="round"/><rect x="4" y="16" width="56" height="38" rx="9" fill="#C28E5B" stroke="#8E6240" stroke-width="4"/><circle cx="30" cy="36" r="12" fill="#FFF6E0" stroke="#8E6240" stroke-width="3"/><circle cx="30" cy="36" r="6" fill="#8DB580"/><circle cx="49" cy="26" r="3" fill="#FFF6E0"/>',
}

static var _cache: Dictionary = {}


static func tex(icon_name: String, px: int = 64) -> Texture2D:
	var key := "%s_%d" % [icon_name, px]
	if _cache.has(key):
		return _cache[key]
	var body: String = SVG.get(icon_name, SVG["leaf"])
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">%s</svg>' % body
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px) / 64.0)
	if err != OK:
		img = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
