﻿using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using EdgeDetectMode = EdgeDetectPostProcessing.EdgeDetectMode;

public class EdgeDetectPostProcessing : PostProcessEffectSettings {
    public enum EdgeDetectMode {
        TriangleDepthNormals = 0,
        RobertsCrossDepthNormals = 1,
        SobelDepth = 2,
        SobelDepthThin = 3,
        TriangleLuminance = 4,
    }

    [Serializable]
    public sealed class EdgeDetectModeParameter : ParameterOverride<EdgeDetectMode> {
        public override void Interp(EdgeDetectMode from, EdgeDetectMode to, float t) {
            base.Interp(from, to, t);
        }
    }

    public EdgeDetectModeParameter mode = new EdgeDetectModeParameter() { value = EdgeDetectMode.SobelDepthThin };
    public FloatParameter sensitivityDepth = new FloatParameter() { value = 1.0f };
    public FloatParameter sensitivityNormals = new FloatParameter() { value = 1.0f };
    public FloatParameter lumThreshold = new FloatParameter() { value = 0.2f };
    public FloatParameter edgeExp = new FloatParameter() { value = 1.0f };
    [Range(0f, 10f)]
    public FloatParameter sampleDist = new FloatParameter() { value = 1.0f };
    [Range(0f, 1f)]
    public FloatParameter edgesOnly = new FloatParameter() { value = 0.0f };
    public ColorParameter edgesOnlyBgColor = new ColorParameter() { value = Color.white };
    public ColorParameter edgesColor = new ColorParameter() { value = Color.black };
}

//--------------------------------------------------------------------------------------------------------------------------------

public class EdgeDetectPostProcessingRenderer<T> : PostProcessEffectRenderer<T> where T : EdgeDetectPostProcessing {

    public override void Render(PostProcessRenderContext context) {
        if (settings == null)
            return;

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/EdgeDetect"));

        Vector2 sensitivity = new Vector2(settings.sensitivityDepth, settings.sensitivityNormals);
        sheet.properties.SetVector("_Sensitivity", new Vector4(sensitivity.x, sensitivity.y, 1.0f, sensitivity.y));
        sheet.properties.SetFloat("_BgFade", settings.edgesOnly);
        sheet.properties.SetFloat("_SampleDistance", settings.sampleDist);
        sheet.properties.SetVector("_BgColor", settings.edgesOnlyBgColor.value);
        sheet.properties.SetVector("_EdgesColor", settings.edgesColor);
        sheet.properties.SetFloat("_Exponent", settings.edgeExp);
        sheet.properties.SetFloat("_Threshold", settings.lumThreshold);

        // Set FOG params
        if (RenderSettings.fog) {
            sheet.EnableKeyword("APPLY_FOG");
            var fogColor = RuntimeUtilities.isLinearColorSpace ? RenderSettings.fogColor.linear : RenderSettings.fogColor;
            sheet.properties.SetVector("_FogColor", fogColor);
            sheet.properties.SetVector("_FogParams", 
                new Vector3(RenderSettings.fogDensity, RenderSettings.fogStartDistance, RenderSettings.fogEndDistance));
        } else {
            sheet.DisableKeyword("APPLY_FOG");
        }

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, (int)settings.mode.value);
    }

    public override DepthTextureMode GetCameraFlags() {
        if (settings == null)
            return DepthTextureMode.None;

        if (settings.mode == EdgeDetectMode.TriangleDepthNormals || settings.mode == EdgeDetectMode.RobertsCrossDepthNormals)
            return DepthTextureMode.DepthNormals;
        else {
            return DepthTextureMode.Depth;
        }
    }
}
