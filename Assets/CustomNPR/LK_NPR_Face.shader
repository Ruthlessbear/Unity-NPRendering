Shader "BearLibrary/NPR/Face"
{
    Properties
    {
        [HideInInspector]_ModelScale("Model Scale", Float) = 1

        [Main(Group1, _, off, off)] _group1 ("Base Setting", float) = 0
        [Advanced(Shader Options)]
        [Enum(UnityEngine.Rendering.BlendMode)][Sub(Group1)] _SrcBlendAlpha("Src Blend (A)", Float) = 0
        [Advanced][Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha("Dst Blend (A)", Float) = 0
        [Advanced][Space(5)]
        [Advanced][Toggle] _AlphaTest("Alpha Test", Float) = 0
        [Advanced][If(_ALPHATEST_ON)] [Indent] _AlphaTestThreshold("Threshold", Range(0, 1)) = 0.5

        [Advanced(Maps)]
        [SingleLineTextureNoScaleOffset(_Color)] [Sub(Group1)]_MainTex("Albedo", 2D) = "white" {}
        [Advanced][HideInInspector] _Color("Color", Color) = (1, 1, 1, 1)
        [Advanced][SingleLineTextureNoScaleOffset] _FaceMap("Face Map", 2D) = "white" {}
        [Advanced][SingleLineTextureNoScaleOffset] _ExpressionMap("Expression Map", 2D) = "white" {}
        [Advanced][TextureScaleOffset] _Maps_ST("Maps Scale Offset", Vector) = (1, 1, 0, 0)
        [Advanced][Header(Overrides)] [Space(5)]
        [Advanced][If(_MODEL_GAME)] [Toggle] _FaceMapUV2("Face Map Use UV2", Float) = 0

        [Main(Group2, _, off, off)] _group2 ("Shading Setting", float) = 0
        [Advanced(Diffuse)]
        [Sub(Group2)]_ShadowColor("Face Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
        [Advanced]_EyeShadowColor("Eye Shadow Color", Color) = (1, 1, 1, 1)

        [Advanced(Emission)]
        [Sub(Group2)]_EmissionColor("Color", Color) = (1, 1, 1, 1)
        [Advanced]_EmissionThreshold("Threshold", Range(0, 1)) = 0.1
        [Advanced]_EmissionIntensity("Intensity", Float) = 0.3

        [Advanced(Bloom)]
        [Sub(Group2)]_BloomIntensity0("Intensity", Range(0, 2)) = 0.5

        [Main(Group3, _, off, off)] _group3 ("Ourline", float) = 0
        [KeywordEnum(Tangent, Normal)][Sub(Group3)] _OutlineNormal("Normal Source", Float) = 0
        [Sub(Group3)]_OutlineWidth("Width", Range(0, 4)) = 1
        [Sub(Group3)]_OutlineZOffset("Z Offset", Float) = 0
        [Sub(Group3)]_OutlineColor0("Color", Color) = (0, 0, 0, 1)

        [Main(Group4, _, off, off)] _group4 ("Correction Factor", float) = 0
        [Advanced(Nose Line)]
        [Sub(Group4)]_NoseLineColor("Color", Color) = (1, 1, 1, 1)
        [Advanced]_NoseLinePower("Power", Range(0, 8)) = 1

        [Advanced(Eye Hair Blend)]
        [Sub(Group4)]_MaxEyeHairDistance("Max Eye Hair Distance", Float) = 0.1

        [Advanced(Expression)]
        [Sub(Group4)]_ExCheekColor("Cheek Color", Color) = (1, 1, 1, 1)
        [Advanced]_ExCheekIntensity("Cheek Intensity", Range(0, 1)) = 0
        [Advanced][Space(10)]
        [Advanced]_ExShyColor("Shy Color", Color) = (1, 1, 1, 1)
        [Advanced]_ExShyIntensity("Shy Intensity", Range(0, 1)) = 0
        [Advanced][Space(10)]
        [Advanced]_ExShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        [Advanced]_ExEyeColor("Eye Color", Color) = (1, 1, 1, 1)
        [Advanced]_ExShadowIntensity("Shadow Intensity", Range(0, 1)) = 0

        [Main(Group5, _, off, off)] _group5 ("Alpha Dither", float) = 0
        [Sub(Group5)]
        _DitherAlpha("Alpha", Range(0, 1)) = 1

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
            "Queue" = "Geometry" 
        }

        Pass
        {
            Name "FaceOpaque+Z"


            Stencil
            {
                Ref 2
                WriteMask 2
                Comp Always
                Pass Replace
                Fail Keep
            }

            Cull Back
            ZWrite On

            Blend 0 One Zero, [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 One Zero

            ColorMask RGBA 0
            ColorMask R 1

            HLSLPROGRAM

            #pragma vertex FaceVertex
            #pragma fragment FaceOpaqueAndZFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _FACEMAPUV2_ON

            #include "Core/NPRFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "WriteEyeStencil"

            Stencil
            {
                Ref 1
                WriteMask 1
                Comp Always
                Pass Replace
                Fail Keep
                ZFail Keep
            }

            Cull Back
            ZWrite Off
            ZTest LEqual 

            ColorMask 0 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma vertex FaceVertex
            #pragma fragment FaceWriteEyeStencilFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #include "Core/NPRFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceOutline"

            Cull Front
            ZTest LEqual
            ZWrite On

            Blend 0 One Zero, [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 Zero Zero

            ColorMask RGBA 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma vertex FaceOutlineVertex
            #pragma fragment FaceOutlineFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma shader_feature_local_vertex _OUTLINENORMAL_TANGENT _OUTLINENORMAL_NORMAL

            #include "Core/NPRFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceShadow"

            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            Cull Back
            ZWrite On
            ZTest LEqual

            ColorMask 0 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma target 2.0

            #pragma vertex FaceShadowVertex
            #pragma fragment FaceShadowFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Core/NPRFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceDepthOnly"

            Tags
            {
                "LightMode" = "DepthOnly"
            }

            Cull Back
            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex FaceDepthOnlyVertex
            #pragma fragment FaceDepthOnlyFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #include "Core/NPRFaceCore.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"
    Fallback Off
}
