﻿using UnityEngine.Rendering.PostProcessing;

[System.Serializable]
[PostProcess(typeof(EdgeDetectPostProcessingRenderer_AfterStack), PostProcessEvent.AfterStack, "Edge Detection/Edge Detection (After Stack)")]
public sealed class EdgeDetect_AfterStack : EdgeDetectPostProcessing { }

//--------------------------------------------------------------------------------------------------------------------------------

public sealed class EdgeDetectPostProcessingRenderer_AfterStack : EdgeDetectPostProcessingRenderer<EdgeDetect_AfterStack> { }
