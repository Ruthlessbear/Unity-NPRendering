Shader "BearLibrary/NPR/Hair"
{
    Properties
    {
        [HideInInspector]_ModelScale("Model Scale", Float) = 1

        [Main(Group1, _, off, off)] _group1 ("Base Setting", float) = 0
        [Advanced(Shader Options)]
        [Enum(UnityEngine.Rendering.CullMode)][Sub(Group1)] _Cull("Cull", Float) = 0                    
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
        [RampTexture][Sub(Group2)] _RampMapCool("Ramp Map (Cool)", 2D) = "white" {}
        [Advanced][RampTexture] _RampMapWarm("Ramp Map (Warm)", 2D) = "white" {}
        [Advanced]_RampCoolWarmLerpFactor("Cool / Warm", Range(0, 1)) = 1

        [Advanced(Specular)]
        [Sub(Group2)]_SpecularColor0("Color", Color) = (1,1,1,1)
        [Advanced]_SpecularShininess0("Shininess", Range(0.1, 500)) = 10
        [Advanced]_SpecularIntensity0("Intensity", Range(0, 100)) = 1
        [Advanced]_SpecularEdgeSoftness0("Edge Softness", Range(0, 1)) = 0.1

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

        [Advanced(Bloom)]
        [Sub(Group2)]_BloomIntensity0("Intensity", Range(0, 2)) = 0.5

        [Advanced(Eye Hair Blend)]
        [Sub(Group2)]_HairBlendAlpha("Hair Alpha", Range(0, 1)) = 0.6

        [Main(Group3, _, off, off)] _group3 ("Outline", float) = 0
        [KeywordEnum(Tangent, Normal)][Sub(Group3)] _OutlineNormal("Normal Source", Float) = 0
        [Sub(Group3)]_OutlineWidth("Width", Range(0,4)) = 1
        [Sub(Group3)]_OutlineZOffset("Z Offset", Float) = 0
        [Sub(Group3)]_OutlineColor0("Color", Color) = (0, 0, 0, 1)

        [Main(Group4, _, off, off)] _group4 ("Shadow", float) = 0
        [Sub(Group4)]_ShadowOffset("Shadow Offset", Range(0, 1)) = 0.6
        [Sub(Group4)]_ShadowIntensity("Shadow Intensity", Range(0, 1)) = 0.6
        [Sub(Group4)]_ShadowColor("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)

        [Main(Group5, _, off, off)] _group5 ("Alpha Dither", float) = 0
        [Sub(Group5)]_DitherAlpha("Alpha", Range(0, 1)) = 1

        // Head Bone
        [HideInInspector] _MMDHeadBoneForward("MMD Head Bone Forward", Vector) = (0, 0, 1, 0)
        [HideInInspector] _MMDHeadBoneUp("MMD Head Bone Up", Vector) = (0, 1, 0, 0)
        [HideInInspector] _MMDHeadBoneRight("MMD Head Bone Right", Vector) = (1, 0, 0, 0)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Geometry+40" 
        }

        Pass
        {
            Name "HairOpaque"

            Stencil
            {
                Ref 7
                ReadMask 1  
                WriteMask 4 
                Comp NotEqual
                Pass Replace
                Fail Keep
            }

            Cull [_Cull]
            ZWrite On

            Blend 0 One Zero, [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 One Zero

            ColorMask RGBA 0
            ColorMask R 1

            HLSLPROGRAM

            #include "Core/NPRHairCore.hlsl"

            #pragma vertex HairVertex
            #pragma fragment HairOpaqueFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _BACKFACEUV2_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

            #define RimLightIsHair

            ENDHLSL
        }

        Pass
        {
            Name "HairOutline"

            Cull Front
            ZTest LEqual
            ZWrite On

            ColorMask RGB 0
            ColorMask 0 1

            HLSLPROGRAM

            #include "Core/NPRHairCore.hlsl"

            #pragma vertex HairOutlineVertex
            #pragma fragment HairOutlineFragment

            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma shader_feature_local_vertex _OUTLINENORMAL_TANGENT _OUTLINENORMAL_NORMAL

            ENDHLSL
        }

        Pass
        {
            Name "HairShadow"

            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            Cull [_Cull]
            ZWrite On
            ZTest LEqual

            ColorMask 0 0
            ColorMask 0 1

            HLSLPROGRAM

            #include "Core/NPRHairCore.hlsl"

            #pragma target 2.0

            #pragma vertex HairShadowVertex
            #pragma fragment HairShadowFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            ENDHLSL
        }

        Pass
        {
            Name "HairDepthOnly"

            Tags
            {
                "LightMode" = "DepthOnly"
            }

            Cull [_Cull]
            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #include "Core/NPRHairCore.hlsl"

            #pragma vertex HairDepthOnlyVertex
            #pragma fragment HairDepthOnlyFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"
    Fallback Off
}
