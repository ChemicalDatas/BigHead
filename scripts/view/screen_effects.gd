class_name ScreenEffects
extends CanvasLayer
## Full-screen special effects (Catalog "effect" items), played with the
## middle mouse button in the full game. Each one is a shader on a rect that
## covers the window, driven by `progress` going from 0 to 1. Ripple, Swirl
## and Kaleidoscope bend what's already on screen (hint_screen_texture); the
## rest paint light over it. All of them work on the Compatibility renderer.
##
## Only one effect plays at a time: starting another ends the last one.

## Seconds each effect lasts.
const DURATION := {
	"shooting_stars": 5.0, "rainbow": 6.0, "ripple": 3.0, "swirl": 3.2,
	"aurora": 7.0, "snow": 7.0, "disco": 6.0, "kaleidoscope": 4.5,
}
## A colour washed over the screen under the effect (night sky, dark dance floor).
const TINT := {
	"shooting_stars": Color(0.04, 0.05, 0.16, 0.55),
	"aurora": Color(0.02, 0.06, 0.14, 0.55),
	"disco": Color(0.05, 0.02, 0.1, 0.5),
	"snow": Color(0.75, 0.82, 0.95, 0.18),
}

const _COMMON := """
shader_type canvas_item;
%s
uniform float progress = 0.0;
uniform float aspect = 1.7778;
uniform vec2 center = vec2(0.5);
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}
float envelope() { return smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.78, 1.0, progress)); }
"""

const _SHADERS := {
	"shooting_stars": ["render_mode blend_add;", """
void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 22; i++) {
		float fi = float(i);
		float t = (progress - hash(fi + 1.0) * 0.78) / 0.2;
		if (t < 0.0 || t > 1.0) continue;
		vec2 start = vec2(hash(fi + 7.0) * aspect * 1.3, hash(fi + 13.0) * 0.4 - 0.08);
		vec2 dir = normalize(vec2(-0.7 - hash(fi + 3.0) * 0.7, 0.55));
		vec2 head = start + dir * t * (0.7 + hash(fi + 5.0) * 0.5);
		float tail = 0.22 * (1.0 - abs(t * 2.0 - 1.0) * 0.5);
		vec2 d = p - head;
		float along = -dot(d, dir);
		float across = abs(dot(d, vec2(-dir.y, dir.x)));
		if (along > 0.0 && along < tail) {
			float k = along / tail;
			col += vec3(1.0, 0.93, 0.75) * smoothstep(mix(0.004, 0.0008, k), 0.0, across) * (1.0 - k) * 1.6;
		}
		col += vec3(1.0, 0.95, 0.85) * smoothstep(0.012, 0.0, length(d)) * (1.0 - t * 0.6);
	}
	COLOR = vec4(col * envelope(), 1.0);
}
"""],
	"rainbow": ["", """
void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec2 c = vec2(center.x * aspect, 1.25);
	float r = length(p - c);
	float band = (r - 0.78) / 0.3;
	float a = atan(p.y - c.y, p.x - c.x);
	float from_left = clamp((a + 3.14159) / 3.14159, 0.0, 1.0);
	float reveal = smoothstep(from_left, from_left + 0.04, progress * 2.2);
	float edge = smoothstep(0.0, 0.06, band) * (1.0 - smoothstep(0.94, 1.0, band));
	vec3 col = hsv((1.0 - clamp(band, 0.0, 1.0)) * 0.78, 0.72, 1.0);
	COLOR = vec4(col, edge * reveal * 0.6 * (1.0 - smoothstep(0.8, 1.0, progress)));
}
"""],
	"ripple": ["uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;", """
void fragment() {
	vec2 p = SCREEN_UV - center;
	p.x *= aspect;
	float d = length(p);
	float w = 0.0;
	for (int i = 0; i < 3; i++) {
		float k = d - (progress - float(i) * 0.12) * 1.8;
		w += sin(k * 45.0) * exp(-k * k * 70.0) * 0.028 * (1.0 - progress);
	}
	vec2 off = (d > 0.0001 ? p / d : vec2(0.0)) * w;
	off.x /= aspect;
	COLOR = texture(screen_tex, SCREEN_UV + off);
	COLOR.rgb += vec3(max(w, 0.0) * 6.0);
}
"""],
	"swirl": ["uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;", """
void fragment() {
	vec2 p = SCREEN_UV - center;
	p.x *= aspect;
	float d = length(p);
	float a = sin(progress * 3.14159) * 5.5 * pow(max(0.0, 1.0 - d / 0.65), 2.0);
	p = vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
	p.x /= aspect;
	COLOR = texture(screen_tex, center + p);
}
"""],
	"aurora": ["render_mode blend_add;", """
void fragment() {
	float x = UV.x * aspect;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float y0 = 0.3 + 0.09 * sin(x * 1.3 + TIME * 0.4 + fi * 2.0) + 0.05 * sin(x * 3.1 - TIME * 0.7 + fi);
		float h = 0.22 + 0.06 * fi;
		float curtain = smoothstep(y0 - h, y0, UV.y) * (1.0 - smoothstep(y0, y0 + 0.025, UV.y));
		float rays = 0.55 + 0.45 * sin(x * 38.0 + sin(x * 6.0 + TIME * 0.8) * 3.0 + fi * 10.0);
		vec3 tone = mix(vec3(0.15, 1.0, 0.55), vec3(0.65, 0.3, 1.0), fi / 2.0 + 0.2 * sin(x + TIME * 0.3));
		col += tone * curtain * rays * (0.75 - 0.18 * fi);
	}
	COLOR = vec4(col * envelope(), 1.0);
}
"""],
	"snow": ["", """
void fragment() {
	float a = 0.0;
	for (int l = 0; l < 3; l++) {
		float fl = float(l);
		float scale = 9.0 + fl * 8.0;
		vec2 p = vec2(UV.x * aspect, UV.y) * scale;
		p.y -= TIME * (0.9 - fl * 0.2) * scale * 0.12;
		p.x += sin(TIME * 0.9 + p.y * 0.35 + fl * 2.0) * 0.35;
		vec2 cell = floor(p);
		if (hash2(cell + fl * 17.0) < 0.45) continue;
		vec2 jitter = vec2(hash2(cell + 3.1), hash2(cell + 9.7)) - 0.5;
		float d = length(fract(p) - 0.5 - jitter * 0.6);
		float r = 0.11 - fl * 0.025;
		a += smoothstep(r, r * 0.4, d) * (1.0 - fl * 0.22);
	}
	COLOR = vec4(1.0, 1.0, 1.0, clamp(a, 0.0, 1.0) * envelope());
}
"""],
	"disco": ["render_mode blend_add;", """
void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float ang = TIME * (0.8 + 0.15 * fi) + fi * 1.047;
		vec2 spot = vec2(aspect * 0.5 + cos(ang) * aspect * 0.33, 0.55 + sin(ang * 1.3) * 0.3);
		col += hsv(fi / 6.0 + TIME * 0.1, 0.85, 1.0) * smoothstep(0.24, 0.0, length(p - spot)) * 0.55;
	}
	vec2 cell = floor(p * 40.0);
	float twinkle = step(0.985, hash2(cell + floor(TIME * 7.0)));
	col += vec3(twinkle) * smoothstep(0.35, 0.0, length(fract(p * 40.0) - 0.5));
	COLOR = vec4(col * envelope(), 1.0);
}
"""],
	"kaleidoscope": ["uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;", """
void fragment() {
	vec2 p = SCREEN_UV - center;
	p.x *= aspect;
	float r = length(p);
	float a = atan(p.y, p.x) + progress * 1.6;
	float seg = 6.28318 / 6.0;
	a = abs(mod(a, seg) - seg * 0.5) - 1.5708 - seg * 0.25;  // fold the wedge above the click
	vec2 q = vec2(cos(a), sin(a)) * r * 0.85;
	q.x /= aspect;
	vec4 folded = texture(screen_tex, clamp(center + q, vec2(0.0), vec2(1.0)));
	COLOR = mix(texture(screen_tex, SCREEN_UV), folded, envelope());
}
"""],
}

static var _compiled := {}

var _current: Node = null


func _init() -> void:
	layer = 40


## Plays effect `id` ("effect/aurora" or just "aurora"), centred on `at`
## (a point in the window, for the ones that start somewhere).
func play(id: String, at: Vector2) -> void:
	var effect := id.get_slice("/", 1) if id.contains("/") else id
	if not _SHADERS.has(effect):
		push_warning("Unknown effect %s" % id)
		return
	if is_instance_valid(_current):
		_current.queue_free()
	var view := get_viewport().get_visible_rect().size
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_current = holder
	var seconds: float = DURATION[effect]
	if TINT.has(effect):
		var tint := ColorRect.new()
		tint.color = TINT[effect]
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.modulate.a = 0.0
		holder.add_child(tint)
		var fade := tint.create_tween()
		fade.tween_property(tint, "modulate:a", 1.0, seconds * 0.12)
		fade.tween_interval(seconds * 0.66)
		fade.tween_property(tint, "modulate:a", 0.0, seconds * 0.22)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader(effect)
	material.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))
	material.set_shader_parameter("center", Vector2(at.x / maxf(view.x, 1.0), at.y / maxf(view.y, 1.0)))
	material.set_shader_parameter("progress", 0.0)
	rect.material = material
	holder.add_child(rect)
	var tween := holder.create_tween()
	tween.tween_method(func(p: float) -> void: material.set_shader_parameter("progress", p), 0.0, 1.0, seconds)
	tween.tween_callback(holder.queue_free)
	print("[effects] %s" % effect)


## The compiled shader for an effect name (cached).
static func shader(effect: String) -> Shader:
	if not _compiled.has(effect):
		var parts: Array = _SHADERS[effect]
		var s := Shader.new()
		s.code = (_COMMON % parts[0]) + parts[1]
		_compiled[effect] = s
	return _compiled[effect]


static func names() -> Array:
	return _SHADERS.keys()
