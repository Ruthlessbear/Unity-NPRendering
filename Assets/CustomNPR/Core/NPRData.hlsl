#ifndef UNIVERSAL_LK_NPR_DATA_INCLUDED
#define UNIVERSAL_LK_NPR_DATA_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "NPRRenderHelper.hlsl"

struct NPRBaseAttributes
{
    float3 positionOS     : POSITION;
    float3 normalOS       : NORMAL;
    float4 color          : COLOR;
    float2 uv1            : TEXCOORD0;
    float2 uv2            : TEXCOORD1;
};

struct NPRBaseVaryings
{
    float4 positionHCS    : SV_POSITION;
    float3 normalWS       : NORMAL;
    float4 color          : COLOR;
    float4 uv             : TEXCOORD0;
    float3 positionWS     : TEXCOORD1;
    float4 shadowCoord    : TEXCOORD2;
    float4 positionSrc    : TEXCOORD3;
};

NPRBaseVaryings GetBaseVertexOut(NPRBaseAttributes i, float4 mapST)
{
    NPRBaseVaryings o;

    float3 positionWS = TransformObjectToWorld(i.positionOS);
    o.positionHCS = TransformWorldToHClip(positionWS);
    o.normalWS = TransformObjectToWorldNormal(i.normalOS, true);
    o.color = i.color;
    o.uv = CombineAndTransformDualFaceUV(i.uv1, i.uv2, mapST);
    o.positionWS = positionWS;
    o.positionSrc = ComputeScreenPos(o.positionHCS);

    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
        o.shadowCoord = ComputeScreenPos(o.positionHCS);
    #else
        o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
    #endif


    return o;
}

#endif