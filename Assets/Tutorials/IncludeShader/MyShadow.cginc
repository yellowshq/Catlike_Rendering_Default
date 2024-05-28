// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#if !defined(My_SHADOWS_INCLUDE)
#define My_SHADOWS_INCLUDE
#include "UnityCG.cginc"

#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	#if defined(_SEMITRANSPARENT_SHADOWS)
		#define SHADOWS_SEMITRANSPARENT 1
	#else
		#define _RENDERING_CUTOUT
	#endif
#endif
#if SHADOWS_SEMITRANSPARENT || defined(_RENDERING_CUTOUT)
	#if !defined(_SMOOTHNESS_ALBEDO)
		#define SHADOWS_NEED_UV 1
	#endif
#endif

UNITY_INSTANCING_BUFFER_START(TestColor_Instancing)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(TestColor_Instancing)
sampler2D _MainTex;
float4 _MainTex_ST;
float _AlphaCutoff;
sampler3D _DitherMaskLOD;

struct VertexData {
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

struct InterpolatorsVertex {
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 position : SV_POSITION;
#if SHADOWS_NEED_UV
	float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
	float3 lightVec : TEXCOORD1;
#endif
};

struct Interpolators {
	UNITY_VERTEX_INPUT_INSTANCE_ID
#if SHADOWS_SEMITRANSPARENT
	UNITY_VPOS_TYPE vpos : VPOS;
#else
	float4 positions : SV_POSITION;
#endif

#if SHADOWS_NEED_UV
	float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
	float3 lightVec : TEXCOORD1;
#endif
};

float GetAlpha(Interpolators i) {
	float alpha = UNITY_ACCESS_INSTANCED_PROP(TestColor_Instancing, _Color).a;
#if SHADOWS_NEED_UV
	alpha *= tex2D(_MainTex, i.uv.xy).a;
#endif
	return alpha;
}

InterpolatorsVertex MyShadowVertexProgram(VertexData v) {
	InterpolatorsVertex i;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, i);
#if defined(SHADOWS_CUBE)
	i.position = UnityObjectToClipPos(v.position);
	i.lightVec =
		mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
#else
	i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
	i.position = UnityApplyLinearShadowBias(i.position);
#endif
#if SHADOWS_NEED_UV
	i.uv = TRANSFORM_TEX(v.uv, _MainTex);
#endif
	return i;
}

	//float4 MyShadowVertexProgram(VertexData v) : SV_POSITION
	//{
	//	//float4 position = UnityObjectToClipPos(v.position);
	//	//应用法线偏差，灯光上的Normal Bias， 并将位置转换到ClipSpace
	//	float4 position = UnityClipSpaceShadowCasterPos(v.position, v.normal);
	//	//应用深度偏差, 灯光上的Bias
	//	position = UnityApplyLinearShadowBias(position);
	//	return position;
	//}

float4 MyShadowFragmentProgram (Interpolators i) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(i);
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif
	#if SHADOWS_SEMITRANSPARENT
	 	float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a;
		clip(dither - 0.01);
	#endif

	#if defined(SHADOWS_CUBE)
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;
		return UnityEncodeCubeShadowDepth(depth);
	#else
		return 0;
	#endif
}

#endif