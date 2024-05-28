using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// ���pass��������ƻ�������,��Ϊ��pass��shader�ᵼ��������Ⱦ���,���л���Ⱦ״̬,���Ի��ϸ�������������Ļ��ᣩ
/// FowardRender ǰ����Ⱦ�Ķ�ƹ���Ⱦ��һ��pass�����޷�����������ֻ�ܺ�������Դ
/// GPUInstancing ����ʹ��ͬһ�����ͬһ���ʲ�����Ч
/// Static Batching �� Dynamic Batching ��ֻ��Ҫͬһ���ʼ���
/// Dynamic ���ƶ�����ĺ���
/// 1.�������Բ��ܳ���900,
/// 2.�ӳ���Ⱦ�޷�����
/// 3.ÿ����Ⱦ����Ҫ����,���Ĵ󣨲���̬������
/// 
/// Static �����ƶ�����ĺ�ƴ
/// ����ʱ����Ҫ��̬����������ϲ���ͬһ��������,����ζ������ʱ���ܶ�
/// ֻ��һ�β���,Ч�ʸ�
/// ռ�ø�����ڴ�洢�ϲ��������
/// �ֶ�����Instantiate�����嵽������ �ǲ��ᱻ��̬������ġ�Unity���ʱ�Զ��ϲ�
/// ���ϣ���ֶ�����Instantiate�����徲̬����,���Ե��� StaticBatchingUtility.Combine
/// 
/// ������ʱ,���ȿ���Static Batching, Ȼ��GPUInstancing �����Dynamic Batching
/// 
/// SRP�ṩ�� SRPBatcher�� ���Զ���ͬShader Variant ��������к���SRPBatcher������GPUInstancing
/// Graphics.DrawMeshInstanced���Ƴ����ģ��Ż���������GPUInstancing��
/// 
/// SRPBatcher > Static Batching > GPUInstancing > Dynamic Batching
/// </summary>
public class GPUInstanceTest : MonoBehaviour
{
    public Transform prefab;
    public float radius = 50f;
    public int instanceCount = 5000;

    void Start()
    {
        MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
        for (int i = 0; i < instanceCount; i++)
        {
            Transform t = Instantiate(prefab);
            t.position = Random.insideUnitSphere * radius;
            t.SetParent(transform);
            //t.gameObject.isStatic = true;
            //var mat = t.GetComponent<MeshRenderer>().material; //������µĲ��ʴ�Ϻ���
            //mat.color = new Color(Random.value, Random.value, Random.value);

            //����ɫ������Ⱦ�������Ǹ�ֵ��������
            //unity���������Կ��ϴ���ʵ����������Instancing Buffer���й�GPUʹ��
            //UNITY_INSTANCING_BUFFER_START(InstanceProperties) //InstanceProperties�Զ���ʵ������
            //UNITY_DEFINE_INSTANCED_PROP(float4,_Color) //��ʵ����_Color���� ������ȡ_Color ��Ҫ��UNITY_ACCESS_INSTANCED_PROP(_Color)
            //UNITY_INSTANCING_BUFFER_END(InstanceProperties) �������Կ�
            //������ͬһ������������϶�����ԣ���Ҫ�μǴ�С���ơ���Ӧע�⣬������������Ϊ32λ�飬��˵�����������Ҫ��������ͬ�Ŀռ�
            var color = new Color(Random.value, Random.value, Random.value);
            materialPropertyBlock.SetColor("_Color", color);
            var renderer = t.GetComponentInChildren<MeshRenderer>();
            renderer.SetPropertyBlock(materialPropertyBlock);
        }
        //StaticBatchingUtility.Combine(transform.gameObject);
    }
}
