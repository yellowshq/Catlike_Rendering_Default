Shader "Custom_Test/My Light Shader 2"
{
    Properties
    {
        _Tint ("Tint", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        //[NoScaleOffset] _HeightMap("Heights", 2D) = "gray" {}
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.1
        _DetailTex("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset]_DetailNormalMap("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale("Detail Bump Scale", Float) = 1
    }
    SubShader
    {
        Pass
        {
            //用于主方向灯
            Tags{"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma target 3.0  
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define FORWARD_BASE_PASS
            //#define BINORMAL_PER_FRAGMENT
            #include "../IncludeShader/MyLighting.cginc"

            ENDCG
        }
        Pass
        {
            //其他光源
            Tags{"LightMode" = "ForwardAdd"}
            //默认是Blend One Zero 则会覆盖已有的
            Blend One One
            ZWrite Off

            CGPROGRAM
            #pragma target 3.0  

            //#pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT POINT_COOKIE SPOT
            #pragma multi_compile_fwdadd
            //#define POINT

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "../IncludeShader/MyLighting.cginc"

            ENDCG
        }
    }
}
