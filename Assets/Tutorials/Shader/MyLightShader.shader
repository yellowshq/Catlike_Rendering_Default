Shader "Custom/My Light Shader"
{
    Properties
    {
        _Color("Tint", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        //[NoScaleOffset] _HeightMap("Heights", 2D) = "gray" {}
        [NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.1
        _DetailTex("Detail Abledo", 2D) = "gray" {}
        [NoScaleOffset]_DetailNormalMap("Detail Normals", 2D) = "bump" {}
        [NoScaleOffset]_DetailMask("Detail Mask", 2D) = "white" {}

        _DetailBumpScale("Detail Bump Scale", Float) = 1
         [NoScaleOffset]_EmissionMap("Emission", 2D) = "black" {}
        _Emission("Emission", Color) = (0,0,0)
        [NoScaleOffset]_OcclusionMap("Occlusion", 2D) = "White" {}
        _OcclusionStrength("Occlusion Strength", Range(0,1)) = 1

        [HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
        [HideInInspector] _DstBlend ("_DestBlend", Float) = 0
        [HideInInspector] _ZWrite("_ZWrite", Float) = 1
    }
    SubShader
    {
        Pass
        {
            //前向渲染主方向灯
            Tags {"LightMode" = "ForwardBase"}
            Name "Custom_ForwardBase"

            //Blend SrcAlpha OneMinusSrcAlpha
            Blend [_SrcBlend] [_DstBlend]

            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0  
            //shader_feature和multi_compile的区别
            //multi_compile总是会包含在构建中
            //shader_feature只会在使用了该关键字时才包含
            //如果是运行时动态使用的关键字，则可以通过 shader variant collection asset收集变体
            #pragma shader_feature _ _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _ _EMISSION_MAP
            #pragma shader_feature _ _OCCLUSION_MAP
            #pragma shader_feature _ _DETIAL_MASK
            #pragma shader_feature _ _NORMAL_MAP
            #pragma shader_feature _ _DETAIL_ALBEDO_MAP
            #pragma shader_feature _ _DETAIL_NORMAL_MAP

            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

            #pragma multi_compile _ SHADOWS_SCREEN
            //#pragma multi_compile _ VERTEXLIGHT_ON
            //#pragma multi_compile _ LIGHTMAP_ON VERTEXLIGHT_ON

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define FORWARD_BASE_PASS
            #define BINORMAL_PER_FRAGMENT
            //#define FOG_DISTANCE
            #include "../IncludeShader/MyLighting.cginc"

            ENDCG
        }
        Pass
        {
            //前向渲染其他光源
            Tags {"LightMode" = "ForwardAdd"}
            Name "Custom_ForwardAdd"

            //默认是Blend One Zero 则会覆盖已有的
            //Blend One One
            // 
            //Blend SrcAlpha One
            Blend [_SrcBlend] One

            ZWrite Off

            CGPROGRAM
            #pragma target 3.0  

            #pragma shader_feature _ _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _ _DETIAL_MASK
            #pragma shader_feature _ _NORMAL_MAP
            #pragma shader_feature _ _DETAIL_ALBEDO_MAP
            #pragma shader_feature _ _DETAIL_NORMAL_MAP

            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

            //#pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT POINT_COOKIE SPOT
            //#pragma multi_compile_fwdadd
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            //#define FOG_DISTANCE

            //#define POINT

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "../IncludeShader/MyLighting.cginc"

            ENDCG
        }
        Pass
        {
            //延迟渲染
            Tags {"LightMode" = "Deferred"}
            Name "Custom_Deferred"

            Blend[_SrcBlend][_DstBlend]

            ZWrite[_ZWrite]

            CGPROGRAM
            #pragma target 3.0  
            #pragma exclude_renderers nomrt   

            #pragma shader_feature _ _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _ _EMISSION_MAP
            #pragma shader_feature _ _OCCLUSION_MAP
            #pragma shader_feature _ _DETIAL_MASK
            #pragma shader_feature _ _NORMAL_MAP
            #pragma shader_feature _ _DETAIL_ALBEDO_MAP
            #pragma shader_feature _ _DETAIL_NORMAL_MAP

            #pragma shader_feature _ _RENDERING_CUTOUT //_RENDERING_FADE _RENDERING_TRANSPARENT

            //#pragma multi_compile _ SHADOWS_SCREEN
            //#pragma multi_compile _ VERTEXLIGHT_ON
            //#pragma multi_compile _ UNITY_HDR_ON
            //#pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_prepassfinal

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define DEFERRED_PASS
            #define BINORMAL_PER_FRAGMENT
            #include "../IncludeShader/MyLighting.cginc"

            ENDCG
        }
        Pass
        {
            //阴影
            Tags {"LightMode" = "ShadowCaster"}
            Name "Custom_ShadowCaster"

            CGPROGRAM
            #pragma target 3.0  

            #pragma shader_feature _RENDERING_CUTOUT
            #pragma shader_feature _SMOOTHNESS_ALBEDO
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            #pragma shader_feature _SEMITRANSPARENT_SHADOWS

            #pragma multi_compile_shadowcaster
            #pragma vertex MyShadowVertexProgram
            #pragma fragment MyShadowFragmentProgram

            #include "../IncludeShader/MyShadow.cginc"

            ENDCG
        }
        Pass
        {
            //用于LightMap 间接光反射
            Tags {"LightMode" = "Meta"}
            Name "Custom_Meta"

            Cull Off

            CGPROGRAM

            #pragma vertex MyLightmappingVertexProgram
            #pragma fragment MyLightmappingFragmentProgram

            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _DETAIL_ALBEDO_MAP

            #include "../IncludeShader/MyLightmapping.cginc"

            ENDCG
        }
    }
    CustomEditor "MyLightingShaderGUI"
}
