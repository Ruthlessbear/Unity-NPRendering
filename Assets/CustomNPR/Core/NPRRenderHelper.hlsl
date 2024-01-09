#ifndef UNIVERSAL_LK_NPR_HELPER_INCLUDED
#define UNIVERSAL_LK_NPR_HELPER_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

float4 CombineAndTransformDualFaceUV(float2 uv1, float2 uv2, float4 mapST)
{
    return float4(uv1, uv2) * mapST.xyxy + mapST.zwzw;
}

void SetupDualFaceRendering(inout float3 normalWS, inout float4 uv, FRONT_FACE_TYPE isFrontFace)
{
    //Discard
    //LK:暂时去了原本的修正
}

float GetLinearEyeDepthAnyProjection(float depth)
{
    if (IsPerspectiveProjection())
    {
        return LinearEyeDepth(depth, _ZBufferParams);
    }

    return LinearDepthToEyeDepth(depth);
}

float GetLinearEyeDepthAnyProjection(float4 svPosition)
{
    return GetLinearEyeDepthAnyProjection(svPosition.z);
}

struct Directions
{
    float3 N;
    float3 V;
    float3 L;
    float3 H;

    float NoL;
    float NoH;
    float NoV;
    float LoH;
};

Directions GetWorldSpaceDirections(Light light, float3 positionWS, float3 normalWS)
{
    Directions dirWS;

    dirWS.N = normalize(normalWS);
    dirWS.V = normalize(GetWorldSpaceViewDir(positionWS));
    dirWS.L = normalize(light.direction);
    dirWS.H = normalize(dirWS.V + dirWS.L);

    dirWS.NoL = dot(dirWS.N, dirWS.L);
    dirWS.NoH = dot(dirWS.N, dirWS.H);
    dirWS.NoV = dot(dirWS.N, dirWS.V);
    dirWS.LoH = dot(dirWS.L, dirWS.H);

    return dirWS;
}

struct HeadDirections
{
    float3 forward;
    float3 right;
    float3 up;
};

HeadDirections GetWorldSpaceCharHeadDirectionsImpl(
    float4 mmdHeadBoneForward,
    float4 mmdHeadBoneUp,
    float4 mmdHeadBoneRight)
{
    HeadDirections dirWS;

    dirWS.forward = normalize(UNITY_MATRIX_M._m01_m11_m21);
    dirWS.right = normalize(-UNITY_MATRIX_M._m02_m12_m22); 
    dirWS.up = normalize(-UNITY_MATRIX_M._m00_m10_m20);

    return dirWS;
}

#define WORLD_SPACE_CHAR_HEAD_DIRECTIONS() \
    GetWorldSpaceCharHeadDirectionsImpl(_MMDHeadBoneForward, _MMDHeadBoneUp, _MMDHeadBoneRight)

// ----------------------------------------------------------------------------------
// NPR
// ----------------------------------------------------------------------------------

float2 GetRampUV(float NoL, bool singleMaterial, float4 vertexColor, float4 lightMap)
{
    float ao = lightMap.g;
    float material = singleMaterial ? 0 : lightMap.a;

    ao *= vertexColor.r;

    float NoL01 = NoL * 0.5 + 0.5;
    float threshold = (NoL01 + ao) * 0.5;
    float shadowStrength = (0.5 - threshold) / 0.5;
    float shadow = 1 - saturate(shadowStrength / 0.5);

    shadow = lerp(0.20, 1, shadow); 
    shadow = lerp(0, shadow, step(0.05, ao)); 
    shadow = lerp(1, shadow, step(ao, 0.95)); 

    return float2(shadow, material + 0.05);
}

struct DiffuseData
{
    float NoL;
    bool singleMaterial;
    float rampCoolOrWarm;
};

struct SpecularData
{
    float3 color;
    float NoH;
    float shininess;
    float edgeSoftness;
    float intensity;
    float metallic;
};

struct EmissionData
{
    float3 color;
    float value;
    float threshold;
    float intensity;
};

struct RimLightData
{
    float3 color;
    float width;
    float edgeSoftness;
    float thresholdMin;
    float thresholdMax;
    float darkenValue;
    float intensityFrontFace;
    float intensityBackFace;
    float modelScale;
    float ditherAlpha;
};

struct RimData
{
	float width;
    float minRange;
    float maxRange;
    float spread;
    float4 rimCol;
};

float3 GetRampDiffuse(
    DiffuseData data,
    float4 vertexColor,
    float3 baseColor,
    float3 lightColor,
    float4 lightMap,
    TEXTURE2D_PARAM(rampMapCool, sampler_rampMapCool),
    TEXTURE2D_PARAM(rampMapWarm, sampler_rampMapWarm))
{
    float2 rampUV = GetRampUV(data.NoL, data.singleMaterial, vertexColor, lightMap);
    float3 rampCool = SAMPLE_TEXTURE2D(rampMapCool, sampler_rampMapCool, rampUV).rgb;
    float3 rampWarm = SAMPLE_TEXTURE2D(rampMapWarm, sampler_rampMapWarm, rampUV).rgb;
    float3 rampColor = lerp(rampCool, rampWarm, data.rampCoolOrWarm);
    return rampColor * baseColor * lightColor;
}

float3 GetHalfLambertDiffuse(float NoL, float3 baseColor, float3 lightColor)
{
    float halfLambert = pow(NoL * 0.5 + 0.5, 2);
    return baseColor * lightColor * halfLambert;
}

float3 GetSpecular(SpecularData data, float3 baseColor, float3 lightColor, float4 lightMap)
{
    float threshold = 1.03 - lightMap.b; 
    float blinnPhong = pow(max(0.01, data.NoH), data.shininess);
    blinnPhong = smoothstep(threshold, threshold + data.edgeSoftness, blinnPhong);

    float3 fresnel = lerp(0.04, baseColor, data.metallic);

    return data.color * fresnel * lightColor * (blinnPhong * lightMap.r * data.intensity);
}

float3 GetEmission(EmissionData data, float3 baseColor)
{
    float emissionMask = 1 - step(data.value, data.threshold);
    return data.color * baseColor * (emissionMask * data.intensity);
}

float LinearEyeDepth(float z)
{
    return 1.0 / (_ZBufferParams.z * z + _ZBufferParams.w);
}

float3 GetRimLight(RimData rimData, float4 lightMap, float3 normalWS, float4 screenPos, float lightMapMask)
{
    float nWS = normalize(normalWS);
    float3 normalVS = TransformWorldToViewNormal(nWS);
    float2 scrPos = screenPos.xy / screenPos.w;
    scrPos += normalVS * rimData.width * 0.001;
    float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos).r;
    float depth = LinearEyeDepth(depthTex);
    float rim = saturate(depth - screenPos.w) / max(0.001, rimData.spread * 0.01);
    rim = smoothstep(min(rimData.minRange, 0.99), rimData.maxRange, rim);

    if(lightMapMask)
        return rim * rimData.rimCol * lightMap.r;
    else
        return rim * rimData.rimCol;
}

void DoDitherAlphaEffect(float4 svPosition, float ditherAlpha)
{
    static const float4 thresholds[4] =
    {
        float4(01.0 / 17.0, 09.0 / 17.0, 03.0 / 17.0, 11.0 / 17.0),
        float4(13.0 / 17.0, 05.0 / 17.0, 15.0 / 17.0, 07.0 / 17.0),
        float4(04.0 / 17.0, 12.0 / 17.0, 02.0 / 17.0, 10.0 / 17.0),
        float4(16.0 / 17.0, 08.0 / 17.0, 14.0 / 17.0, 06.0 / 17.0)
    };

    uint xIndex = fmod(svPosition.x - 0.5, 4);
    uint yIndex = fmod(svPosition.y - 0.5, 4);
    clip(ditherAlpha - thresholds[yIndex][xIndex]);
}

void DoAlphaClip(float alpha, float cutoff)
{
    #if defined(_ALPHATEST_ON)
        clip(alpha - cutoff);
    #endif
}

#endif