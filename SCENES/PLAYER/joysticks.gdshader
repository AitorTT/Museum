shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radius = 0.7; // relative to UV (0–0.5 works well)
uniform float edge_softness = 0.005; // smooth edges

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // remap UV from [-1,1]
    float dist = length(uv);  // distance from center

    // Smooth circle mask
    float alpha = smoothstep(radius, radius - edge_softness, dist);

    COLOR = vec4(circle_color.rgb, alpha * circle_color.a);
}
