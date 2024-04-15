// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/My Frist Shader"
{
    Properties
    {
        _Tint("Tint", Color) = (1,1,1,1)

        //����������ʲô�õģ�
        //��ǰ���ɵĹ̶�������ɫ�������������ã������ڲ���ʹ�á���Щ���þ��Ƿ�����Щ�����ڡ�
        _MainTex("Texture",2D) = "white" {}

        //��������Mipmaps��Filtering
        //���������غ�ͶӰ�������ز�ƥ�����ʹ�ù���ģʽ
        //1.Point ��ֱ�ӵĹ���ģʽ��ʹ���������������
        // 
        //2.Bilinear Filtering Ĭ�������ʹ�õ�˫���Թ��ˣ���������������֮���ĳ��λ�ö�������в���ʱ�����������������ؽ��в�ֵ��uv�������꣬������˫����
        //��ģʽ�����������ܶ�С����ʾ�ܶ�����Ч���Ŵ���������ģ�������ǵ���Сʱ�����������������´ֲڹ��ȡ��������Mipmaps
        //ʹ������Mipmapȡ����������������ʾ���ص��ܶȣ�����3D����
        //��ˣ����û��mipmap���㽫���ģ����Ϊ������������ù���������ʹ��mipmap�����Դ�ģ������������ٵ�ͻȻ���ģ�����ٵ��������ٵ�ͻȻ���ģ�����������ơ�
        //��Щģ���������߽���˫�����˲��������������ͨ����������ģʽ�л�ΪTrilinear���������ǡ�
        //3.Trilinear Filtering ��˫������ͬ����Ҳ����������Mipmap���ֵ�������������ԡ�
        //4.Anisotropic Filtering �������Թ��ˣ�����������Ϊ0ʱ��������ø�ģ��������mipmap�����ѡ���йء�
        //��������һ���Ƕ�ͶӰʱ������͸�ӵ�ԭ��ͨ���ᵼ������һ��ά�ȱ���һ��ά��Ť���ø���
        //ѡ���ĸ�mipmap�����ǻ������ĳߴ硣�������ܴ���ô�㽫���һά�ǳ�ģ���Ľ����
        //�������Թ���ͨ������ߴ�������������������˾�����С�����⣬�����ṩ������ά�������Ų�ͬ�����İ汾��
        //��ˣ�������ӵ��256x256��mipmap�����һ���256x128��256x64�ȵ�mipmap
        //��ע�⣬��Щ�����Mipmap�����񳣹�Mipmap����Ԥ�����ɡ�����ͨ��ִ�ж��������������ģ�����ǡ���ˣ����ǲ���Ҫ����ռ䣬�������ɱ����ߡ�
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM

            //#Ԥ����ָ��
            //pramga �������ָ��
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityCG.cginc"

            float4 _Tint;

            //OpenGlCore�� uniform ������
            //uniform��ʾ��������������ж����Ƭ�ξ�����ͬ��ֵ����ˣ��������ж����Ƭ���϶���ͳһ�ġ�
            
            //SV_POSITION ��SV��ϵͳֵSystemValue
            //float4 MyVertexProgram(float4 position : POSITION, out float3 localPosition : TEXCOORD0) : SV_POSITION
            //{
            //    localPosition = position.xyz;
            //    return UnityObjectToClipPos(position);
            //}

            //���ǲ�û��ʹ���������꣬ΪʲôҪʹ��TEXCOORD0��
            //��ֵ����û��ͨ�����塣ÿ���˶�ֻ�Բ�����������ݣ������Ƕ���λ�ã�ʹ�������������塣TEXCOORD0��TEXCOORD1��TEXCOORD2�ȡ����ڼ�����ԭ����д˲�����
            //float4 MyFragmentProgram(float4 position : SV_POSITION, float3 localPosition : TEXCOORD0) : SV_TARGET
            //{
            //    //�������� 0�Զ�����float4(0,0,0,0)
            //    //return 0;
            //    //return _Tint;
            //    return float4(localPosition, 1);
            //}

            /// <summary>
            /// ʹ�ýṹ��
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
            /// ���� UV
            /// </summary>
            
            //sampler2D�ı���������ɫ���е�����
            sampler2D _MainTex;

            //ƽ�̺�ƫ��
            //��Щ������������ݴ洢�ڲ����У�Ҳ��������ɫ�����ʡ������ͨ����������ʾ�����ͬ���Ƶı�������_ST��׺��ִ�д˲������˱��������ͱ���Ϊfloat4��
            float4 _MainTex_ST;

            //�������ݣ�uv��TEXCOORD0����ϵͳ��ֵ--���ڱ�����ɺ��shader�в鿴
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
