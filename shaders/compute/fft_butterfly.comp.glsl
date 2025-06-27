#version 460
/** Precomputes the butterfly factors for a Stockham FFT kernel */

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
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/fft_butterfly.glsl
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

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 5) restrict writeonly buffer ButterflyFactorBuffer {
	vec4 butterfly[]; // log2(WAVE_RES) x WAVE_RES
};

/** Returns exp(j*x) assuming x >= 0. */
vec2 exp_complex(in float x) {
	return vec2(cos(x), sin(x));
}

#define BUTTERFLY(col, stage) (butterfly[(stage)*map_size + (col)])
void main() {
	const uint map_size = gl_NumWorkGroups.x * gl_WorkGroupSize.x * 2;
	const uint col = gl_GlobalInvocationID.x;   // Column in row
	const uint stage = gl_GlobalInvocationID.y; // Stage of FFT

	uint stride = 1 << stage;
	uint mid = map_size >> (stage + 1);
	uint i = col >> stage, j = col % stride;

	vec2 twiddle_factor = exp_complex(PI / float(stride) * float(j));
	uint r0 = stride*(i +   0) + j, r1 = stride*(i + mid) + j;
	uint w0 = stride*(2*i + 0) + j, w1 = stride*(2*i + 1) + j;

	vec2 read_indices = vec2(uintBitsToFloat(r0), uintBitsToFloat(r1));

	BUTTERFLY(w0, stage) = vec4(read_indices,  twiddle_factor);
	BUTTERFLY(w1, stage) = vec4(read_indices, -twiddle_factor);
}