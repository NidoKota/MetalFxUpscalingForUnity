// ===== CUSTOM MODIFICATION START =====
// Modified by: Matsubara on 2025/09/02
namespace UnityEngine.Rendering.Universal
{
    public enum MtlFxSpatialScalerColorProcessingMode
    {
        MTLFXSpatialScalerColorProcessingModePerceptual = 0, /* This should be used when the input and output textures are already in an sRGB or otherwise perceptual 0-1 encoding. */
        MTLFXSpatialScalerColorProcessingModeLinear = 1,     /* This should be used when the input and output textures will contain light linear data in the 0-1 range. */
        MTLFXSpatialScalerColorProcessingModeHDR = 2,        /* This should be used when the input and output texture will contain light linear data outside the 0-1 range.
                                                                In this case a reversible tonemapping operation will be done internally to convert to a 0-1 range. */
    }
}
// ===== CUSTOM MODIFICATION END =====