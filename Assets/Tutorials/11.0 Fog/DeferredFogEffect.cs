using System;
using UnityEngine;

[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader deferredFog;
    [NonSerialized]
    private Material fogMaterial;

    [NonSerialized]
    private Camera deferredCamera;
    private Vector3[] frustumCorners;
    private Vector4[] vectorArray;

    [ImageEffectOpaque]
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            fogMaterial = new Material(deferredFog);
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
        }

        deferredCamera.CalculateFrustumCorners(new Rect(0, 0, 1, 1), deferredCamera.farClipPlane, deferredCamera.stereoActiveEye, frustumCorners);
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[3];
        vectorArray[2] = frustumCorners[1];
        vectorArray[3] = frustumCorners[2];

        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);

        Graphics.Blit(source, destination, fogMaterial);
    }
}
