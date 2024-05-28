using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// 在着色器末尾添加语句CustomEditor "MyLightingShaderGUI" 生效
/// </summary>
public class MyLightingShaderGUI : ShaderGUI
{
    enum TessellationMode
    {
        Uniform, Edge
    }

    //着色器的平滑度从哪里获取
    private enum SmoothnessSource
    {
        Uniform,    //统一数值
        Albedo,     //反照率贴图alpha
        Metallic,   //金属贴图alpha
    }

    private enum RenderingMode
    {
        Opaque,
        Cutout,
        /// <summary>
        /// cutout 渲染是针对每个片段的，这意味着边缘会出现锯齿。因为在表面的不透明部分和透明部分之间没有平滑过渡。
        /// 为了解决这个问题，我们必须增加对另一种渲染模式的支持。此模式将支持半透明, unity叫Fade
        /// 漫反射和镜面反射都会本淡化，所有叫Fade
        /// </summary>
        Fade,
        /// <summary>
        /// 用于实体半透明效果，如玻璃，镜子这种具有清晰的高光和反射
        /// </summary>
        Transparent,
    }

    private struct RenderingSetting
    {
        public RenderQueue quque;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderingSetting[] modes =
        {
            new RenderingSetting()
            {
                quque = RenderQueue.Geometry,
                renderType = "",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true,
            },
            new RenderingSetting()
            {
                quque = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true,
            },
            new RenderingSetting()
            {
                quque = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false,
            },
            new RenderingSetting()
            {
                quque = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false,
            },
        };
    }

    bool shouldShowAlphaCutoff;

    Material target;
    MaterialEditor editor;
    MaterialProperty[] properties;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
        DoRenderingMode();
        DoMain();
        if (target.HasProperty("_TessellationUniform"))
        {
            DoTessellation();
        }
        if (target.HasProperty("_WireframeColor"))
        {
            DoWireframe();
        }
        DoSecondary();
        DoAdvance();
    }

    private void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutoff = false;
        if (IsKeyWordEnable("_RENDERING_CUTOUT"))
        {
            mode = RenderingMode.Cutout;
            shouldShowAlphaCutoff = true;
        }else if (IsKeyWordEnable("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        }
        else if (IsKeyWordEnable("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");
            SetKeyWord("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyWord("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyWord("_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent);

            //决定物体的渲染顺序
            //RenderQueue queue = mode == RenderingMode.Opaque ? RenderQueue.Geometry : RenderQueue.AlphaTest;

            //是一个标记，告诉unity该着实器的类型，替换着色器使用它来确定是否应渲染对象。
            //什么是replacement着色器？
            //它可以否决使用哪种着色器渲染对象。
            //然后，你可以使用这些着色器手动渲染场景。
            //这可以用来创建许多不同的效果。
            //在某些情况下，需要深度缓冲区但无法访问时，Unity可能会使用替换着色器创建深度纹理。
            //再举一个例子，你可以使用着色器替换来查看是否有任何对象在视图中使用cutoff着色器，方法是将它们设置为亮红色或其他颜色。
            //当然，这仅适用于具有适当RenderType标签的着色器。
            //string renderType = mode == RenderingMode.Opaque ? "" : "TransparentCutout";

            foreach (Material m in editor.targets)
            {
                var renderingSetting = RenderingSetting.modes[(int)mode];
                m.renderQueue = (int)renderingSetting.quque;
                m.SetOverrideTag("RenderType", renderingSetting.renderType);
                m.SetInt("_SrcBlend", (int)renderingSetting.srcBlend);
                m.SetInt("_DstBlend", (int)renderingSetting.dstBlend);
                m.SetInt("_ZWrite", renderingSetting.zWrite ? 1 : 0);
            }
        }

        if (mode == RenderingMode.Fade || mode == RenderingMode.Transparent)
        {
            DoSemitranparentShadows();
        }
    }

    private void DoSemitranparentShadows()
    {
        EditorGUI.BeginChangeCheck();
        bool semitransparentShadows = EditorGUILayout.Toggle(MakeLabel("Semitransp. Shadows", "Semitransparent Shadows"), IsKeyWordEnable("_SEMITRANSPARENT_SHADOWS"));
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_SEMITRANSPARENT_SHADOWS", semitransparentShadows);
        }
        if (!semitransparentShadows)
        {
            shouldShowAlphaCutoff = true;
        }
    }

    private void DoMain()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);
        MaterialProperty mainTex = FindProperty("_MainTex");
        //GUIContent albedoLabel = MakeLabel(mainTex.displayName, "Albedo(RGB)");
        //editor.TextureProperty(mainTex, mainTex.displayName); //默认的显示
        editor.TexturePropertySingleLine(MakeLabel(mainTex.displayName, "Albedo (RGB)"), mainTex, FindProperty("_Color"));
        if(shouldShowAlphaCutoff)
        {
            DoAlphaCutoff();
        }
        DoMetallic();
        DoSmoothness();
        DoNormal();
        DoParallax();
        DoOcclusion();
        DoEmission();
        DoDetailMask();
        editor.TextureScaleOffsetProperty(mainTex); //平铺和偏移
    }

    private void DoAdvance()
    {
        GUILayout.Label("Advanced Options", EditorStyles.boldLabel);
        editor.EnableInstancingField();
    }

    private void DoAlphaCutoff()
    {
        MaterialProperty slider = FindProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel -= 2;
    }

    private void DoNormal()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map.displayName), map, map.textureValue ? FindProperty("_BumpScale") : null);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_NORMAL_MAP", map.textureValue);
        }
    }

    private void DoMetallic()
    {
        MaterialProperty map = FindProperty("_MetallicMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map), map, map.textureValue ? null : FindProperty("_Metallic"));
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_METALLIC_MAP", map.textureValue);
        }
    }

    private void DoSmoothness()
    {
        SmoothnessSource source = SmoothnessSource.Uniform;
        if (IsKeyWordEnable("_SMOOTHNESS_ALBEDO"))
        {
            source = SmoothnessSource.Albedo;
        }else if (IsKeyWordEnable("_SMOOTHNESS_METALLIC"))
        {
            source = SmoothnessSource.Metallic;
        }
        MaterialProperty slider = FindProperty("_Smoothness");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel += 1;
        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source"), source);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Smoothness Source");
            SetKeyWord("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyWord("_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic);
        }
        EditorGUI.indentLevel -= 3;
    }


    private void DoEmission()
    {
        MaterialProperty map = FindProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();
        //editor.TexturePropertySingleLine(MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"));
        //需要HDR颜色
        editor.TexturePropertyWithHDRColor(MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"), emissionConfig, false);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_EMISSION_MAP", map.textureValue);
            foreach (Material m in editor.targets)
            {
                //指示在编辑其发射时应该烘焙自发光。
                m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.BakedEmissive;
            }
        }
    }

    private void DoParallax()
    {
        MaterialProperty map = FindProperty("_ParallaxMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map, "Parallax (G)"), map, map.textureValue ? FindProperty("_ParallaxStrength") : null);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_PARALLAX_MAP", map.textureValue);
        }
    }


    private void DoOcclusion()
    {
        MaterialProperty map = FindProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map, "Occlusion (G)"), map, map.textureValue ? FindProperty("_OcclusionStrength") : null);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_OCCLUSION_MAP", map.textureValue);
        }
    }

    private void DoDetailMask()
    {
        MaterialProperty map = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map, "Detail Mask (A)"), map);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_DETAIL_MASK", map.textureValue);
        }
    }


    private void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);
        MaterialProperty detailTex = FindProperty("_DetailTex");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_DETAIL_ALBEDO_MAP", detailTex.textureValue);
        }
        DoSecondaryNormals();
        editor.TextureScaleOffsetProperty(detailTex);
    }

    private void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map), map, map.textureValue ? FindProperty("_DetailBumpScale") : null);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_DETAIL_NORMAL_MAP", map.textureValue);
        }
    }

    private void DoWireframe()
    {
        GUILayout.Label($"Wireframe", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(FindProperty("_WireframeColor"), MakeLabel("Color"));
        editor.ShaderProperty(FindProperty("_WireframeSmoothing"), MakeLabel("Smoothing", "In screen space."));
        editor.ShaderProperty(FindProperty("_WireframeThickness"), MakeLabel("Thickness", "In screen space."));
        EditorGUI.indentLevel -= 2;
    }

    void DoTessellation()
    {
        GUILayout.Label("Tessellation", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;

        TessellationMode mode = TessellationMode.Uniform;
        if (IsKeyWordEnable("_TESSELLATION_EDGE"))
        {
            mode = TessellationMode.Edge;
        }
        EditorGUI.BeginChangeCheck();
        mode = (TessellationMode)EditorGUILayout.EnumPopup(
            MakeLabel("Mode"), mode
        );
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Tessellation Mode");
            SetKeyWord("_TESSELLATION_EDGE", mode == TessellationMode.Edge);
        }

        if (mode == TessellationMode.Uniform)
        {
            editor.ShaderProperty(
                FindProperty("_TessellationUniform"),
                MakeLabel("Uniform")
            );
        }
        else
        {
            editor.ShaderProperty(
                FindProperty("_TessellationEdgeLength"),
                MakeLabel("Edge Length")
            );
        }
        EditorGUI.indentLevel -= 2;
    }

    private void RecordAction(string label)
    {
        editor.RegisterPropertyChangeUndo(label);
    }

    private void SetKeyWord(string keyword, bool state)
    {
        if (state)
        {
            target.EnableKeyword(keyword);
        }
        else
        {
            target.DisableKeyword(keyword);
        }
    }

    private bool IsKeyWordEnable(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
    }

    private MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    static GUIContent staticLabel = new GUIContent();

    static GUIContent MakeLabel(string text, string tooltip = null)
    {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    static GUIContent MakeLabel(MaterialProperty property, string tooltip = null)
    {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    static ColorPickerHDRConfig emissionConfig = new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);
}
