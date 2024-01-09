#ifndef UNIVERSAL_LK_NPR_DEPTH_INCLUDED
#define UNIVERSAL_LK_NPR_DEPTH_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "NPRRenderHelper.hlsl"

struct NPRDepthOnlyAttributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv1          : TEXCOORD0;
    float2 uv2          : TEXCOORD1;
};

struct NPRDepthOnlyVaryings
{
    float4 positionHCS  : SV_POSITION;
    float3 normalWS     : NORMAL;
    float4 uv           : TEXCOORD0;
};

NPRDepthOnlyVaryings CharDepthOnlyVertex(NPRDepthOnlyAttributes input, float4 mapST)
{
    NPRDepthOnlyVaryings output;

    output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = CombineAndTransformDualFaceUV(input.uv1, input.uv2, mapST);

    return output;
}

float4 CharDepthOnlyFragment(NPRDepthOnlyVaryings input)
{
    return input.positionHCS.z;
}

#endif