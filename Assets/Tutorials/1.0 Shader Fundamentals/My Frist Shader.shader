// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/My Frist Shader"
{
    Properties
    {
        _Tint("Tint", Color) = (1,1,1,1)

        //大括号是做什么用的？
        //以前，旧的固定功能着色器具有纹理设置，但现在不再使用。这些设置就是放在这些括号内。
        _MainTex("Texture",2D) = "white" {}

        //纹理设置Mipmaps和Filtering
        //当纹理像素和投影到的像素不匹配则会使用过滤模式
        //1.Point 最直接的过滤模式，使用最近的纹理像素
        // 
        //2.Bilinear Filtering 默认情况下使用的双线性过滤，在两个纹理像素之间的某个位置对纹理进行采样时，对这两个纹理像素进行插值，uv两个坐标，所有是双线性
        //该模式对纹理像素密度小于显示密度是有效，放大纹理看到很模糊。但是当缩小时部分纹理被跳过，导致粗糙过度。因此有了Mipmaps
        //使用哪种Mipmap取决于纹理像素于显示像素的密度，不是3D距离
        //因此，如果没有mipmap，你将会从模糊变为锐利，甚至变得过于锐利。使用mipmap，可以从模糊变成锐利，再到突然变得模糊，再到锐利，再到突然变得模糊，依此类推。
        //这些模糊的锐利边界是双线性滤波的特征，你可以通过将过滤器模式切换为Trilinear来摆脱它们。
        //3.Trilinear Filtering 与双线性相同，但也可以在相邻Mipmap间插值，所以是三线性。
        //4.Anisotropic Filtering 各向异性过滤，当将其设置为0时，纹理会变得更模糊。这与mipmap级别的选择有关。
        //当纹理以一定角度投影时，由于透视的原因，通常会导致其中一个维度比另一个维度扭曲得更多
        //选择哪个mipmap级别是基于最差的尺寸。如果差异很大，那么你将获得一维非常模糊的结果。
        //各向异性过滤通过解耦尺寸来减轻这种情况。除了均匀缩小纹理外，它还提供在两个维度上缩放不同数量的版本。
        //因此，您不仅拥有256x256的mipmap，而且还有256x128、256x64等的mipmap
        //请注意，这些额外的Mipmap不会像常规Mipmap那样预先生成。而是通过执行额外的纹理样本来模拟它们。因此，它们不需要更多空间，但采样成本更高。
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM

            //#预处理指令
            //pramga 特殊编译指令
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityCG.cginc"

            float4 _Tint;

            //OpenGlCore中 uniform 变量？
            //uniform表示变量对网格的所有顶点和片段具有相同的值。因此，它在所有顶点和片段上都是统一的。
            
            //SV_POSITION 中SV是系统值SystemValue
            //float4 MyVertexProgram(float4 position : POSITION, out float3 localPosition : TEXCOORD0) : SV_POSITION
            //{
            //    localPosition = position.xyz;
            //    return UnityObjectToClipPos(position);
            //}

            //我们并没有使用纹理坐标，为什么要使用TEXCOORD0？
            //插值数据没有通用语义。每个人都只对插入的所有内容（而不是顶点位置）使用纹理坐标语义。TEXCOORD0，TEXCOORD1，TEXCOORD2等。出于兼容性原因进行此操作。
            //float4 MyFragmentProgram(float4 position : SV_POSITION, float3 localPosition : TEXCOORD0) : SV_TARGET
            //{
            //    //编译器将 0自动填充成float4(0,0,0,0)
            //    //return 0;
            //    //return _Tint;
            //    return float4(localPosition, 1);
            //}

            /// <summary>
            /// 使用结构体
            /// </summary>
            //struct Interpolators {
            //    float4 position : SV_POSITION;
            //    float3 localPosition : TEXCOORD0;
            //};

            //Interpolators MyVertexProgram(float4 position : POSITION)
            //{
            //    Interpolators i;
            //    i.position = UnityObjectToClipPos(position);
            //    i.localPosition = position.xyz;
            //    return i;
            //}

            //float4 MyFragmentProgram(Interpolators i) : SV_Target
            //{
            //    //return float4(i.localPosition,1);
            //    return float4(i.localPosition + 0.5,1) * _Tint;
            //}

            /// <summary>
            /// 纹理 UV
            /// </summary>
            
            //sampler2D的变量访问着色器中的纹理
            sampler2D _MainTex;

            //平铺和偏移
            //这些额外的纹理数据存储在材质中，也可以由着色器访问。你可以通过与关联材质具有相同名称的变量加上_ST后缀来执行此操作。此变量的类型必须为float4。
            float4 _MainTex_ST;

            //顶点数据，uv在TEXCOORD0中由系统赋值--可在编译完成后的shader中查看
            struct VertexData {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
            };
            struct Interpolators {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators MyVertexProgram(VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);
                i.uv = v.uv;
                return i;
            }

            float4 MyFragmentProgram(Interpolators i) : SV_Target
            {
                //return float4(i.uv,1,1);
                i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                //i.uv = TRANSFORM_TEX(i.uv, _MainTex);
                return tex2D(_MainTex, i.uv) * _Tint;
            }

            ENDCG
        }
    }
}
