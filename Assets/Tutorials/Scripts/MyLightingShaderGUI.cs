using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// ����ɫ��ĩβ������CustomEditor "MyLightingShaderGUI" ��Ч
/// </summary>
public class MyLightingShaderGUI : ShaderGUI
{
    enum TessellationMode
    {
        Uniform, Edge
    }

    //��ɫ����ƽ���ȴ������ȡ
    private enum SmoothnessSource
    {
        Uniform,    //ͳһ��ֵ
        Albedo,     //��������ͼalpha
        Metallic,   //������ͼalpha
    }

    private enum RenderingMode
    {
        Opaque,
        Cutout,
        /// <summary>
        /// cutout ��Ⱦ�����ÿ��Ƭ�εģ�����ζ�ű�Ե����־�ݡ���Ϊ�ڱ���Ĳ�͸�����ֺ�͸������֮��û��ƽ�����ɡ�
        /// Ϊ�˽��������⣬���Ǳ������Ӷ���һ����Ⱦģʽ��֧�֡���ģʽ��֧�ְ�͸��, unity��Fade
        /// ������;��淴�䶼�᱾���������н�Fade
        /// </summary>
        Fade,
        /// <summary>
        /// ����ʵ���͸��Ч�����粣�����������־��������ĸ߹�ͷ���
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

            //�����������Ⱦ˳��
            //RenderQueue queue = mode == RenderingMode.Opaque ? RenderQueue.Geometry : RenderQueue.AlphaTest;

            //��һ����ǣ�����unity����ʵ�������ͣ��滻��ɫ��ʹ������ȷ���Ƿ�Ӧ��Ⱦ����
            //ʲô��replacement��ɫ����
            //�����Է��ʹ��������ɫ����Ⱦ����
            //Ȼ�������ʹ����Щ��ɫ���ֶ���Ⱦ������
            //���������������಻ͬ��Ч����
            //��ĳЩ����£���Ҫ��Ȼ��������޷�����ʱ��Unity���ܻ�ʹ���滻��ɫ�������������
            //�پ�һ�����ӣ������ʹ����ɫ���滻���鿴�Ƿ����κζ�������ͼ��ʹ��cutoff��ɫ���������ǽ���������Ϊ����ɫ��������ɫ��
            //��Ȼ����������ھ����ʵ�RenderType��ǩ����ɫ����
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
        //editor.TextureProperty(mainTex, mainTex.displayName); //Ĭ�ϵ���ʾ
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
        editor.TextureScaleOffsetProperty(mainTex); //ƽ�̺�ƫ��
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
        //��ҪHDR��ɫ
        editor.TexturePropertyWithHDRColor(MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"), emissionConfig, false);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWord("_EMISSION_MAP", map.textureValue);
            foreach (Material m in editor.targets)
            {
                //ָʾ�ڱ༭�䷢��ʱӦ�ú決�Է��⡣
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
