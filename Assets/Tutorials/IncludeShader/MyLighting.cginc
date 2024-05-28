// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(MY_LIGHTING_INCLUDE)
#define MY_LIGHTING_INCLUDE
#include "./MyLightingInput.cginc"

#if !defined(ALBEDO_FUNCTION)
    #define ALBEDO_FUNCTION GetAlbedo
#endif

void ComputeVertexLightColor(inout Interpolators i)
{
#if defined(VERTEXLIGHT_ON)
 /*   float3 lightPos = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
    float3 lightVec = lightPos - i.worldPos.xyz;
    float3 lightDir = normalize(lightVec);
    float ndotl = DotClamped(i.normal, lightDir);
    float attenuation = 1 / (1 + dot(lightVec, lightVec) * unity_4LightAtten0.x);
    i.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuation;*/
    //i.vertexLightColor = unity_LightColor[0].rgb;

    i.vertexLightColor = Shade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb,
        unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, i.worldPos.xyz, i.normal
    );
#endif 
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    float3 binormal = cross(normal, tangent) * (binormalSign * unity_WorldTransformParams.w);
    return binormal;
}


UnityLight CreateLight(Interpolators i)
{
    UnityLight light;

#if defined(DEFERRED_PASS)
    light.dir = float3(0, 1, 0);
    light.color = 0;
#else
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
    #else 
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
        //float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;
        //float attenuation = 1 / (1 + dot(lightVec, lightVec));
    //#if defined(SHADOWS_SCREEN)
    //    //float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy/i.shadowCoordinates.w);
    //    float attenuation = SHADOW_ATTENUATION(i);
    //#else
    //    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos.xyz)
    //#endif
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz)
    //方向光应该直接照亮遮挡区域，因此只需要间接光遮挡
    //但是为了是美术更好的控制灯光，通常直接光被遮挡
    //SSAO(屏幕空间的环境光遮挡)，是一种用于增强场景深度感的后处理技术，渲染了所有灯光之后将其应用，效果也不真实。
    //attenuation *= GetOcclusion(i); 
    light.color = _LightColor0.rgb * attenuation;
#endif
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax) 
{
#if UNITY_SPECCUBE_BOX_PROJECTION
    //使用盒投影
    UNITY_BRANCH//先执行分支计算 如果为ture，则后续仅执行true对应的那一段代码
    if (cubemapPosition.w > 0.0) {
        float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
        float scalar = min(min(factors.x, factors.y), factors.z);
        return direction * scalar + (position - cubemapPosition);
    }
#endif
    return direction;
}

UnityIndirect CreateUnityIndirect(Interpolators i, float3 viewDir)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = float3(0, 0, 0);  //环境光颜色
    indirectLight.specular = float3(0, 0, 0); //环境光镜面反射

#if defined(VERTEXLIGHT_ON)
    indirectLight.diffuse = i.vertexLightColor;
#endif 

#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
    float3 shColor = ShadeSH9(float4(i.normal, 1));
#if defined(LIGHTMAP_ON)
    //indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));

#if defined(DIRLIGHTMAP_COMBINED)
    float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(
        unity_LightmapInd, unity_Lightmap, i.lightmapUV
    );
#endif
    indirectLight.diffuse = DecodeDirectionalLightmap(
        indirectLight.diffuse, lightmapDirection, i.normal
    );
#else
    indirectLight.diffuse += max(0, shColor);
#endif

    //立方体贴图包含HDR(高动态范围)颜色，使其包含大于1的值，需要通过DecodeHDR将其转换为RGBM 
    //float4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, i.normal);//应该使用视角方向的反射方向
    float3 reflectionDir = reflect(-viewDir, i.normal);
    ////根据粗糙度进行Mipmap的选择, 越粗糙级别越高
    //float roughness = 1 - _Smoothness;
    //float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
    //indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);

    Unity_GlossyEnvironmentData envData;
    envData.roughness = 1 - GetSmoothness(i);
    envData.reflUVW = BoxProjection(
        reflectionDir, i.worldPos.xyz,
        unity_SpecCube0_ProbePosition,
        unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
    );

    float3 probe0 = Unity_GlossyEnvironment(
        UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
    );


#if UNITY_SPECCUBE_BLENDING
    //探针混合
    float interpolator = unity_SpecCube0_BoxMin.w;
    UNITY_BRANCH
    if (interpolator < 0.99999) //插值优化
    {
        envData.reflUVW = BoxProjection(
            reflectionDir, i.worldPos.xyz,
            unity_SpecCube1_ProbePosition,
            unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
        );
        float3 probe1 = Unity_GlossyEnvironment(
            UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube1_HDR, envData
        );
        indirectLight.specular = lerp(probe1, probe0, interpolator);
    }
    indirectLight.specular = probe0;
#else
    //indirectLight.specular = probe0;
#endif
    indirectLight.specular = probe0;
    //indirectLight.specular = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);

    float occlusion = GetOcclusion(i);
    indirectLight.diffuse *= occlusion;
    indirectLight.specular *= occlusion;

#if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
    indirectLight.specular = 0;
#endif
#endif

    return indirectLight;
}

//高度图每次都需计算，比较浪费，是否可以将法线直接存储在纹理中=>法线贴图
//void InitializeFragmentNormal_HeightMap(inout Interpolators i) 
//{
//    //* 0.5 和 -du为有限差法， 稍微改凹凸，但这更好的于高度场对齐
//    float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
//    float u1 = tex2D(_HeightMap, i.uv - du);
//    float u2 = tex2D(_HeightMap, i.uv + du);
//    float3 tu = float3(1, u2 - u1, 0);
//
//    float2 dv = float2(0, _HeightMap_TexelSize.y * 0.5);
//    float v1 = tex2D(_HeightMap, i.uv - dv);
//    float v2 = tex2D(_HeightMap, i.uv + dv);
//    float3 tv = float3(0, v2 - v1, 1);
//
//    //i.normal = float3(1, (h2 - h1)/du.x, 0);
//    //i.normal = float3(du.x, h2 - h1, 0);
//    //i.normal = float3(1, h2 - h1, 0); //缩放高度
//    //i.normal = float3(h1 - h2, 1, 0); //绕Z轴旋转90度
//
//    i.normal = float3(u1 - u2, 1, v1 - v2); //i.normal = cross(tv, tu);
//
//    i.normal = normalize(i.normal);
//}

float3 GetTangentSpaceNormal(Interpolators i) {
    //为了将法线存储到0-1的范围，需对法线进行处理(N+1)/2, 所以
    //为何法线贴图是浅蓝色的, 将向上的方向存储在z分量中, 从unity中角度看则是y分量， 所以需要将其调换。
    //i.normal = tex2D(_NormalMap, i.uv).xyz * 2 - 1;
    //i.normal = i.normal.xzy;


    //解码DXT5nm 法线贴图
    //i.normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1;
    //i.normal.xy *= _BumpScale;
    //i.normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));

#if defined(_NORMAL_MAP)
    float3 normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
#else 
    float3 normal = float3(0, 0, 1);
#endif

#if defined(_DETAIL_NORMAL_MAP)
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
    normal = BlendNormals(normal, detailNormal);
#endif

    //i.normal = (mainNormal + detailNormal) * 0.5; //单纯相加效果并不是很好，应该是高度场相加

    //高度场方法很好，但是当很陡峭的时候会失去一些细节
    //i.normal = (mainNormal.xy / mainNormal.z + detailNormal.xy / detailNormal.z, 1);  

    //泛白混合
    //i.normal = float3(mainNormal.xy + detailNormal.xy, mainNormal.z * detailNormal.z);
    //i.normal = BlendNormals(mainNormal, detailNormal);
    //i.normal = i.normal.xzy;

    //float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
    //i.tangent.w 创建具有双边对称性的3D模型（例如人和动物）时，一种常见的技术是左右镜像网格。这意味着你只需要编辑网格的一侧
    //unity_WorldTransformParams.w 当缩放为(-1,1,1) 为镜像时
    return normal;
}

void InitializeFragmentNormal(inout Interpolators i)
{
    //float3 dpdx = ddx(i.worldPos);
    //float3 dpdy = ddy(i.worldPos);
    //i.normal = normalize(cross(dpdy, dpdx)); //flatwireframe

    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
#if defined(BINORMAL_PER_FRAGMENT)
    float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w); //cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
#else
    float3 binormal = i.binormal;
#endif
    //切线空间 TBN
    i.normal = (tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal); //注意z y坐标
    i.normal = normalize(i.normal);
}

float4 ApplyFog(float4 color, Interpolators i) 
{
#if FOG_ON
    float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
#if FOG_DEPTH
    viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
#endif
    UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
    float3 fogColor = 0;//在附加灯光通道下，始终保持黑色
#if defined(FORWARD_BASE_PASS)
    fogColor.rbg = unity_FogColor.rgb;
#endif
    color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
#endif
    return color;
}

struct FragmentOutput
{
#if defined(DEFERRED_PASS)
    float4 gBuffer0 : SV_Target0;
    float4 gBuffer1 : SV_Target1;
    float4 gBuffer2 : SV_Target2;
    float4 gBuffer3 : SV_Target3;
#else
    float4 color : SV_Target;
#endif
};

void ApplyParallax(inout Interpolators i) 
{
#if defined(_PARALLAX_MAP)
    i.tangentViewDir = normalize(i.tangentViewDir);
    i.tangentViewDir.xy /= (i.tangentViewDir.z+0.42);
    float height = tex2D(_ParallaxMap, i.uv.xy).g;
    height -= 0.5;
    height *= _ParallaxStrength;
    float2 uvOffset = i.tangentViewDir.xy * height;
    i.uv.xy += uvOffset;
    i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy) ;
#endif
}

Interpolators MyVertexProgram(VertexData v)
{
    Interpolators i;
    UNITY_INITIALIZE_OUTPUT(Interpolators, i);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, i);
    i.pos = UnityObjectToClipPos(v.vertex);
    i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
#if FOG_DEPTH
    i.worldPos.w = i.pos.z;
#endif
    i.normal = UnityObjectToWorldNormal(v.normal);
#if defined(BINORMAL_PER_FRAGMENT)
    i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
#else
    i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
    i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
#endif
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
#if defined(LIGHTMAP_ON)
    //i.lightmapUV = TRANSFORM_TEX(v.uv1, unity_Lightmap);//不能使用TRANSFORM_TEX 因为没有unity_Lightmap_ST 实际上是unity_LightmapST
    i.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
#endif
#if defined(SHADOWS_SCREEN)
    //裁剪空间[-1,1]需要转换为屏幕空间[0,1]中;
    //透视除法 /i.pos.w;插值影响除法,所以不能在顶点程序中处理,应该在片段程序中
    // 最好用一个例子说明。假设我们在XW坐标对（0，1）和（1，4）之间进行插值。无论我们如何执行，X / W都从0开始，到¼结束。但是在这些点之间的一半呢？
    //如果我们在插值之前进行除法，则最终将在0和¼之间的中间位置，即⅛。
    //如果我们在插值后进行除法，则在中点处将得到坐标（0.5，2.5），这将导致除法0.5 / 2.5，即⅕，而不是⅛。因此，在这种情况下，插值不是线性的。
    //i.shadowCoordinates.xy = (i.pos.xy + i.pos.w) * 0.5;
    //i.shadowCoordinates.xy = (float2(i.pos.x, -i.pos.y) + i.pos.w) * 0.5; //Direct3D翻转y
    //i.shadowCoordinates.zw = i.pos.zw;
    //i.shadowCoordinates = ComputeScreenPos(i.pos);
    TRANSFER_SHADOW(i);
#endif

    //ComputeVertexLightColor报错 先值接把代码拷贝过来执行
#if defined(VERTEXLIGHT_ON)
    /*   float3 lightPos = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
       float3 lightVec = lightPos - i.worldPos.xyz;
       float3 lightDir = normalize(lightVec);
       float ndotl = DotClamped(i.normal, lightDir);
       float attenuation = 1 / (1 + dot(lightVec, lightVec) * unity_4LightAtten0.x);
       i.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuation;*/
       //i.vertexLightColor = unity_LightColor[0].rgb;

    i.vertexLightColor = Shade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb,
        unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, i.worldPos.xyz, i.normal
    );
#endif 

#if defined(_PARALLAX_MAP)
    float3x3 objectToTangent = float3x3(
            v.tangent.xyz,
            cross(v.normal, v.tangent.xyz) * v.tangent.w,
            v.normal
        );
    i.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
#endif
    return i;
}

FragmentOutput MyFragmentProgram(Interpolators i)
{
    UNITY_SETUP_INSTANCE_ID(i);
    ApplyParallax(i);
    //clip不是免费的，对台式机GPU来说不错，但是对切片渲染的移动GUP并不喜欢丢弃片元。
    float alpha = GetAlpha(i);
#if defined(_RENDERING_CUTOUT)
    clip(alpha - _Cutoff);
#endif
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
    //float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * UNITY_ACCESS_INSTANCED_PROP(_Color).rgb;
    //albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;

    float oneMinusReflectivity;

    float3 specularTint;
    float3 albedo = DiffuseAndSpecularFromMetallic(ALBEDO_FUNCTION(i), GetMetallic(i), specularTint, oneMinusReflectivity);
#if defined(_RENDERING_TRANSPARENT)
    albedo *= alpha;
    alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
#endif
    float4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, GetSmoothness(i), i.normal, viewDir, CreateLight(i), CreateUnityIndirect(i, viewDir));    //UnityPBSLighting.cginc
    color.rgb += GetEmission(i);
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
    color.a = alpha;
#endif

    FragmentOutput output;
#if defined(DEFERRED_PASS)
    #if !defined(UNITY_HDR_ON)
        color.rgb = exp2(-color.rgb);
    #endif
    output.gBuffer0.rgb = albedo;
    output.gBuffer0.a = GetOcclusion(i);
    output.gBuffer1.rgb = specularTint;
    output.gBuffer1.a = GetSmoothness(i);
    output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
    output.gBuffer3 = color;
#else
    output.color = ApplyFog(color, i);
#endif
    return output;
}
#endif