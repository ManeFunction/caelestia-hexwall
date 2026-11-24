#version 440
// Everything that is linear across the screen or only depends on the theme is computed here, for the 4 corners,
// instead of for every pixel. Built per target (qsb -p): GLSL 120 / ES 100 have no `flat`, a plain varying does
// the same there because the values are equal at all corners.
#if defined(QSHADER_GLSL) && QSHADER_GLSL_VERSION < 130
#define FLAT
#else
#define FLAT flat
#endif

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 ax;          // axial hex coordinates: p = ax.x * (sqrt(3)/2, 1/2) + ax.y * (0, 1)
layout(location = 1) out vec2 vig;         // uv - 0.5, for the vignette
layout(location = 2) out vec3 base;        // background gradient
layout(location = 3) FLAT out vec3 lineCol;
layout(location = 4) FLAT out vec3 glowCol;
layout(location = 5) FLAT out vec4 kc;     // dark-hex shade, vignette * opacity, line ramp scale and offset
layout(location = 6) FLAT out vec3 kg;     // glow falloff constants and its edge limit, in cell units

// must match hexgrid.frag
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pulse; // (0.35 * time) mod 2pi: hexes lighting up in turns
    float spin;  // (1.1 * time) mod 2pi: light running around the hex
    float cell;
    float lightMix; // 0 = dark theme, 1 = light theme
    vec2 res;
} ubuf;

void main() {
    vec2 uv = qt_MultiTexCoord0;
    float lm = ubuf.lightMix;
    float c = ubuf.cell;

    // hex lattice (flat-top hexes, neighbour spacing 1), shifted right by about 0.3 of the grid spacing
    vec2 p = uv * ubuf.res / c - vec2(0.316, 0.0);
    float u = p.x * 1.1547005;
    ax = vec2(u, p.y - 0.5 * u);
    vig = uv - 0.5;

    vec3 top = mix(vec3(0.135, 0.135, 0.150), vec3(0.90, 0.90, 0.92), lm);
    vec3 bottom = mix(vec3(0.055, 0.055, 0.063), vec3(0.76, 0.76, 0.79), lm);
    base = mix(top, bottom, uv.y);
    lineCol = mix(vec3(0.26, 0.26, 0.29), vec3(0.55, 0.55, 0.60), lm);
    glowCol = mix(vec3(0.82, 0.82, 0.88), vec3(-0.80, -0.80, -0.76), lm); // light on dark, dark on light

    // the fragment shader measures the edge distance w in cells; in pixels it is e = w * cell
    kc = vec4(mix(0.35, 0.68, lm), mix(0.3, 0.12, lm) * ubuf.qt_Opacity, c / 1.1, 0.5 / 1.1);
    kg = vec3(0.48 * c * c, 0.206 * c, 28.0 / c);

    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
