#ifndef UNIVERSAL_LK_NPR_OUTLINE_INCLUDED
#define UNIVERSAL_LK_NPR_OUTLINE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "NPRRenderHelper.hlsl"

struct NPROutlineAttributes
{
    float3 positionOS     : POSITION;

    float3 normalOS       : NORMAL;

#if defined(_OUTLINENORMAL_TANGENT)
    float4 tangentOS      : TANGENT;
#endif

    float4 color          : COLOR;
    float2 uv1            : TEXCOORD0;
    float2 uv2            : TEXCOORD1;
};

struct NPROutlineVaryings
{
    float4 positionHCS    : SV_POSITION;
    float4 uv             : TEXCOORD0;
};

struct OutlineData
{
    float modelScale;
    float width;
    float zOffset;
};

float4 GetOutlinePositionHCS(OutlineData data, float3 positionVS, float3 normalVS, float4 vertexColor)
{
    float outlineWidth = data.width * data.modelScale * 0.0588;

    outlineWidth *= vertexColor.a;

    float fixScale;
    if (IsPerspectiveProjection())
    {
        fixScale = 2.414 / unity_CameraProjection._m11;
    }
    else
    {
        fixScale = 1.5996 / unity_CameraProjection._m11;
    }
    fixScale *= -positionVS.z / data.modelScale;
    outlineWidth *= clamp(fixScale * 0.025, 0.04, 0.1);

    normalVS.z = -0.1;
    positionVS += normalize(normalVS) * outlineWidth;
    positionVS.z += data.zOffset * data.modelScale;
    return TransformWViewToHClip(positionVS);
}



NPROutlineVaryings CharOutlineVertex(
    OutlineData data,
    NPROutlineAttributes input,
    VertexPositionInputs vertexInputs,
    float4 mapST)
{
    NPROutlineVaryings o;
    float3 normalOS = 0;

    #if defined(_OUTLINENORMAL_NORMAL)
        normalOS = input.normalOS;
    #elif defined(_OUTLINENORMAL_TANGENT)
        normalOS = input.tangentOS.xyz;
    #endif

    float3 normalWS = TransformObjectToWorldNormal(normalOS);
    float3 normalVS = TransformWorldToViewNormal(normalWS);

    o.positionHCS = GetOutlinePositionHCS(data, vertexInputs.positionVS, normalVS, input.color);
    o.uv = CombineAndTransformDualFaceUV(input.uv1, input.uv2, mapST);
    return o;
}

float GetCameraFOV()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    float t = unity_CameraProjection._m11;
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
    return fov;
}
float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    return saturate(inputMulFix);
}

float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    float cameraMulFix;
    if(IsPerspectiveProjection())
    {
        cameraMulFix = abs(positionVS_Z);

        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        cameraMulFix *= GetCameraFOV();       
    }
    else
    {
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 50; 
    }

    return cameraMulFix * 0.00005;
}

NPROutlineVaryings ComputeOutlineVertex(
    OutlineData data,
    NPROutlineAttributes input,
    VertexPositionInputs vertexInputs,
    VertexNormalInputs normalInputs,
    float4 mapST
)
{
    NPROutlineVaryings output;
    
    float outlineExpandAmount = data.width * GetOutlineCameraFovAndDistanceFixMultiplier(vertexInputs.positionVS.z);
    #if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED) || defined(UNITY_STEREO_DOUBLE_WIDE_ENABLED)
        outlineExpandAmount *= 0.5;
    #endif
    float3 positionWS = vertexInputs.positionWS + normalInputs.normalWS * outlineExpandAmount;

    output.positionHCS = TransformWorldToHClip(positionWS);
    output.uv = CombineAndTransformDualFaceUV(input.uv1, input.uv2, mapST);

    return output;
}

#endif