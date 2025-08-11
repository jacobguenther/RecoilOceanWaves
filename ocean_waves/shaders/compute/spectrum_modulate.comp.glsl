#version 460
/**
 * Modulates the JONSWAP wave spectra texture in time and calculates
 * its gradients. Since the outputs are all real-valued, they are packed
 * in pairs.
 *
 * Sources: Jerry Tessendorf - Simulating Ocean Water
 *          Robert Matusiak - Implementing Fast Fourier Transform Algorithms of Real-Valued Sequences With the TMS320 DSP Platform
 */

/*
Copyright (C) 2025 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
*/

/*
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/spectrum_modulate.glsl
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
12 June 2025: Jacob Guenther: Use storage buffer in place of push constants
*/

//__DEFINES__

layout(local_size_x = SPECTRUM_MODULTE_TILE_SIZE, local_size_y = SPECTRUM_MODULTE_TILE_SIZE, local_size_z = 1) in;

struct CascadeParameters {
	// vec2 scales; // x: displacement, y: normal
	float displacement_scale;
	float normal_scale;
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

layout(std430, binding = 6) restrict readonly buffer Cascade {
	CascadeParameters cascade;
};

uniform float time;

layout(std430, binding = 7) restrict writeonly buffer FFTBuffer {
	vec2 data[]; // WAVE_RES x WAVE_RES x num_spectra x 2 * num_cascades
};

layout(SPECTRUM_FORMAT_QUALIFIER, binding=SPECTRUM_BINDING) restrict readonly uniform image2DArray spectrum;

/** Returns exp(j*x) assuming x >= 0. */
vec2 exp_complex(in float x) {
	return vec2(cos(x), sin(x));
}

/** Returns (a0 + j*a1)(b0 + j*b1) */
vec2 mul_complex(in vec2 a, in vec2 b) {
	return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x);
}

/** Returns the complex conjugate of x */
vec2 conj_complex(in vec2 x) {
	x.y *= -1;
	return x;
}

// Jerry Tessendorf - Source: Simulating Ocean Water
float dispersion_relation(in float k, in float depth) {
	return sqrt(G*k*tanh(k*depth));
}

#define FFT_DATA(id, layer) (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 + (layer)*WAVE_RES*WAVE_RES + (id.y)*WAVE_RES + (id.x)])
void main() {
	const uint num_stages = findMSB(WAVE_RES); // Equivalent: log2(WAVE_RES) (assuming WAVE_RES is a power of 2)
	const ivec2 dims = imageSize(spectrum).xy;
	const ivec3 id = ivec3(gl_GlobalInvocationID.xy, int(cascade.index));

	vec2 k_vec = (id.xy - dims*0.5)*2.0*PI / cascade.tile_length; // Wave direction
	float k = length(k_vec) + 1e-6;
	vec2 k_unit = k_vec / k;

	// --- WAVE SPECTRUM MODULATION ---
	vec4 h0 = imageLoad(spectrum, id); // xy=h0(k), zw=conj(h0(-k))
	float dispersion = dispersion_relation(k, cascade.depth) * time;
	vec2 modulation = exp_complex(dispersion);
	// Note: h respects the complex conjugation property
	vec2 h = mul_complex(h0.xy, modulation) + mul_complex(h0.zw, conj_complex(modulation));
	vec2 h_inv = vec2(-h.y, h.x); // Used to simplify complex multiplication operations

	// --- WAVE DISPLACEMENT CALCULATION ---
	vec2 hx = h_inv * k_unit.y;            // Equivalent: mul_complex(vec2(0, -k_unit.x), h);
	vec2 hy = h;
	vec2 hz = h_inv * k_unit.x;            // Equivalent: mul_complex(vec2(0, -k_unit.z), h);

	// --- WAVE GRADIENT CALCULATION ---
	// FIXME: i dont understand why k vectors need to be accessed yx instead of xy :(
	vec2 dhy_dx = h_inv * k_vec.y;         // Equivalent: mul_complex(vec2(0, k_vec.x), h);
	vec2 dhy_dz = h_inv * k_vec.x;         // Equivalent: mul_complex(vec2(0, k_vec.z), h);
	vec2 dhx_dx = -h * k_vec.y * k_unit.y; // Equivalent: mul_complex(vec2(k_vec.x * k_unit.x, 0), -h);
	vec2 dhz_dz = -h * k_vec.x * k_unit.x; // Equivalent: mul_complex(vec2(k_vec.y * k_unit.y, 0), -h);
	vec2 dhz_dx = -h * k_vec.y * k_unit.x; // Equivalent: mul_complex(vec2(k_vec.x * k_unit.y, 0), -h);

	// Because h repsects the complex conjugation property (i.e., the output of IFFT will be a
	// real signal), we can pack two waves into one.
	FFT_DATA(id, 0) = vec2(    hx.x -     hy.y,     hx.y +     hy.x);
	FFT_DATA(id, 1) = vec2(    hz.x - dhy_dx.y,     hz.y + dhy_dx.x);
	FFT_DATA(id, 2) = vec2(dhy_dz.x - dhx_dx.y, dhy_dz.y + dhx_dx.x);
	FFT_DATA(id, 3) = vec2(dhz_dz.x - dhz_dx.y, dhz_dz.y + dhz_dx.x);
}
