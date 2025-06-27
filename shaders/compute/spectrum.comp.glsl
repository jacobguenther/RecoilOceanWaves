#version 460

/*
Copyright (C) 2025 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License version 3 as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
*/

/*
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/spectrum_compute.glsl
MIT License

Copyright (c) 2024 Ethan Truong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/* Change Log
11 June 2025: Jacob Guenther: Use storage buffer in place of push constants
*/

//__Defines__

layout(local_size_x = SPECTRUM_TILE_SIZE, local_size_y = SPECTRUM_TILE_SIZE, local_size_z = 1) in;

struct CascadeParameters {
	vec2 scales; // x: displacement, y: normal
	float tile_length;
	float alpha;
	float peak_frequency;
	float wind_speed;
	float angle;
	float depth;
	float swell;
	float detail;
	float spread;
	float time;
	float index;
	float whitecap;
	float foam_grow_rate;
	float foam_decay_rate;
	// 16 * sizeof(float)
};

layout(std430, binding=6) restrict readonly buffer Cascade {
	CascadeParameters cascades[NUM_CASCADES];
};

layout(SPECTRUM_FORMAT_QUALIFIER, binding=SPECTRUM_BINDING) restrict writeonly uniform image2DArray spectrum;

// --- HELPER FUNCTIONS ---
// Source: https://www.shadertoy.com/view/Xt3cDn
vec2 hash(in uvec2 x) {
	uint h32 = x.y + 374761393U + x.x*3266489917U;
	h32 = 2246822519U * (h32 ^ (h32 >> 15));
	h32 = 3266489917U * (h32 ^ (h32 >> 13));
	uint n = h32 ^ (h32 >> 16);
	uvec2 rz = uvec2(n, n*48271U);
	return vec2((rz.xy >> 1) & uvec2(0x7FFFFFFFU)) / float(0x7FFFFFFF);
}

/** Samples a 2D-bivariate normal distribution */
vec2 gaussian(in vec2 x) {
	// Use Box-Muller transform to convert uniform distribution->normal distribution.
	float r = sqrt(-2.0 * log(x.x));
	float theta = 2.0*PI * x.y;
	return vec2(r*cos(theta), r*sin(theta));
}

/** Returns the complex conjugate of x */
vec2 conj_complex(in vec2 x) {
	return vec2(x.x, -x.y);
}

// --- SPECTRUM-RELATED FUNCTIONS ---
// Source: Jerry Tessendorf - Simulating Ocean Water
vec2 dispersion_relation(in float k, in float depth) {
	float a = k*depth;
	float b = tanh(a);
	float dispersion_relation = sqrt(G*k*b);
	float d_dispersion_relation = 0.5*G * (b + a*(1.0 - b*b)) / dispersion_relation;

	// Return both the dispersion relation and its derivative w.r.t. k
	return vec2(dispersion_relation, d_dispersion_relation);
}

/** Normalization factor approximation for Longuet-Higgins function. */
float longuet_higgins_normalization(in float s) {
	// Note: i forgot how i derived this :skull:
	float a = sqrt(s);
	return (s < 0.4) ? (0.5/PI) + s*(0.220636+s*(-0.109+s*0.090)) : inversesqrt(PI)*(a*0.5 + (1.0/a)*0.0625);
}

// Source: Christopher J. Horvath - Empirical Directional Wave Spectra for Computer Graphics
float longuet_higgins_function(in float s, in float theta) {
	return longuet_higgins_normalization(s) * pow(abs(cos(theta*0.5)), 2.0*s);
}

// Source: Christopher J. Horvath - Empirical Directional Wave Spectra for Computer Graphics
float hasselmann_directional_spread(in float w, in float w_p, in float wind_speed, in float theta, in float swell, in float angle) {
	float p = w / w_p;
	float s = (w <= w_p) ? 6.97*pow(abs(p), 4.06) : 9.77*pow(abs(p), -2.33 - 1.45*(wind_speed*w_p/G - 1.17)); // Shaping parameter
	float s_xi = 16.0 * tanh(w_p / w) * swell*swell; // Shaping parameter w/ swell
	return longuet_higgins_function(s + s_xi, theta - angle);
}

// Source: Christopher J. Horvath - Empirical Directional Wave Spectra for Computer Graphics
float TMA_spectrum(in float w, in float w_p, in float alpha, in float depth) {
	const float beta = 1.25;
	const float gamma = 3.3; // Spectral peak shape constant
	
	float sigma = (w <= w_p) ? 0.07 : 0.09;
	float r = exp(-(w-w_p)*(w-w_p) / (2.0 * sigma*sigma * w_p*w_p));
	float jonswap_spectrum = (alpha * G*G) / pow(w, 5) * exp(-beta * pow(w_p/w, 4)) * pow(gamma, r);

	float w_h = min(w * sqrt(depth / G), 2.0);
	float kitaigorodskii_depth_attenuation = (w_h <= 1.0) ? 0.5*w_h*w_h : 1.0 - 0.5*(2.0-w_h)*(2.0-w_h);

	return jonswap_spectrum * kitaigorodskii_depth_attenuation;
}

vec2 get_spectrum_amplitude(in ivec2 id, in ivec2 dims, in CascadeParameters cascade) {
	float dk = 2.0*PI / cascade.tile_length;
	vec2 k_vec = (id - dims*0.5)*dk; // Wave direction
	float k = length(k_vec) + 1e-6;
	float theta = atan(k_vec.x, k_vec.y);

	vec2 dispersion = dispersion_relation(k, cascade.depth);
	float w = dispersion[0];
	float w_norm = dispersion[1] / k * dk*dk;
	float s = TMA_spectrum(
		w,
		cascade.peak_frequency,
		cascade.alpha,
		cascade.depth
	);
	float directional_spread = hasselmann_directional_spread(
		w,
		cascade.peak_frequency,
		cascade.wind_speed,
		theta,
		cascade.swell,
		cascade.angle
	);
	float d = mix(
		0.5/PI,
		directional_spread,
		1.0 - cascade.spread
	) * exp(-(1.0-cascade.detail)*(1.0-cascade.detail) * k*k);
	
	const ivec2 seed = ivec2(0, 0);
	return gaussian(hash(uvec2(id + seed))) * sqrt(2.0 * s * d * w_norm);
}

void main() {
	const uint cascade_index = gl_GlobalInvocationID.z;
	const ivec2 dims = ivec2(WAVE_RES);
	const ivec3 id = ivec3(gl_GlobalInvocationID.xy, cascade_index);
	const ivec2 id0 = id.xy;
	const ivec2 id1 = ivec2(mod(-id0, dims));

	CascadeParameters cascade = cascades[cascade_index];
	barrier();

	vec2 spectrum_amplitude = get_spectrum_amplitude(id0, dims, cascade);
	vec2 complex_conjugate = conj_complex(get_spectrum_amplitude(id1, dims, cascade));
	vec4 packed_data = vec4(spectrum_amplitude, complex_conjugate);
	imageStore(spectrum, id, packed_data);
}

