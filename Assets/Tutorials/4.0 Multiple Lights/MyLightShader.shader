Shader "Custom_Test/My Light Shader 1"
{
    Properties
    {
        _Tint ("Tint", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.1
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
