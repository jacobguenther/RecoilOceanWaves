#version 460
/** 
 * Unpacks the IFFT outputs from the modulation stage and creates
 * the output displacement and normal maps.
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
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/fft_unpack.glsl
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

layout(local_size_x = UNPACK_TILE_SIZE, local_size_y = UNPACK_TILE_SIZE, local_size_z = 2) in;

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

layout(std430, binding=7) restrict buffer FFTBuffer {
	vec2 data[]; // WAVE_RES x WAVE_RES x NUM_SPECTRA x 2 * NUM_CASCADES
};

layout(DISPLACEMENT_FORMAT_QUALIFIER, binding=DISPLACEMENT_MAP_BINDING) restrict writeonly uniform image2DArray displacement_map;
layout(NORMAL_FORMAT_QUALIFIER, binding=NORMAL_MAP_BINDING) restrict uniform image2DArray normal_map;

// Tiling doesn't provide much of a benefit here (but it does a *little*)
shared vec2 tile[NUM_SPECTRA][UNPACK_TILE_SIZE][UNPACK_TILE_SIZE];

// Note: There is an assumption that the FFT does not transpose a second time. Thus,
//       we access the FFT buffer at an offset of NUM_LAYERS*WAVE_RES*WAVE_RES
#define FFT_DATA(id, layer) (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 + NUM_SPECTRA*WAVE_RES*WAVE_RES + (layer)*WAVE_RES*WAVE_RES + (id).y*WAVE_RES + (id).x])
void main() {
	const uvec3 id_local = gl_LocalInvocationID;
	const ivec3 id = ivec3(gl_GlobalInvocationID.xy, int(cascade.index));
	// Multiplying output of inverse FFT by below factor is equivalent to ifftshift()
	const float sign_shift = float(-2*((id.x & 1) ^ (id.y & 1)) + 1); // Equivalent: (-1^id.x)(-1^id.y)

	tile[id_local.z*2][id_local.y][id_local.x] = FFT_DATA(id, id_local.z*2);
	tile[id_local.z*2 + 1][id_local.y][id_local.x] = FFT_DATA(id, id_local.z*2 + 1);
	barrier();

	// Half of all threads writes to displacement map while other half writes to normal map.
	switch (id_local.z) {
		case 0:
			float hx = tile[0][id_local.y][id_local.x].x;
			float hy = tile[0][id_local.y][id_local.x].y;
			float hz = tile[1][id_local.y][id_local.x].x;
			imageStore(displacement_map, id, vec4(hx, hy, hz, 0.0) * sign_shift);
			break;
		case 1:
			float dhy_dx = tile[1][id_local.y][id_local.x].y * sign_shift;
			float dhy_dz = tile[2][id_local.y][id_local.x].x * sign_shift;
			float dhx_dx = tile[2][id_local.y][id_local.x].y * sign_shift;
			float dhz_dz = tile[3][id_local.y][id_local.x].x * sign_shift;
			float dhz_dx = tile[3][id_local.y][id_local.x].y * sign_shift;
			vec2 gradient = vec2(dhy_dx, dhy_dz) / (1.0 + abs(vec2(dhx_dx, dhz_dz)));

			float jacobian = (1.0 + dhx_dx) * (1.0 + dhz_dz) - dhz_dx*dhz_dx;
			float foam_factor = -min(0.0, jacobian - cascade.whitecap);
			float foam = imageLoad(normal_map, id).a;
			foam *= exp(-cascade.foam_decay_rate);
			foam += foam_factor * cascade.foam_grow_rate;
			foam = clamp(foam, 0.0, 1.0);

			imageStore(normal_map, id, vec4(gradient, dhx_dx, foam));
			break;
	}
}