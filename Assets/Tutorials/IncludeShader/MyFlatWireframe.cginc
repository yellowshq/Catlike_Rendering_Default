// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#if !defined(FLAT_WIREFRAME_INCLUDED)
#define FLAT_WIREFRAME_INCLUDED

#define CUSTOM_GEOMETRY_INTERPOLATORS \
	float2 barycentricCoordinates : TEXCOORD8;

#include "./MyLightingInput.cginc"

float3 _WireframeColor;
float _WireframeSmoothing;
float _WireframeThickness; //厚度

float3 GetAlbedoWithWirframe(Interpolators i) 
{
	float3 albedo = GetAlbedo(i);
	float3 barys;
	barys.xy = i.barycentricCoordinates;
	barys.z = 1 - barys.x - barys.y;
	//float minBary = min(barys.x, min(barys.y, barys.z));
	//albedo = barys;
	
	//minBary = smoothstep(0, 0.1, minBary);  //smoothstep 在0-0.1范围内插值， minBary< 0 则minBary=0, minBary > 0.1 则 minBary = 0.1
	//albedo *= minBary;

	//float delta = abs(ddx(minBary)) + abs(ddy(minBary));
	//float delta = fwidth(minBary);
	//delta = smoothstep(0, delta, minBary); //太细了
	//delta = smoothstep(delta, 2 * delta, minBary);	//有锯齿 应该使用重心坐标的的导数 如下

	float3 deltas = fwidth(barys);
	//barys = smoothstep(deltas, 2 * deltas, barys);
	float3 smoothing = deltas * _WireframeSmoothing;
	float3 thickness = deltas * _WireframeThickness;
	barys = smoothstep(thickness, thickness + smoothing, barys);

	float minBary = min(barys.x, min(barys.y, barys.z));

	//albedo *= minBary;
	return lerp(_WireframeColor, albedo, minBary);
}

#if !defined(ALBEDO_FUNCTION)
#define ALBEDO_FUNCTION GetAlbedoWithWirframe
#endif


#include "./MyLighting.cginc"

struct InterpolatorsGeometry {
	Interpolators data;
	//CUSTOM_GEOMETRY_INTERPOLATORS
};

[maxvertexcount(3)]
void MyGeometryProgram(triangle Interpolators i[3], inout TriangleStream<InterpolatorsGeometry> stream)
{
	float3 p0 = i[0].worldPos.xyz;
	float3 p1 = i[1].worldPos.xyz;
	float3 p2 = i[2].worldPos.xyz;

	float3 triangleNormal = normalize(cross(p1 - p0, p2 - p0));//顶点顺时针排列
	i[0].normal = triangleNormal;
	i[1].normal = triangleNormal;
	i[2].normal = triangleNormal;

	InterpolatorsGeometry g0, g1, g2;
	g0.data = i[0];
	g1.data = i[1];
	g2.data = i[2];
	g0.data.barycentricCoordinates = float2(1, 0);
	g1.data.barycentricCoordinates = float2(0, 1);
	g2.data.barycentricCoordinates = float2(0, 0);

	stream.Append(g0);
	stream.Append(g1);
	stream.Append(g2);

	//stream.Append(i[0]);
	//stream.Append(i[1]);
	//stream.Append(i[2]);
}

#endif