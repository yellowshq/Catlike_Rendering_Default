Shader "Custom/Texture Splatting"
{
    Properties
    {
        _MainTex ("Splat Map", 2D) = "white" {}
       [NoScaleOffset] _Texture1 ("Texture 1", 2D) = "white" {}
       [NoScaleOffset] _Texture2 ("Texture 2", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityCG.cginc"

            sampler2D _MainTex, _Texture1, _Texture2;
            float4 _MainTex_ST;

            struct VertexData
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uvSplat : TEXCOORD1;
            };

            Interpolators MyVertexProgram(VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);
                i.uvSplat = v.uv;
                return i;
            }

            float4 MyFragmentProgram(Interpolators i) : SV_Target
            {
                float4 splat = tex2D(_MainTex, i.uvSplat);

                float4 col = tex2D(_Texture1, i.uv) * splat.r + tex2D(_Texture2, i.uv) * (1 - splat.r);
                return col;
            }
            ENDCG
        }
    }
}
