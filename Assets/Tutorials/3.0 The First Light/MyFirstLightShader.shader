Shader "Custom/My First Light Shader 1"
{
    Properties
    {
        _Tint ("Tint", Color) = (1,1,1,1)
        //材质的漫反射率称为:Albedo(反照率)，描述了多少RGB通道被反射了，另外的则被吸收了
        _MainTex ("Albedo", 2D) = "white" {}
        //_SpecularTint ("SpecularTint", Color) = (0.5,0.5,0.5)
       
        //Gamma 将gamma矫正用于该值以便于在线性空间下保持正确
        //金属工作流， 不需要_SpecularTint,可以通过金属特行得出镜面反射颜色
        //对于非金属来说，使用改方法镜面反射就没那么清晰了，PBS(基于物理得着色更好的解决这点)
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Pass
        {
            //LightMode 灯光模式，确定在那种光模式下该Pass起效
            Tags{"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma target 3.0   //确保unity使用最佳的BRDF功能,着色器级别至少是3.0
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            //#include "UnityCG.cginc"
            //#include "UnityStandardBRDF.cginc"
            //#include "UnityStandardUtils.cginc"
            #include "UnityPBSLighting.cginc"

            float4 _Tint;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            //float4 _SpecularTint;
            float _Metallic;
            float _Smoothness;

            struct VertexData
            {
                float4 position : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            Interpolators MyVertexProgram(VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);
                i.worldPos = mul(unity_ObjectToWorld, v.position);
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //i.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
                //由于存在不统一得比例尺缩放(假如仅仅缩放x轴为原来得1/2,则法线的x轴应该缩放为原来的2倍;
                //例:O=S₁R₁P₁S₂R₂P₂ 法线为向量可忽略P矩阵, 因此：O=S₁R₁S₂R₂
                //需要一个矩阵N = S₁-¹R₁S₂-¹R₂
                //O-¹ = R₂-¹S₂-¹R₁-¹S₁-¹
                //(O-¹)^T = S₁-¹^T R₁-¹^T S₂-¹^T R₂-¹^T
                //缩放矩阵的转置等于本身 => S₁-¹^T = S₁-¹
                //旋转矩阵的逆等于矩阵的转置 =>  R₁-¹^T = R₁
                i.normal = UnityObjectToWorldNormal(v.normal); //==mul(transpose((float3x3)unity_WorldToObject), v.normal);
                i.normal = normalize(i.normal);
                return i;
            }

            float4 MyFragmentProgram(Interpolators i) : SV_Target
            {
                //由于向量间插值得到向量不是一个单位向量，比单位向量更小，所以需要重新Normalize;
                //通常误差很小，如果注重性能可省略此步骤，特别是移动设备上
                i.normal = normalize(i.normal);
                //return float4(i.normal * 0.5 + 0.5,1);
                
                //兰伯特余弦定理
                //return max(0,dot(float3(0, 1, 0), i.normal)); //saturate(dot(float3(0, 1, 0), i.normal));
                //return DotClamped(float3(0, 1, 0), i.normal);  //UnityDeprecated.cginc in UnityStandardBRDF.cginc

                float3 lightDir = _WorldSpaceLightPos0.xyz; //UnityShaderVariables.cginc
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 reflectionDir = reflect(-lightDir, i.normal); //Phong反射模型
                float3 halfVector = normalize(lightDir + viewDir); //Blinn-Phong

                float3 lightColor = _LightColor0.rgb;
                float3 abledo = tex2D(_MainTex, i.uv);

                //能量守恒
                //abledo *= 1 - _SpecularTint.rgb; //在仅有单色得情况下会出现颜色怪异得结果
                //abledo *= 1 - max(_SpecularTint.r, max(_SpecularTint.g, _SpecularTint.b)); //单色能量守恒
                float oneMinusReflectivity;
                //abledo = EnergyConservationBetweenDiffuseAndSpecular(abledo, _SpecularTint, oneMinusReflectivity); //UnityStandardUtils.cginc
                //float3 specularTint = abledo * _Metallic; //越接近金属 吸收颜色越多物体越接近黑色
                //abledo *= 1 - _Metallic; //由于纯介电材质，也仍然具有镜面反射所以该方法不可取
                
                float3 specularTint;
                abledo = DiffuseAndSpecularFromMetallic(abledo, _Metallic, specularTint, oneMinusReflectivity);

                //float3 diffuse = abledo * lightColor * DotClamped(lightDir, i.normal);

                //float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector, i.normal), _Smoothness * 100);
                //float3 specular = specularTint * lightColor * pow(DotClamped(halfVector, i.normal), _Smoothness * 100);


                //return pow(DotClamped(viewDir, reflectionDir), _Smoothness * 100);
                //return pow(DotClamped(halfVector, i.normal), _Smoothness * 100);
                //return float4(specular + diffuse , 1);
                //return float4(diffuse, 1);

                UnityLight light;
                light.color = lightColor;
                light.dir = lightDir;
                light.ndotl = DotClamped(i.normal, lightDir);

                UnityIndirect indirectLight;
                indirectLight.diffuse = float3(0, 0, 0);  //环境光颜色
                indirectLight.specular = float3(0, 0, 0); //环境光反射

                return UNITY_BRDF_PBS(abledo, specularTint, oneMinusReflectivity, _Smoothness, i.normal, viewDir, light, indirectLight);    //UnityPBSLighting.cginc
            }

            ENDCG
        }
    }
}
