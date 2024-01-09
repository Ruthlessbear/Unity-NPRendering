#ifndef UNIVERSAL_LK_NPR_BODY_INCLUDED
#define UNIVERSAL_LK_NPR_BODY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "NPRData.hlsl"
#include "NPROutLine.hlsl"
#include "NPRDepthOnly.hlsl"
#include "NPRShadow.hlsl"

TEXTURE2D(_MainTex); 
SAMPLER(sampler_MainTex);
TEXTURE2D(_LightMap); 
SAMPLER(sampler_LightMap);
TEXTURE2D(_RampMapCool); 
SAMPLER(sampler_RampMapCool);
TEXTURE2D(_RampMapWarm); 
SAMPLER(sampler_RampMapWarm);
TEXTURE2D(_StockingsMap); 
SAMPLER(sampler_StockingsMap);

CBUFFER_START(NPRBodyMaterial)
    float _ModelScale;
    float _AlphaTestThreshold;

    float4 _Color;
    float4 _BackColor;
    float4 _Maps_ST;

    float _RampCoolWarmLerpFactor;

    float4 _SpecularColor;
    float _SpecularMetallic;
    float _SpecularShininess;
    float _SpecularIntensity;
    float _SpecularEdgeSoftness;

    float4 _StockingsMap_ST;
    float4 _StockingsColor;
    float4 _StockingsColorDark;
    float _StockingsDarkWidth;
    float _StockingsPower;
    float _StockingsLightedWidth;
    float _StockingsLightedIntensity;
    float _StockingsRoughness;

    float4 _EmissionColor;
    float _EmissionThreshold;
    float _EmissionIntensity;

    float _OutlineWidth;
    float _OutlineZOffset;
    float4 _OutlineColor;

    float _DitherAlpha;

    float _ShadowOffset;
    float _ShadowIntensity;
    float4 _ShadowColor;

    float _RimLightWidth;
    float _MinRange;
    float _MaxRange;
    float _RimSpread;
    float4 _RimCol;
    float _RimLightMask;

    float _AlphaThreshold;
CBUFFER_END

void ApplyStockings(inout float3 baseColor, float2 uv, float NoV)
{
    // * Modified from °Nya°222's blender shader.
    float4 stockingsMap = SAMPLE_TEXTURE2D(_StockingsMap, sampler_StockingsMap, uv);
    stockingsMap.b = SAMPLE_TEXTURE2D(_StockingsMap, sampler_StockingsMap, TRANSFORM_TEX(uv, _StockingsMap)).b;

    NoV = saturate(NoV);

    float power = max(0.04, _StockingsPower);
    float darkWidth = max(0, _StockingsDarkWidth * power);

    float darkIntensity = (NoV - power) / (darkWidth - power);
    darkIntensity = saturate(darkIntensity * (1 - _StockingsLightedIntensity)) * stockingsMap.r;

    float3 darkColor = lerp(1, _StockingsColorDark.rgb, darkIntensity);
    darkColor = lerp(1, darkColor * baseColor, darkIntensity) * baseColor;

    float lightIntensity = lerp(0.5, 1, stockingsMap.b * _StockingsRoughness);//ramping [0.5, 1]
    lightIntensity *= stockingsMap.g;
    lightIntensity *= _StockingsLightedIntensity;
    lightIntensity *= max(0.004, pow(NoV, _StockingsLightedWidth));

    float3 stockings = lightIntensity * (darkColor + _StockingsColor.rgb) + darkColor;
    baseColor = lerp(baseColor, stockings, step(0.01, stockingsMap.r));
}

NPRBaseVaryings BodyVertex(NPRBaseAttributes input)
{
    return GetBaseVertexOut(input, _Maps_ST);
}

void BodyFragment(NPRBaseVaryings input, out float4 colorTarget : SV_TARGET0)
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
    float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv.xy);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(input.positionHCS, _DitherAlpha);

    float4 specularColor = _SpecularColor;
    float specularMetallic = _SpecularMetallic;
    float specularShininess = _SpecularShininess;
    float specularIntensity = _SpecularIntensity;
    float specularEdgeSoftness = _SpecularEdgeSoftness;

    Light light = GetMainLight(input.shadowCoord);

    //LK_DO:Soft Receive Shadow
    #ifdef _MAIN_LIGHT_SHADOWS
        light.shadowAttenuation = MainLightRealtimeShadow(input.shadowCoord);
    #endif

    Directions dirWS = GetWorldSpaceDirections(light, input.positionWS, input.normalWS);

    ApplyStockings(texColor.rgb, input.uv.xy, dirWS.NoV);

    DiffuseData diffuseData;
    diffuseData.NoL = dirWS.NoL;
    diffuseData.singleMaterial = false;
    diffuseData.rampCoolOrWarm = _RampCoolWarmLerpFactor;

    SpecularData specularData;
    specularData.color = specularColor.rgb;
    specularData.NoH = dirWS.NoH;
    specularData.shininess = specularShininess;
    specularData.edgeSoftness = specularEdgeSoftness;
    specularData.intensity = specularIntensity;
    specularData.metallic = specularMetallic;

    RimData rimData;
    rimData.width = _RimLightWidth;
    rimData.minRange = _MinRange;
    rimData.maxRange = _MaxRange;
    rimData.spread = _RimSpread;
    rimData.rimCol = _RimCol;

    EmissionData emissionData;
    emissionData.color = _EmissionColor.rgb;
    emissionData.value = texColor.a;
    emissionData.threshold = _EmissionThreshold;
    emissionData.intensity = _EmissionIntensity;

    float3 diffuse = GetRampDiffuse(diffuseData, input.color, texColor.rgb, light.color, lightMap,
        TEXTURE2D_ARGS(_RampMapCool, sampler_RampMapCool), TEXTURE2D_ARGS(_RampMapWarm, sampler_RampMapWarm));
    float3 specular = GetSpecular(specularData, texColor.rgb, light.color, lightMap);
    float3 rimLight = GetRimLight(rimData, lightMap, dirWS.N, input.positionSrc, _RimLightMask);
    float3 emission = GetEmission(emissionData, texColor.rgb);

    float3 diffuseAdd = 0;
    float3 specularAdd = 0;
    uint pixelLightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light lightAdd = GetAdditionalLight(lightIndex, input.positionWS);
        Directions dirWSAdd = GetWorldSpaceDirections(lightAdd, input.positionWS, input.normalWS);
        float attenuationAdd = saturate(lightAdd.distanceAttenuation);

        diffuseAdd += GetHalfLambertDiffuse(dirWSAdd.NoL, texColor.rgb, lightAdd.color) * attenuationAdd;

        SpecularData specularDataAdd;
        specularDataAdd.color = specularColor.rgb;
        specularDataAdd.NoH = dirWSAdd.NoH;
        specularDataAdd.shininess = specularShininess;
        specularDataAdd.edgeSoftness = specularEdgeSoftness;
        specularDataAdd.intensity = specularIntensity;
        specularDataAdd.metallic = specularMetallic;
        specularAdd += GetSpecular(specularDataAdd, texColor.rgb, lightAdd.color, lightMap) * attenuationAdd;
    LIGHT_LOOP_END

    colorTarget = float4(diffuse + specular + rimLight + emission + diffuseAdd + specularAdd, texColor.a);

    //LK_DO:Soft Receive Shadow
    float4 shadowColor = colorTarget * _ShadowIntensity * _ShadowColor;
    colorTarget = lerp(shadowColor, colorTarget, saturate(light.shadowAttenuation + _ShadowOffset));
}

NPROutlineVaryings BodyOutlineVertex(NPROutlineAttributes input)
{
    VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs vertexNormalInputs = GetVertexNormalInputs(input.normalOS);

    OutlineData outlineData;
    outlineData.modelScale = _ModelScale;
    outlineData.width = _OutlineWidth;
    outlineData.zOffset = _OutlineZOffset;

    return ComputeOutlineVertex(outlineData, input, vertexInputs, vertexNormalInputs, _Maps_ST);
}

void BodyOutlineFragment(
    NPROutlineVaryings input,
    out float4 colorTarget : SV_TARGET0)
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy) * _Color;
    float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv.xy);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(input.positionHCS, _DitherAlpha);

    float4 outlineColor = _OutlineColor;

    colorTarget = float4(outlineColor.rgb, 1);
}

NPRShadowVaryings BodyShadowVertex(NPRShadowAttributes input)
{
    return CharShadowVertex(input, _Maps_ST);
}

void BodyShadowFragment(
    NPRShadowVaryings input,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC)
{
    SetupDualFaceRendering(input.normalWS, input.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(input.positionHCS, _DitherAlpha);
}


NPRDepthOnlyVaryings BodyDepthOnlyVertex(NPRDepthOnlyAttributes input)
{
    return CharDepthOnlyVertex(input, _Maps_ST);
}

float4 BodyDepthOnlyFragment(
    NPRDepthOnlyVaryings input,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    SetupDualFaceRendering(input.normalWS, input.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(input.positionHCS, _DitherAlpha);

    return CharDepthOnlyFragment(input);
}

#endif