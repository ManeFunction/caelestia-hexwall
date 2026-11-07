#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float cell;
    float lightMix; // 0 = dark theme, 1 = light theme
    vec2 res;
} ubuf;

// sin-free hash: three random values per hex in one go
vec3 hash3(vec2 id) {
    vec3 p3 = fract(vec3(id.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * ubuf.res / ubuf.cell - vec2(0.316, 0.0); // shifted right by about 0.3 of the grid spacing

    // hex lattice (flat-top hexes, neighbour spacing 1.0)
    const vec2 s = vec2(1.7320508, 1.0);
    vec4 hC = floor(vec4(p, p - vec2(1.0, 0.5)) / s.xyxy) + 0.5;
    vec4 h = vec4(p - hC.xy * s, p - (hC.zw + 0.5) * s);
    vec4 r = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hC.xy) : vec4(h.zw, hC.zw + 0.5);
    vec2 q = r.xy;
    vec2 id = r.zw;

    // distance from the hex edge, in pixels (0 on the edge, grows towards the centre)
    vec2 aq = abs(q);
    float e = (0.5 - max(dot(aq, vec2(0.8660254, 0.5)), aq.y)) * ubuf.cell;

    vec3 hh = hash3(id);
    float h1 = hh.x;

    // background and per-hex shade; a few hexes are nearly black
    float lm = ubuf.lightMix;
    vec3 top = mix(vec3(0.135, 0.135, 0.150), vec3(0.90, 0.90, 0.92), lm);
    vec3 bottom = mix(vec3(0.055, 0.055, 0.063), vec3(0.76, 0.76, 0.79), lm);
    vec3 col = mix(top, bottom, uv.y);
    col += (h1 - 0.5) * 0.035;
    if (h1 > 0.93) col *= mix(0.35, 0.68, lm);

    // grid lines
    float line = 1.0 - smoothstep(0.5, 1.6, e);
    col = mix(col, mix(vec3(0.26, 0.26, 0.29), vec3(0.55, 0.55, 0.60), lm), line * 0.75);

    // light running around the hex along its edges; each hex lights up in turns.
    // Only pixels near an edge of a currently lit hex pay for the angle and glow maths.
    if (e < 28.0) {
        float gate = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(ubuf.time * 0.35 + h1 * 25.0));
        if (gate > 0.02) {
            float dir = hh.y > 0.5 ? 1.0 : -1.0;
            float theta = ubuf.time * 1.1 * dir + hh.z * 6.2831853;
            float c = max(cos(atan(q.y, q.x) - theta), 0.0);
            float c2 = c * c;
            float g = c2 * c2 * c; // c^5
            float glow = g * gate * (exp2(-e * e * 0.48) + exp2(-e * 0.206) * 0.25);
            col += mix(vec3(0.82, 0.82, 0.88), vec3(-0.80, -0.80, -0.76), lm) * glow; // light on dark, dark on light
        }
    }

    // soft vignette
    col *= 1.0 - mix(0.3, 0.12, lm) * length(uv - 0.5);

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
