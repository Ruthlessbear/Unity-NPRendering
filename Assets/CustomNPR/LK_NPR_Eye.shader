Shader "BearLibrary/NPR/Eye"
{
    Properties
    {
        [Main(Group1, _, off, off)]_Group1("Setting", float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] 
        [Sub(Group1)]_SrcBlendAlpha("Src Blend (A)", Float) = 0 
        [Enum(UnityEngine.Rendering.BlendMode)] 
        [Sub(Group1)]_DstBlendAlpha("Dst Blend (A)", Float) = 0 
        [Sub(Group1)]_Color("Color", Color) = (0.6770648, 0.7038123, 0.8018868, 0.7647059)
        [Sub(Group1)]_DitherAlpha("Dither Alpha", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Geometry+10"
        }

        Pass
        {
            Name "EyeShadow"

            Stencil
            {
                Ref 1
                ReadMask 1  
                Comp Equal
                Pass Keep
                Fail Keep
            }

            Cull Back
            ZWrite Off

            Blend DstColor Zero, [_SrcBlendAlpha] [_DstBlendAlpha]

            ColorMask RGBA 0
            ColorMask 0 1

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Core/NPRRenderHelper.hlsl"

            CBUFFER_START(NPRBodyMaterial)
                float4 _Color;
                float _DitherAlpha;
            CBUFFER_END

            #pragma vertex vert
            #pragma fragment frag

            float4 vert(float3 positionOS : POSITION) : SV_POSITION
            {
                return TransformObjectToHClip(positionOS);
            }

            float4 frag(float4 positionHCS : SV_POSITION) : SV_Target0
            {
                DoDitherAlphaEffect(positionHCS, _DitherAlpha);
                return _Color;
            }

            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"
    Fallback Off
}
