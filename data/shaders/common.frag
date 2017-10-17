// Adapted from https://www.shadertoy.com/view/XdyGzR
// Authored by @frutbunn, adapted by @Incinirate for usage in Riko4

varying vec4 color;
varying vec2 texCoord;

uniform sampler2D tex;
uniform vec2 resolution;
uniform bool crteffect;

const float gamma = 1.;
const float contrast = 1.;
const float saturation = 1.;
const float brightness = 1.;

const float light = 9.;
const float blur = 1.5;

vec3 postEffects(in vec3 rgb, in vec2 xy) {
    rgb = pow(rgb, vec3(gamma));
    rgb = mix(vec3(.5), mix(vec3(dot(vec3(.2125, .7154, .0721), rgb*brightness)), rgb*brightness, saturation), contrast);

    return rgb;
}

// Sigma 1. Size 3
vec3 gaussian(in vec2 ncuv, in vec2 rs) {
    float b = blur / (rs.x / rs.y);

    ncuv+= .5;

    vec3 col = texture2D(tex, vec2(ncuv.x - b/rs.x, ncuv.y - b/rs.y) ).rgb * 0.077847;
    col += texture2D(tex, vec2(ncuv.x - b/rs.x, ncuv.y) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x - b/rs.x, ncuv.y + b/rs.y) ).rgb * 0.077847;

    col += texture2D(tex, vec2(ncuv.x, ncuv.y - b/rs.y) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x, ncuv.y) ).rgb * 0.195346;
    col += texture2D(tex, vec2(ncuv.x, ncuv.y + b/rs.y) ).rgb * 0.123317;

    col += texture2D(tex, vec2(ncuv.x + b/rs.x, ncuv.y - b/rs.y) ).rgb * 0.077847;
    col += texture2D(tex, vec2(ncuv.x + b/rs.x, ncuv.y) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x + b/rs.x, ncuv.y + b/rs.y) ).rgb * 0.077847;

    return col;
}

void main(void)
{
    if (crteffect) {
        vec2 st = texCoord - vec2(.5);
        
        // Curvature/light
        float d = length(st*.5 * st*.5);

        vec2 cuv = st*d + st*.935;

        // Fudge aspect ratio

        // cuv.x *= resolution.x/resolution.y*.75;

        
        // CRT color blur

        vec3 color;
        if (resolution.y >= 720. && resolution.x >= 1280.)
            color = gaussian(cuv, resolution);
        else
            color = gaussian(cuv, vec2(1280., 720.));

        // Light

        float l = 1. - min(1., d*light);
        color *= l;


        // Scanlines

        float y = cuv.y;


        float showScanlines = 1.;
        if (resolution.y < 720.0) {
            showScanlines = 0.;
        }

        float s = 1. - smoothstep(320., 1440., resolution.y) + 1.;
        float j = cos(y*resolution.y*s)*.1; // values between .01 to .25 are ok.
        color = abs(showScanlines-1.)*color + showScanlines*(color - color*j);
        color *= 1. - ( .01 + ceil(mod( (st.x+.5)*resolution.x, 3.) ) * (.995-1.01) )*showScanlines;


        // Border mask

            float m = max(0.0, 1. - 2.*max(abs(cuv.x), abs(cuv.y) ) );
            m = min(m*200., 1.);
            color *= m;


        // Color correction

        color = postEffects(color, st);


        gl_FragColor = vec4(max(vec3(.0), min(vec3(1.), color)), 1.);
    } else {
        gl_FragColor = texture2D(tex, texCoord) * color;
    }
}