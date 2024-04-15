Shader "Custom/DeferredShading"
{
    SubShader
    {
        Pass
        {
            //Blend One One
            Blend [_SrcBlend] [_DstBlend]
       /*     Cull Off
            ZWrite Off*/
            ZTest Always

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex VertexProgram 
            #pragma fragment FragmentProgram
            #pragma exclude_renderers nomrt

            #pragma multi_compile_lightpass
            #pragma multi_compile _ UNITY_HDR_ON

            #include "../IncludeShader/MyDeferredShading.cginc"
            ENDCG
        }

        //禁用HDR后，灯光数据将会进行对数编码
        //该Pass负责解码

        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always

            Stencil {
                Ref [_StencilNonBackground]
                ReadMask [_StencilNonBackground]
                CompBack Equal
                CompFront Equal
            }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex VertexProgram 
            #pragma fragment FragmentProgram
            #pragma exclude_renderers nomrt

            #include "UnityCG.cginc"

            sampler2D _LightBuffer;

            struct VertexData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators VertexProgram(VertexData v)
            {
                Interpolators i;
                i.pos = UnityObjectToClipPos(v.vertex);
                i.uv = v.uv;
                return i;
            }

            fixed4 FragmentProgram(Interpolators i) : SV_Target
            {
                return -log2(tex2D(_LightBuffer, i.uv));
            }
            ENDCG
        }
    }
}
