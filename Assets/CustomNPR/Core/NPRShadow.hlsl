#ifndef UNIVERSAL_LK_NPR_SHADOW_INCLUDE
#define UNIVERSAL_LK_NPR_SHADOW_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "NPRRenderHelper.hlsl"

float3 _LightDirection;
float3 _LightPosition;

struct NPRShadowAttributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv1          : TEXCOORD0;
    float2 uv2          : TEXCOORD1;
};

struct NPRShadowVaryings
{
    float4 positionHCS  : SV_POSITION;
    float3 normalWS     : NORMAL;
    float4 uv           : TEXCOORD0;
};

float4 GetShadowPositionHClip(NPRShadowAttributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

NPRShadowVaryings CharShadowVertex(NPRShadowAttributes input, float4 mapST)
{
    NPRShadowVaryings o;

    o.positionHCS = GetShadowPositionHClip(input);
    o.normalWS = TransformObjectToWorldNormal(input.normalOS);
    o.uv = CombineAndTransformDualFaceUV(input.uv1, input.uv2, mapST);

    return o;
}

#endif