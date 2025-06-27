#version 460
/** 
 * A coalesced decimation-in-time Stockham FFT kernel. 
 * Source: http://wwwa.pikara.ne.jp/okojisan/otfft-en/stockham3.html
 */

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
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/fft_compute.glsl
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

//__Defines__

layout(local_size_x = WAVE_RES, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 5) restrict readonly buffer ButterflyFactorBuffer {
	vec4 butterfly[]; // log2(WAVE_RES) x WAVE_RES
};

layout(std430, binding = 7) restrict buffer FFTBuffer {
	vec2 data[]; // WAVE_RES x WAVE_RES x NUM_SPECTRA x 2 * NUM_CASCADES
};

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
	CascadeParameters cascade;
};

shared vec2 row_shared[2 * WAVE_RES]; // "Ping-pong" shared buffer for a single row

/** Returns (a0 + j*a1)(b0 + j*b1) */
vec2 mul_complex(in vec2 a, in vec2 b) {
	return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x);
}

#define ROW_SHARED(col, pingpong) (row_shared[(pingpong)*WAVE_RES + (col)])
#define BUTTERFLY(col, stage)     (butterfly[(stage)*WAVE_RES + (col)])
#define DATA_IN(id, layer)  (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 +                             0 + (layer)*WAVE_RES*WAVE_RES + (id.y)*WAVE_RES + (id.x)])
#define DATA_OUT(id, layer) (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 + NUM_SPECTRA*WAVE_RES*WAVE_RES + (layer)*WAVE_RES*WAVE_RES + (id.y)*WAVE_RES + (id.x)])
void main() {
	const uint num_stages = findMSB(WAVE_RES); // Equivalent: log2(WAVE_RES) (assuming WAVE_RES is a power of 2)
	const uvec3 id = uvec3(gl_GlobalInvocationID.xy, uint(cascade.index)); // col, row, cascade
	const uint col = id.x;
	const uint spectrum = gl_GlobalInvocationID.z; // The spectrum in the buffer to perform FFT on.
	
	ROW_SHARED(col, 0) = DATA_IN(id, spectrum);
	for (uint stage = 0U; stage < num_stages; ++stage) {
		barrier();
		uvec2 buf_idx = uvec2(stage % 2, (stage + 1) % 2); // x=read index, y=write index
		vec4 butterfly_data = BUTTERFLY(col, stage);

		uvec2 read_indices = uvec2(floatBitsToUint(butterfly_data.xy));
		vec2 twiddle_factor = butterfly_data.zw;

		vec2 upper = ROW_SHARED(read_indices[0], buf_idx[0]);
		vec2 lower = ROW_SHARED(read_indices[1], buf_idx[0]);
		ROW_SHARED(col, buf_idx[1]) = upper + mul_complex(lower, twiddle_factor);
	}
	DATA_OUT(id, spectrum) = ROW_SHARED(col, num_stages % 2);
}