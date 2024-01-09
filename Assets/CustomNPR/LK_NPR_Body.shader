Shader "BearLibrary/NPR/Body"
{
    Properties
    {
        [HideInInspector]_ModelScale("Model Scale", Float) = 1

        [Main(Group1, _, off, off)] _group1 ("Base Setting", float) = 0
        [Advanced(Shader Options)]
        [Enum(UnityEngine.Rendering.CullMode)] [Sub(Group1)]_Cull("Cull", Float) = 0                      
        [Advanced][Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendColor("Src Blend (RGB)", Float) = 1 
        [Advanced][Enum(UnityEngine.Rendering.BlendMode)] _DstBlendColor("Dst Blend (RGB)", Float) = 0 
        [Advanced][Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha("Src Blend (A)", Float) = 0   
        [Advanced][Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha("Dst Blend (A)", Float) = 0   
        [Advanced][Space(5)]
        [Advanced][Toggle] _AlphaTest("Alpha Test", Float) = 0
        [Advanced][If(_ALPHATEST_ON)] [Indent] _AlphaTestThreshold("Threshold", Range(0, 1)) = 0.5

        [Advanced(Maps)]
        [SingleLineTextureNoScaleOffset(_Color)][Sub(Group1)] _MainTex("Albedo", 2D) = "white" {}
        [Advanced][HideInInspector] _Color("Color", Color) = (1, 1, 1, 1)
        [Advanced][SingleLineTextureNoScaleOffset] _LightMap("Light Map", 2D) = "white" {}
        [Advanced][TextureScaleOffset] _Maps_ST("Maps Scale Offset", Vector) = (1, 1, 0, 0)
        [Advanced][Header(Overrides)] [Space(5)]
        [Advanced][If(_MODEL_GAME)] _BackColor("Back Face Color", Color) = (1, 1, 1, 1)
        [Advanced][If(_MODEL_GAME)] [Toggle] _BackFaceUV2("Back Face Use UV2", Float) = 0

        [Main(Group2, _, off, off)] _group2 ("Shading Setting", float) = 0
        [Advanced(Diffuse)]
        [RampTexture][Sub(Group2)] _RampMapCool("Ramp (Cool)", 2D) = "white" {}
        [Advanced][RampTexture] _RampMapWarm("Ramp (Warm)", 2D) = "white" {}
        [Advanced]_RampCoolWarmLerpFactor("Cool / Warm", Range(0, 1)) = 1

        [Advanced(Specular)]
        [HDR][Sub(Group2)]_SpecularColor("Color", Color) = (1, 1, 1, 1)    
        [Advanced]_SpecularMetallic("Metallic", Float) = 0  
        [Advanced]_SpecularShininess("Shininess", Float) = 0
        [Advanced]_SpecularIntensity("Intensity", Float) = 0
        [Advanced]_SpecularEdgeSoftness("Edge Softness", Float) = 0

        [Advanced(Stockings)]
        [Sub(Group2)]_StockingsMap("Stockings Texture", 2D) = "black" {}
        [Advanced]_StockingsColor("Stockings Color", Color) = (1, 1, 1, 1)
        [Advanced]_StockingsColorDark("Dark Rim Color", Color) = (1, 1, 1, 1)
        [Advanced]_StockingsDarkWidth("Dark Rim Width", Range(0, 0.96)) = 0.5
        [Advanced]_StockingsPower("Stockings Power", Range(0.04, 1)) = 1
        [Advanced]_StockingsLightedWidth("Lighted Width", Range(1, 32)) = 1
        [Advanced]_StockingsLightedIntensity("Lighted Intensity", Range(0, 1)) = 0.25
        [Advanced]_StockingsRoughness("Roughness", Range(0, 1)) = 1

        [Advanced(Rim Light)]
        [Sub(Group2)]_RimLightWidth ("Width", Float) = 0
        [Advanced]_MinRange ("MinRange", Range(0, 1)) = 0 
        [Advanced]_MaxRange ("MaxRange", Range(0, 1)) = 1
        [Advanced]_RimSpread ("Spread", Float) = 1
        [Advanced][HDR]_RimCol ("Rim Color", Color) = (1, 1, 1, 1)
        [Advanced][Toggle]_RimLightMask("Rim Light Mask", float) = 1

        [Advanced(Emission)]
        [Sub(Group2)]_EmissionColor("Color", Color) = (1, 1, 1, 1)
        [Advanced]_EmissionThreshold("Threshold", Range(0, 1)) = 1
        [Advanced]_EmissionIntensity("Intensity", Float) = 0

        [Main(Group3, _, off, off)] _group3 ("Shadow Setting", float) = 0
        [Sub(Group3)]_ShadowOffset("Shadow Offset", Range(0, 1)) = 0.6
        [Sub(Group3)]_ShadowIntensity("Shadow Intensity", Range(0, 1)) = 0.6
        [Sub(Group3)]_ShadowColor("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)

        [Main(Group4, _, off, off)] _group4 ("Outline", float) = 0
        [KeywordEnum(Tangent, Normal)][Sub(Group4)] _OutlineNormal("Normal Source", Float) = 0
        [Sub(Group4)]_OutlineWidth("Width", Range(0, 4)) = 1
        [Sub(Group4)]_OutlineZOffset("Z Offset", Float) = 0
        [Sub(Group4)]_OutlineColor("Color", Color) = (0, 0, 0, 0)

        [Main(Group5, _, off, off)] _group5 ("Alpha Dither", float) = 0
        [Sub(Group5)]
        _DitherAlpha("Alpha", Range(0, 1)) = 1

        
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry+30"
        }

        Pass
        {
            Name "Base Opaque"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull[_Cull]
            ZWrite On
            
            Blend 0 [_SrcBlendColor] [_DstBlendColor], [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 One Zero

            ColorMask RGBA 0
            ColorMask R 1

            HLSLPROGRAM

            #include "Core/NPRBody.hlsl"

            #pragma vertex BodyVertex
            #pragma fragment BodyFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

            ENDHLSL
        }

        Pass
        {
            Name "Outline"

            Cull Front
            ZTest LEqual
            ZWrite On
            
            Blend 0 [_SrcBlendColor] [_DstBlendColor], [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 Zero Zero

            ColorMask RGBA 0
            ColorMask 0 1

            HLSLPROGRAM

            #include "Core/NPRBody.hlsl"

            #pragma vertex BodyOutlineVertex
            #pragma fragment BodyOutlineFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON
            #pragma shader_feature_local_vertex _OUTLINENORMAL_TANGENT _OUTLINENORMAL_NORMAL

            ENDHLSL
        }

        Pass
        {
            Name "BodyShadow"

            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            CULL [_CULL]
            ZWrite On
            ZTest LEqual
            
            ColorMask 0 0 
            ColorMask 0 1

            HLSLPROGRAM

            #include "Core/NPRBody.hlsl"

            #pragma vertex BodyShadowVertex
            #pragma fragment BodyShadowFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            ENDHLSL
        }

        Pass
        {
            Name "BodyDepthOnly"

            Tags
            {
                "LightMode" = "DepthOnly"
            }

            Cull [_Cull]
            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #include "Core/NPRBody.hlsl"

            #pragma vertex BodyDepthOnlyVertex
            #pragma fragment BodyDepthOnlyFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"

    Fallback Off
}
