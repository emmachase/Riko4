varying vec4 color;
varying vec2 texCoord;

uniform sampler2D tex;

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
vec3 gaussian(in vec2 ncuv) {
    float b = blur / (1280.0 / 720.0);

    ncuv+= .5;

    vec3 col = texture2D(tex, vec2(ncuv.x - b/1280.0, ncuv.y - b/720.0) ).rgb * 0.077847;
    col += texture2D(tex, vec2(ncuv.x - b/1280.0, ncuv.y) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x - b/1280.0, ncuv.y + b/720.0) ).rgb * 0.077847;

    col += texture2D(tex, vec2(ncuv.x, ncuv.y - b/720.0) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x, ncuv.y) ).rgb * 0.195346;
    col += texture2D(tex, vec2(ncuv.x, ncuv.y + b/720.0) ).rgb * 0.123317;

    col += texture2D(tex, vec2(ncuv.x + b/1280.0, ncuv.y - b/720.0) ).rgb * 0.077847;
    col += texture2D(tex, vec2(ncuv.x + b/1280.0, ncuv.y) ).rgb * 0.123317;
    col += texture2D(tex, vec2(ncuv.x + b/1280.0, ncuv.y + b/720.0) ).rgb * 0.077847;

    return col;
}

void main(void)
{
    vec2 st = texCoord - vec2(.5);
    
    // Curvature/light
    float d = length(st*.5 * st*.5);

    vec2 cuv = st*d + st*.935;

    // Fudge aspect ratio

    // cuv.x *= 1280.0/720.0*.75;

    
    // CRT color blur

    vec3 color = gaussian(cuv);

    // Light

    float l = 1. - min(1., d*light);
    color *= l;


    // Scanlines

    float y = cuv.y;


    float showScanlines = 1.;

    float s = 1. - smoothstep(320., 1440., 720.) + 1.;
    float j = cos(y*720.*s)*.1; // values between .01 to .25 are ok.
    color = abs(showScanlines-1.)*color + showScanlines*(color - color*j);
    color *= 1. - ( .01 + ceil(mod( (st.x+.5)*1280., 3.) ) * (.995-1.01) )*showScanlines;


    // Border mask

        float m = max(0.0, 1. - 2.*max(abs(cuv.x), abs(cuv.y) ) );
        m = min(m*200., 1.);
        color *= m;


    // Color correction

    color = postEffects(color, st);


	gl_FragColor = vec4(max(vec3(.0), min(vec3(1.), color)), 1.);
}