#ifndef UNIVERSAL_LK_NPR_HAIR_INCLUDED
#define UNIVERSAL_LK_NPR_HAIR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
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

CBUFFER_START(NPRBodyMaterial)
    float _ModelScale;
    float _AlphaTestThreshold;

    float4 _Color;
    float4 _BackColor;
    float4 _Maps_ST;

    float _RampCoolWarmLerpFactor;

    float4 _SpecularColor0;
    float _SpecularShininess0;
    float _SpecularIntensity0;
    float _SpecularEdgeSoftness0;

    float4 _EmissionColor;
    float _EmissionThreshold;
    float _EmissionIntensity;

    float _BloomIntensity0;

    float _RimIntensity;
    float _RimIntensityBackFace;
    float _RimThresholdMin;
    float _RimThresholdMax;
    float _RimEdgeSoftness;
    float _RimWidth0;
    float4 _RimColor0;
    float _RimDark0;

    float _OutlineWidth;
    float _OutlineZOffset;
    float4 _OutlineColor0;

    float _HairBlendAlpha;

    float _DitherAlpha;

    float4 _MMDHeadBoneForward;
    float4 _MMDHeadBoneUp;
    float4 _MMDHeadBoneRight;

    float _ShadowOffset;
    float _ShadowIntensity;
    float4 _ShadowColor;

    float _RimLightWidth;
    float _MinRange;
    float _MaxRange;
    float _RimSpread;
    float4 _RimCol;
    float _RimLightMask;
CBUFFER_END

NPRBaseVaryings HairVertex(NPRBaseAttributes i)
{
    return GetBaseVertexOut(i, _Maps_ST);
}

float4 BaseHairOpaqueFragment(
    inout NPRBaseVaryings i,
    FRONT_FACE_TYPE isFrontFace)
{
    SetupDualFaceRendering(i.normalWS, i.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    Light light = GetMainLight(i.shadowCoord);

    //LK_DO:Soft Receive Shadow
    #ifdef _MAIN_LIGHT_SHADOWS
        light.shadowAttenuation = MainLightRealtimeShadow(i.shadowCoord);
    #endif

    Directions dirWS = GetWorldSpaceDirections(light, i.positionWS, i.normalWS);

    DiffuseData diffuseData;
    diffuseData.NoL = dirWS.NoL;
    diffuseData.singleMaterial = true;
    diffuseData.rampCoolOrWarm = _RampCoolWarmLerpFactor;

    SpecularData specularData;
    specularData.color = _SpecularColor0.rgb;
    specularData.NoH = dirWS.NoV * (dirWS.NoL > 0);
    specularData.shininess = _SpecularShininess0;
    specularData.edgeSoftness = _SpecularEdgeSoftness0;
    specularData.intensity = _SpecularIntensity0;
    specularData.metallic = 0;

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

    float3 diffuse = GetRampDiffuse(diffuseData, i.color, texColor.rgb, light.color, lightMap,
        TEXTURE2D_ARGS(_RampMapCool, sampler_RampMapCool), TEXTURE2D_ARGS(_RampMapWarm, sampler_RampMapWarm));
    float3 specular = GetSpecular(specularData, texColor.rgb, light.color, lightMap);
    float3 rimLight = GetRimLight(rimData, lightMap, dirWS.N, i.positionSrc, _RimLightMask);
    float3 emission = GetEmission(emissionData, texColor.rgb);

    float3 diffuseAdd = 0;
    float3 specularAdd = 0;
    uint pixelLightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light lightAdd = GetAdditionalLight(lightIndex, i.positionWS);
        Directions dirWSAdd = GetWorldSpaceDirections(lightAdd, i.positionWS, i.normalWS);
        float attenuationAdd = saturate(lightAdd.distanceAttenuation);

        diffuseAdd += GetHalfLambertDiffuse(dirWSAdd.NoL, texColor.rgb, lightAdd.color) * attenuationAdd;

        SpecularData specularDataAdd;
        specularDataAdd.color = _SpecularColor0.rgb;
        specularDataAdd.NoH = dirWSAdd.NoH;
        specularDataAdd.shininess = _SpecularShininess0;
        specularDataAdd.edgeSoftness = _SpecularEdgeSoftness0;
        specularDataAdd.intensity = _SpecularIntensity0;
        specularDataAdd.metallic = 0;
        specularAdd += GetSpecular(specularDataAdd, texColor.rgb, lightAdd.color, lightMap) * attenuationAdd;
    LIGHT_LOOP_END

    // Output
    float4 colorTarget = float4(diffuse + specular + rimLight + emission + diffuseAdd + specularAdd, texColor.a);

    //LK_DO:Soft Receive Shadow
    float4 shadowColor = colorTarget * _ShadowIntensity * _ShadowColor;
    colorTarget = lerp(shadowColor, colorTarget, saturate(light.shadowAttenuation + _ShadowOffset));

    return colorTarget;
}

void HairOpaqueFragment(
    NPRBaseVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC,
    out float4 colorTarget      : SV_Target0,
    out float4 bloomTarget      : SV_Target1)
{
    float4 hairColor = BaseHairOpaqueFragment(i, isFrontFace);

    colorTarget = float4(hairColor.rgb, 1);
    bloomTarget = float4(_BloomIntensity0, 0, 0, 0);
}

NPROutlineVaryings HairOutlineVertex(NPROutlineAttributes i)
{
    VertexPositionInputs vertexInputs = GetVertexPositionInputs(i.positionOS);

    OutlineData outlineData;
    outlineData.modelScale = _ModelScale;
    outlineData.width = _OutlineWidth;
    outlineData.zOffset = _OutlineZOffset;

    return CharOutlineVertex(outlineData, i, vertexInputs, _Maps_ST);
}

float4 HairOutlineFragment(NPROutlineVaryings i) : SV_Target0
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return float4(_OutlineColor0.rgb, 1);
}

NPRShadowVaryings HairShadowVertex(NPRShadowAttributes i)
{
    return CharShadowVertex(i, _Maps_ST);
}

void HairShadowFragment(
    NPRShadowVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC)
{
    SetupDualFaceRendering(i.normalWS, i.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);
}

NPRDepthOnlyVaryings HairDepthOnlyVertex(NPRDepthOnlyAttributes i)
{
    return CharDepthOnlyVertex(i, _Maps_ST);
}

float4 HairDepthOnlyFragment(
    NPRDepthOnlyVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    SetupDualFaceRendering(i.normalWS, i.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return CharDepthOnlyFragment(i);
}

#endif
