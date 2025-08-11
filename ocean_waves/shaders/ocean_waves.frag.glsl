#version 460
// File: ocean_waves.frag.glsl
// Author: chmod777
// License: GNU GPLv2 or later

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
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/spatial/water.gdshader
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

// From https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/modelmaterials_gl4/templates/cus_gl4.frag.glsl
// This shader is Copyright (c) 2025 Beherith (mysterme@gmail.com) and licensed under the MIT License

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

const float MIN_ROUGHNESS = 0.04;
const float DEFAULT_F0 = 0.02;

layout (std140, binding=15) uniform CascadeData {
	vec4 cascade_displacement_scale;
	vec4 cascade_normal_scale;
	vec4 cascade_length;
};

#ifdef DEBUG_COLOR_TEXTURE_DISPLACEMENT
	layout (binding=DISPLACEMENT_MAP_BINDING) uniform sampler2DArray displacement_map;
#endif

layout (binding=NORMAL_MAP_BINDING) uniform sampler2DArray normal_map;
layout (binding=DEPTH_MAP_BINDING) uniform sampler2DArray depth_map;

// layout (binding = 3) uniform sampler2D brdfLUT;
// layout (binding = 4) uniform sampler3D noisetex3dcube;
// layout (binding = 5) uniform sampler2D envLUT;

layout (location = 7) uniform vec4 water_color;      // rgb, water_alpha
layout (location = 8) uniform vec4 foam_color;       // rgb, foam_alpha
layout (location = 9) uniform vec4 subsurface_color; // rgb, roughness

in DataVS {
	vec4 uv_wave_height; // w unused
	vec4 world_vertex_position_distance;
	flat vec4 tile; // id, rotation, scale, layer
} IN;

out vec4 outColor;

/** Filter weights for a cubic B-spline. */
vec4 cubic_weights(float a) {
	float a2 = a*a;
	float a3 = a2*a;

	float w0 =-a3     + a2*3.0 - a*3.0 + 1.0;
	float w1 = a3*3.0 - a2*6.0         + 4.0;
	float w2 =-a3*3.0 + a2*3.0 + a*3.0 + 1.0;
	float w3 = a3;
	return vec4(w0, w1, w2, w3) / 6.0;
}

/** Performs bicubic B-spline filtering on the provided sampler. */
// Source: https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-20-fast-third-order-texture-filtering
vec4 texture_bicubic(in sampler2DArray sampler_2d_array, in vec3 uvw) {
	vec2 dims = vec2(textureSize(sampler_2d_array, 0).xy);
	vec2 dims_inv = 1.0 / dims;
	uvw.xy = uvw.xy*dims + 0.5;

	vec2 fuv = fract(uvw.xy);
	vec4 wx = cubic_weights(fuv.x);
	vec4 wy = cubic_weights(fuv.y);

	vec4 g = vec4(wx.xz + wx.yw, wy.xz + wy.yw);
	vec4 h = (vec4(wx.yw, wy.yw) / g + vec2(-1.5, 0.5).xyxy + floor(uvw.xy).xxyy)*dims_inv.xxyy;
	vec2 w = g.xz / (g.xz + g.yw);
	return mix(
		mix(texture(sampler_2d_array, vec3(h.yw, uvw.z)), texture(sampler_2d_array, vec3(h.xw, uvw.z)), w.x),
		mix(texture(sampler_2d_array, vec3(h.yz, uvw.z)), texture(sampler_2d_array, vec3(h.xz, uvw.z)), w.x), w.y);
}
float smith_masking_shadowing(in float cos_theta, in float alpha) {
	float a = cos_theta / (alpha * sqrt(1.0 - cos_theta*cos_theta)); // Approximate: 1.0 / (alpha * tan(acos(cos_theta)))
	float a_sq = a*a;
	return a < 1.6 ? (1.0 - 1.259*a + 0.396*a_sq) / (3.535*a + 2.181*a_sq) : 0.0;
}
float ocean_waves_fresnel(in float VdotN, in float roughness, in float reflectance) {
	return mix(
		pow(1.0 - VdotN, 5.0*exp(-2.69*roughness)) / (1.0 + 22.7*pow(roughness, 1.5)),
		1.0,
		reflectance
	);
}


// Fresnel - Schlick
// F term
vec3 FresnelSchlick(vec3 R0, vec3 R90, float VdotH) {
	return R0 + (R90 - R0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}
// Fresnel - Schlick with Roughness - LearnOpenGL
vec3 FresnelSchlickWithRoughness(vec3 R0, vec3 R90, float VdotH, float roughness) {
	return R0 + (max(R90 - vec3(roughness), R0) - R0) * pow(1.0 - VdotH, 5.0);
}
float VisibilityOcclusionFast(float NdotL, float NdotV, float roughness2) {
	float GGXV = NdotL * (NdotV * (1.0 - roughness2) + roughness2);
	float GGXL = NdotV * (NdotL * (1.0 - roughness2) + roughness2);

	float GGX = GGXV + GGXL;

	return mix(0.0, 0.5 / GGX, float(GGX > 0.0));
}
float MicrofacetDistribution(float NdotH, float roughness4) {
	float f = (NdotH * roughness4 - NdotH) * NdotH + 1.0;
	return roughness4 / (/*PI */ f * f);
}
float ComputeSpecularAOFilament(float NoV, float diffuseAO, float roughness2) {
	return clamp(pow(NoV + diffuseAO, exp2(-16.0 * roughness2 - 1.0)) - 1.0 + diffuseAO, 0.0, 1.0);
	// return diffuseAO;
}


void main() {
	if (IN.uv_wave_height.x > float(mapSize.x) || IN.uv_wave_height.y > float(mapSize.y)
		|| IN.uv_wave_height.x < 0.0 || IN.uv_wave_height.y < 0.0)
	{
		discard;
	}

	const vec3 v = cameraViewInv[3].xyz - IN.world_vertex_position_distance.xyz;

	// Read foam and normal information from normal maps.
	vec3 gradient = vec3(0.0);
	for (uint i = 0U; i < NUM_CASCADES; ++i) {
		const float uv_scale = 1.0 / cascade_length[i];
		const vec3 coords = vec3(IN.uv_wave_height.xy*uv_scale, float(i));
		const vec3 normal_scale = vec3(vec2(cascade_normal_scale[i]), 1.0);
		#ifdef TEXTURE_FILTERING_BILINEAR
			const vec4 bilinear = texture(normal_map, coords);
			gradient += bilinear.xyw * normal_scale;
		#endif
		#ifdef TEXTURE_FILTERING_BICUBIC
			const vec4 bicubic = texture_bicubic(normal_map, coords);
			gradient += bicubic.xyw * normal_scale;
		#endif
		#ifdef TEXTURE_FILTERING_DEFAULT
			const vec4 bilinear = texture(normal_map, coords);
			const vec4 bicubic = texture_bicubic(normal_map, coords);
			// Pixels per meter
			const float ppm = WAVE_RES * 0.1 * uv_scale;
			// Mix between bicubic and bilinear filtering depending on the world space pixels per meter.
			// This is dependent on the tile size as well as displacement/normal map resolution.
			gradient += mix(bicubic, bilinear, min(1.0, ppm)).xyw * normal_scale;
		#endif
	}

	const float foam_factor = min(
		smoothstep(0.0, 1.0, gradient.z),
		1.0 - smoothstep(FOAM_FALLOFF_START, FOAM_FALLOFF_END, IN.world_vertex_position_distance.w)
	);

	const vec3 albedo = mix(water_color.rgb, foam_color.rgb, foam_factor);

	const float roughness = clamp(subsurface_color.a, 0.2, 1.0);
	const float ao_term = 1.0;

	const float roughness2 = roughness * roughness;
	const float roughness4 = roughness2 * roughness2;

	const vec3 F0 = vec3(DEFAULT_F0) * albedo;
	const float reflectance = max(F0.r, max(F0.g, F0.b));
	const vec3 F90 = vec3(clamp(reflectance * 50.0, 1.0, 1.0));

	const vec3 N = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	// L - worldLightDir
	const vec3 L = normalize(sunDir.xyz); //from fragment to light, world space
	// V - worldCameraDir
	const vec3 V = normalize(v);
	// H - worldHalfVec
	const vec3 H = normalize(L + V); //half vector
	// R - reflection of worldCameraDir against worldFragNormal
	const vec3 Rv = -reflect(V, N);

	// dot products
	const float NdotL = clamp(dot(N, L), 1e-5, 1.0);
	const float NdotH = clamp(dot(H, N), 1e-5, 1.0);
	const float NdotV = clamp(dot(N, V), 1e-5, 1.0);
	const float VdotH = clamp(dot(V, H), 1e-5, 1.0);

	// TODO fix subsurface scattering
	// float VdotN = clamp(dot(V, N), 0.0, 1.0);
	// float LdotnV = clamp(dot(L, -V), 0.0, 1.0);
	// float LdotN = clamp(dot(L, N), 0.0, 1.0);
	// float fresnel = 0.7;//ocean_waves_fresnel(VdotN, roughness, reflectance);
	// float light_mask = smith_masking_shadowing(roughness, NdotV);
	// float view_mask = smith_masking_shadowing(roughness, NdotL);
	// const vec3 sss_modifier = subsurface_color.rgb; // vec3(0.9,1.15,0.85); // Subsurface scattering produces a 'greener' color.
	// float sss_height = 1.0*max(0.0, IN.uv_wave_height.z - 2.5) * pow(LdotnV, 4.0) * pow(0.5 - 0.5 * LdotN, 3.0);
	// float sss_near = 0.5*pow(NdotV, 2.0);
	// float lambertian = 0.5*NdotL;
	// vec3 sss_light = mix(
	// 	(sss_height + sss_near) * sss_modifier / (1.0 + light_mask) + lambertian,
	// 	foam_color.rgb,
	// 	foam_factor
	// ) * (1.0 - fresnel) * sunDiffuseModel.rgb;
	// diffuse += sss_light;

	const vec2 envBRDF = vec2(0.0);// textureLod(brdfLUT, vec2(NdotV, roughness), 0.0).rg;

	const vec3 energyCompensation =  clamp(1.0 + F0 * (1.0 / max(envBRDF.x, 1e-5) - 1.0), vec3(1.0), vec3(2.0));

	vec3 dirContrib = vec3(0.0);
	vec3 outSpecularColor = vec3(0.0);
	{
		const vec3 F = FresnelSchlick(F0, F90, VdotH);
		const float Vis = VisibilityOcclusionFast(NdotL, NdotV, roughness2);
		const float D = MicrofacetDistribution(NdotH, roughness4);

		// float geometric_attenuation = Vis * 1.0 / (1.0 + light_mask + view_mask);

		outSpecularColor = F * Vis * D /* * PI */;

		const float shadowMult = 1.0;
		vec3 maxSun = mix(sunSpecularModel.rgb, sunDiffuseModel.rgb, step(dot(sunSpecularModel.rgb, LUMA), dot(sunDiffuseModel.rgb, LUMA)));

		#ifdef SUNMULT
			maxSun *= SUNMULT;
		#endif

		outSpecularColor *= maxSun;
		outSpecularColor *= NdotL * shadowMult;

		// Scale the specular lobe to account for multiscattering
		// https://google.github.io/filament/Filament.md.html#toc4.7.2
		outSpecularColor *= energyCompensation;

		// kS is equal to Fresnel
		//vec3 kS = F;

		// for energy conservation, the diffuse and specular light can't
		// be above 1.0 (unless the surface emits light); to preserve this
		// relationship the diffuse component (kD) should equal 1.0 - kS.
		const vec3 kD = vec3(1.0) - F;

		// multiply kD by the inverse metalness such that only non-metals
		// have diffuse lighting, or a linear blend if partly metal (pure metals
		// have no diffuse light).
		// kD *= 1.0 - metalness;

		// add to outgoing radiance dirContrib
		dirContrib  = maxSun * (kD * albedo /* PI */) * NdotL * shadowMult;
		dirContrib += outSpecularColor;
	}

	// getSpecularDominantDirection (Filament)
	// Rv = mix(Rv, N, roughness4);

	vec3 ambientContrib;
	vec3 iblDiffuse = vec3(0.0);
	vec3 iblSpecular = vec3(0.0);
	vec3 specular = vec3(0.0);
	{
		// ambient lighting (we now use IBL as the ambient term)
		const vec3 F = FresnelSchlickWithRoughness(F0, F90, VdotH, roughness);

		//vec3 kS = F;
		const vec3 kD = 1.0 - F;
		// kD *= 1.0 - metalness;

		iblDiffuse = sunAmbientModel.rgb;

		const vec3 diffuse = iblDiffuse * albedo * ao_term;

		vec3 reflectionColor = vec3(0.0);
		reflectionColor = mix(reflectionColor, iblSpecular, roughness);

		const float aoTermSpec = ComputeSpecularAOFilament(NdotV, ao_term, roughness2);
		specular = reflectionColor * (F0 * envBRDF.x + F90 * envBRDF.y);
		specular *= aoTermSpec * energyCompensation;

		ambientContrib = (kD * diffuse + specular);
	}
	float alpha =
		(1.0-foam_factor) * water_color.a +
		foam_factor * foam_color.a;
	vec3 color = ambientContrib.xyz + dirContrib.xyz;
	// color *= 2.0; // hacks

	#ifdef DEBUG_COLOR_CLIPMAP
		uint ulayer = uint(IN.tile.w);
		if (ulayer == 0) {
			color = vec3(1.0, 0.0, 0.0);
		} else if (ulayer % 3 == 1) {
			color = vec3(0.0, 1.0, 0.0);
		} else if (ulayer % 3 == 2) {
			color = vec3(0.0, 0.0, 1.0);
		} else {
			color = vec3(1.0, 0.0, 1.0);
		}
	#endif

	#ifdef DEBUG_COLOR_TILE_ID
		color = vec3(IN.tile.x / 15.0);
		alpha = 1.0;
	#endif

	#ifdef DEBUG_COLOR_TEXTURE_DISPLACEMENT
		const vec2 uv_scale = vec2(1.0 / cascade_length[DEBUG_COLOR_TEXTURE_DISPLACEMENT]);
		const vec3 coords = vec3(IN.uv_wave_height.xy*uv_scale, float(DEBUG_COLOR_TEXTURE_DISPLACEMENT));
		color = texture(displacement_map, coords).xyz;
		alpha = 1.0;
	#endif

	#ifdef DEBUG_COLOR_TEXTURE_NORMAL
		const vec2 uv_scale = vec2(1.0 / cascade_length[DEBUG_COLOR_TEXTURE_NORMAL]);
		const vec3 coords = vec3(IN.uv_wave_height.xy*uv_scale, float(DEBUG_COLOR_TEXTURE_NORMAL));
		color = texture(normal_map, coords).xyz;
		alpha = 1.0;
	#endif

	#ifdef DEBUG_COLOR_TEXTURE_DEPTH
		color = vec3(texture(depth_map, vec3(IN.world_vertex_position_distance.xz/mapSize.xy, 0.0)).x, 0.0, 0.0);
		alpha = 1.0;
	#endif

	outColor = vec4(color, alpha);
}
