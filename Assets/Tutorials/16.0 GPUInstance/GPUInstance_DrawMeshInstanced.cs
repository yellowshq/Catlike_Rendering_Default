using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class InstanceBatching
{
    public Matrix4x4[] matrix4X4s;
    public int batchingCount;
    public List<Vector4> colors;
    public InstanceBatching(int count, Matrix4x4[] matrix4X4s)
    {
        batchingCount = count;
        this.matrix4X4s = matrix4X4s;
        colors = new List<Vector4>(batchingCount);
        for (int i = 0; i < batchingCount; i++)
        {
            colors.Add(new Color(Random.value, Random.value, Random.value, 1.0f));
    }
    }
}

public class GPUInstance_DrawMeshInstanced : MonoBehaviour
{
    // Start is called before the first frame update
    public GameObject instance;
    public float radius = 50f;
    public int instanceCount = 5000;
    private int oneBatchingCount = 500;

    private Mesh mesh;
    private Material material;
    MaterialPropertyBlock materialProperty;
    private InstanceBatching[] instanceBatchings;

    public Camera m_camera;
    public bool useCommandBuffer;
    private CommandBuffer commandBuffer;
    void Start()
    {
        mesh = instance.GetComponentInChildren<MeshFilter>().sharedMesh;
        var renderer = instance.GetComponentInChildren<Renderer>();
        material = renderer.sharedMaterial;
        materialProperty = new MaterialPropertyBlock();

        var batchingCount = Mathf.CeilToInt(instanceCount / (float)oneBatchingCount);
        instanceBatchings = new InstanceBatching[batchingCount];
        for (int i = 0; i < batchingCount; i++)
        {
            int count = i < batchingCount - 1 ? oneBatchingCount : instanceCount - ((batchingCount - 1) * oneBatchingCount);
            Matrix4x4[] matrix4X4s = new Matrix4x4[1024];
            for (int j = 0; j < count; j++)
            {
                Vector3 pos = Random.insideUnitSphere * radius;
                matrix4X4s[j] = Matrix4x4.Translate(pos);
            }
            instanceBatchings[i] = new InstanceBatching(count, matrix4X4s);
        }

        if (useCommandBuffer)
        {
            CommandBufferForDrawMeshInstanced();
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (!useCommandBuffer)
        {
            DrawMeshInstanced();
        }
    }

    private void OnDestroy()
    {
        if (commandBuffer != null)
        {
            commandBuffer.Release();
            commandBuffer = null;
        }
    }

    public void DrawMeshInstanced()
    {
        foreach (var instanceBatching in instanceBatchings)
        {
            materialProperty.SetVectorArray("_Colors", instanceBatching.colors);
            Graphics.DrawMeshInstanced(mesh, 0, material, instanceBatching.matrix4X4s, instanceBatching.batchingCount, materialProperty);
            //Graphics.RenderMeshInstanced
        }
    }

    public void CommandBufferForDrawMeshInstanced()
    {
        if (commandBuffer != null)
        {
            m_camera.RemoveCommandBuffer(CameraEvent.AfterForwardOpaque, commandBuffer);
            commandBuffer.Release();
            commandBuffer = null;
        }
        commandBuffer = new CommandBuffer();
        commandBuffer.name = "DrawMeshInstanced";
        foreach (var instanceBatching in instanceBatchings)
        {
            commandBuffer.DrawMeshInstanced(mesh, 0, material,0, instanceBatching.matrix4X4s, instanceBatching.batchingCount);
        }
        m_camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, commandBuffer);
    }
}
