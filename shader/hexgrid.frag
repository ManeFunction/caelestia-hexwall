#version 440
#if defined(QSHADER_GLSL) && QSHADER_GLSL_VERSION < 130
#define FLAT
#else
#define FLAT flat
#endif

layout(location = 0) in vec2 ax;
layout(location = 1) in vec2 vig;
layout(location = 2) in vec3 base;
layout(location = 3) FLAT in vec3 lineCol;
layout(location = 4) FLAT in vec3 glowCol;
layout(location = 5) FLAT in vec4 kc;
layout(location = 6) FLAT in vec3 kg;
layout(location = 7) FLAT in vec4 kd;
layout(location = 0) out vec4 fragColor;

// must match hexgrid.vert
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pulse;
    float spin;
    float cell;
    float lightMix;
    vec2 res;
    float dpr;
    float seed;
    float shift;
} ubuf;

void main() {
    // nearest hex centre: cube rounding of the axial coordinates (x = u, y = -u - v, z = v)
    vec3 cu = vec3(ax.x, -ax.x - ax.y, ax.y);
    vec3 rc = round(cu);
    vec3 d = abs(rc - cu);
    if (d.x > d.y && d.x > d.z) rc.x = -rc.y - rc.z;
    else if (d.y <= d.z) rc.z = -rc.x - rc.y;
    vec2 du = ax - rc.xz;
    vec2 q = vec2(0.8660254 * du.x, 0.5 * du.x + du.y); // offset from the centre, in cells
    vec2 id = vec2(0.5 * rc.x, rc.z + 0.5 * rc.x);      // hex id: centre / (sqrt(3), 1)

    // distance from the hex edge, in cells (0 on the edge, 0.5 in the centre)
    vec2 aq = abs(q);
    float w = 0.5 - max(dot(aq, vec2(0.8660254, 0.5)), aq.y);

    // sin-free hash, three random values per hex; only the first one is needed for every pixel.
    // The ids depend on the seed (see hexgrid.vert), which picks the pattern.
    vec3 p3 = fract(id.xyx * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    float h1 = fract((p3.x + p3.y) * p3.z);

    // background and per-hex shade; a few hexes are nearly black
    vec3 col = base + (h1 - 0.5) * 0.035;
    if (h1 > 0.93) col *= kc.x;

    // grid lines: 0.75 * (1 - smoothstep(0.5, 1.6, e))
    float t = clamp(w * kc.z - kc.w, 0.0, 1.0);
    col = mix(col, lineCol, 0.75 - t * t * (2.25 - 1.5 * t));

    // light running around the hex along its edges; each hex lights up in turns.
    // Only pixels of a currently lit hex pay for the direction, and only its lit half for the glow.
    float sn = sin(ubuf.pulse + h1 * 25.0);
    if (sn > -0.1991547 && w < kg.z) { // smoothstep(-0.3, 0.9, sn) > 0.02, away from the centre
        float g = clamp((sn + 0.3) * 0.8333333, 0.0, 1.0);
        float gate = g * g * (3.0 - 2.0 * g);
        float hy = fract((p3.x + p3.z) * p3.y);
        float hz = fract((p3.y + p3.z) * p3.x);
        float th = (hy > 0.5 ? ubuf.spin : -ubuf.spin) + hz * 6.2831853;
        float c = dot(q, vec2(cos(th), sin(th))); // cos(angle - th) * |q|
        if (c > 0.0) {
            c *= inversesqrt(dot(q, q));
            float c2 = c * c;
            float glow = c2 * c2 * c * gate * (exp2(-w * w * kg.x) + exp2(-w * kg.y) * 0.25);
            col += glowCol * glow;
        }
    }

    // soft vignette, then dither: a fixed per-pixel offset of under one 8-bit level mixes neighbouring levels, so
    // the dark gradients show no bands where they step from one level to the next. The pixel position comes from
    // vig, which is interpolated anyway (cheaper than gl_FragCoord).
    float n = fract(dot(vig, kd.xy));
    fragColor = vec4(col * (ubuf.qt_Opacity - kc.y * length(vig)) + (n * kd.z + kd.w), ubuf.qt_Opacity);
}
