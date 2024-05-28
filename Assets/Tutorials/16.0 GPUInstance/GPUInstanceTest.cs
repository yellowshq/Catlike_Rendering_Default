using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 多个pass的物体会破坏批处理,因为多pass的shader会导致物体渲染多次,并切换渲染状态,所以会打断跟其他物体合批的机会）
/// FowardRender 前向渲染的多灯光渲染多一个pass所以无法合批，仅仅只能合批主光源
/// GPUInstancing 物体使用同一网格和同一材质才能生效
/// Static Batching 和 Dynamic Batching 则只需要同一材质即可
/// Dynamic 可移动物体的合批
/// 1.顶点属性不能超过900,
/// 2.延迟渲染无法合批
/// 3.每次渲染都需要合批,消耗大（不像静态合批）
/// 
/// Static 不可移动物体的合拼
/// 运行时把需要静态合批的物体合并到同一个网格中,则意味着运行时不能动
/// 只有一次操作,效率高
/// 占用更多的内存存储合并后的数据
/// 手动加载Instantiate的物体到场景中 是不会被静态批处理的。Unity打包时自动合并
/// 如何希望手动加载Instantiate的物体静态合批,可以调用 StaticBatchingUtility.Combine
/// 
/// 批处理时,优先考虑Static Batching, 然后GPUInstancing 最后是Dynamic Batching
/// 
/// SRP提供了 SRPBatcher， 可以对相同Shader Variant 的物体进行合批SRPBatcher优先于GPUInstancing
/// Graphics.DrawMeshInstanced绘制出来的，才会优先启用GPUInstancing。
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
            //var mat = t.GetComponent<MeshRenderer>().material; //会产生新的材质打断合批
            //mat.color = new Color(Random.value, Random.value, Random.value);

            //将颜色传给渲染器而不是赋值给材质球，
            //unity将材质属性块上传到实例缓冲区（Instancing Buffer）中供GPU使用
            //UNITY_INSTANCING_BUFFER_START(InstanceProperties) //InstanceProperties自定义实例名称
            //UNITY_DEFINE_INSTANCED_PROP(float4,_Color) //定实例化_Color数组 后续获取_Color 则要用UNITY_ACCESS_INSTANCED_PROP(_Color)
            //UNITY_INSTANCING_BUFFER_END(InstanceProperties) 包裹属性块
            //可以在同一个缓冲区中组合多个属性，但要牢记大小限制。还应注意，缓冲区被划分为32位块，因此单个浮点数需要与向量相同的空间
            var color = new Color(Random.value, Random.value, Random.value);
            materialPropertyBlock.SetColor("_Color", color);
            var renderer = t.GetComponentInChildren<MeshRenderer>();
            renderer.SetPropertyBlock(materialPropertyBlock);
        }
        //StaticBatchingUtility.Combine(transform.gameObject);
    }
}
