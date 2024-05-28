// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(MY_LIGHTING_INPUT_INCLUDE)
#define MY_LIGHTING_INPUT_INCLUDE
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    # define FOG_ON 1
#endif
UNITY_INSTANCING_BUFFER_START(TestColor_Instancing)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(TestColor_Instancing)
float _Cutoff;
sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;

//sampler2D _HeightMap;
/// <summary>
/// 纹理像素， 前两个分量纹理像素大小(u 和 v的分数表示)，后两个像素数量
/// 若_HeightMap为256*128， 则改值为(1/256, 1/128, 256, 128);
/// </summary>
//float4 _HeightMap_TexelSize;
sampler2D _NormalMap, _DetailNormalMap, _DetailMask;
float _BumpScale, _DetailBumpScale;

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _EmissionMap;
float3 _Emission;

sampler2D _ParallaxMap;
float _ParallaxStrength;

sampler2D _OcclusionMap;
float _OcclusionStrength;

struct VertexData
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
};

struct Interpolators
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
#if defined(BINORMAL_PER_FRAGMENT)
    float4 tangent : TEXCOORD2;
#else
    float3 tangent : TEXCOORD2;
    float3 binormal : TEXCOORD3;
#endif
#if FOG_DEPTH
    float4 worldPos : TEXCOORD4; //将深度赋予位置的第4个坐标
#else
    float3 worldPos : TEXCOORD4;
#endif
//
//#if defined(SHADOWS_SCREEN)
//    float4 shadowCoordinates : TECDOORD5;
//#endif
    SHADOW_COORDS(5)
#if defined(VERTEXLIGHT_ON)
    float3 vertexLightColor : TEXCOORD6;
#endif 
#if defined(LIGHTMAP_ON)
    float2 lightmapUV : TEXCOORD6;
#endif
#if defined(_PARALLAX_MAP)
    float3 tangentViewDir:TEXCOORD8;
#endif

#if defined(CUSTOM_GEOMETRY_INTERPOLATORS)
    CUSTOM_GEOMETRY_INTERPOLATORS
#endif
};


float GetMetallic(Interpolators i)
{
#if defined(_METALLIC_MAP)
    return tex2D(_MetallicMap, i.uv.xy).r;
#else
    return _Metallic;
#endif
}

float GetSmoothness(Interpolators i)
{
    float smoothness = 1;
#if defined(_SMOOTHNESS_ALBEDO)
    smoothness = tex2D(_MainTex, i.uv.xy).a;
#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
    smoothness = tex2D(_MetallicMap, i.uv.xy).a;
#endif
    return smoothness * _Smoothness;
}

float3 GetEmission(Interpolators i)
{
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
#if defined(_EMISSION_MAP)
    return tex2D(_EmissionMap, i.uv.xy) * _Emission;
#else
    return _Emission;
#endif
#else
    return 0;
#endif
}

float GetOcclusion(Interpolators i) {
#if defined(_OCCLUSION_MAP)
    //return tex2D(_OcclusionMap, i.uv.xy).g;
    return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
#else
    return 1;
#endif
}

float GetDetailMask(Interpolators i) {
#if defined(_DETIAL_MASK)
    return tex2D(_DetailMask, i.uv.xy).a;
#else
    return 1;
#endif
}

float3 GetAlbedo(Interpolators i) {
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * UNITY_ACCESS_INSTANCED_PROP(TestColor_Instancing, _Color).rgb;
#if defined(_DETAIL_ALBEDO_MAP)
    float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    albedo = lerp(albedo, albedo * details, GetDetailMask(i));
#endif
    return albedo;
}

float GetAlpha(Interpolators i) 
{
    float alpha = UNITY_ACCESS_INSTANCED_PROP(TestColor_Instancing, _Color).a;
#if !defined(_SMOOTHNESS_ALBEDO)    //在不使用alpha通道作为平滑度时
    return alpha * tex2D(_MainTex, i.uv.xy).a;
#endif 
    return alpha;
}

#endif