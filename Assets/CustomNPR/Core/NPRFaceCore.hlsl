#ifndef _CHAR_FACE_CORE_INCLUDED
#define _CHAR_FACE_CORE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "NPRData.hlsl"
#include "NPRDepthOnly.hlsl"
#include "NPROutLine.hlsl"
#include "NPRShadow.hlsl"

TEXTURE2D(_MainTex); 
SAMPLER(sampler_MainTex);
TEXTURE2D(_FaceMap); 
SAMPLER(sampler_FaceMap);
TEXTURE2D(_ExpressionMap); 
SAMPLER(sampler_ExpressionMap);

CBUFFER_START(UnityPerMaterial)
    float _ModelScale;
    float _AlphaTestThreshold;

    float4 _Color;
    float4 _Maps_ST;

    float4 _ShadowColor;
    float4 _EyeShadowColor;

    float4 _EmissionColor;
    float _EmissionThreshold;
    float _EmissionIntensity;

    float _BloomIntensity0;

    float _OutlineWidth;
    float _OutlineZOffset;
    float4 _OutlineColor0;

    float4 _NoseLineColor;
    float _NoseLinePower;

    float _MaxEyeHairDistance;

    float4 _ExCheekColor;
    float _ExCheekIntensity;
    float4 _ExShyColor;
    float _ExShyIntensity;
    float4 _ExShadowColor;
    float4 _ExEyeColor;
    float _ExShadowIntensity;

    float _DitherAlpha;

    float4 _MMDHeadBoneForward;
    float4 _MMDHeadBoneUp;
    float4 _MMDHeadBoneRight;
CBUFFER_END

NPRBaseVaryings FaceVertex(NPRBaseAttributes i)
{
    return GetBaseVertexOut(i, _Maps_ST);
}

float GetSDFFaceAttenuation(float2 uv, Directions dirWS)
{
   float right_sampler = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, float2(-uv.x, uv.y));
   float left_sampler = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, uv);
   float3 rightDir = normalize(TransformObjectToWorldDir(float3(1, 0, 0)));
   float3 forwardDir = normalize(TransformObjectToWorldDir(float3(0, 0, 1)));
   float3 lightDir = -normalize(dirWS.L);
   lightDir = normalize(float3(lightDir.x, 0, lightDir.z));
   float fdl = dot(forwardDir.xz, lightDir.xz) * 0.5 + 0.5;
   float rdl = dot(rightDir.xz, lightDir.xz);
   float sampler_threshold = lerp(left_sampler, right_sampler, step(rdl, 0));
   float shadow_attenuation = lerp(1, 0, fdl > sampler_threshold);
   return shadow_attenuation;
}

float3 GetFaceOrEyeDiffuse(
    Directions dirWS,
    HeadDirections headDirWS,
    float4 uv,
    float3 baseColor,
    float3 lightColor,
    float4 faceMap)
{
    float3 lightDirProj = normalize(dirWS.L - dot(dirWS.L, headDirWS.up) * headDirWS.up);

    bool isRight = dot(lightDirProj, headDirWS.right) > 0;
    float2 sdfUV = isRight ? float2(1 - uv.x, uv.y) : uv.xy;
    float threshold = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, sdfUV).a;

    float FoL01 = dot(headDirWS.forward, lightDirProj) * 0.5 + 0.5;
    float3 faceShadow = lerp(_ShadowColor.rgb, 1, step(1 - threshold, FoL01)); // SDF Shadow
    float3 eyeShadow = lerp(_EyeShadowColor.rgb, 1, smoothstep(0.3, 0.5, FoL01));

    float shadowAttenuation = GetSDFFaceAttenuation(uv.zw, dirWS);

    float3 result_color = baseColor * lightColor * lerp(faceShadow, eyeShadow, faceMap.r);

    return lerp(result_color * _ShadowColor, result_color, shadowAttenuation);
}

void FaceOpaqueAndZFragment(
    NPRBaseVaryings i,
    out float4 colorTarget : SV_Target0,
    out float4 bloomTarget : SV_Target1)
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    float4 faceMap = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, i.uv.zw);
    float4 exprMap = SAMPLE_TEXTURE2D(_ExpressionMap, sampler_ExpressionMap, i.uv.zw);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    Light light = GetMainLight();
    Directions dirWS = GetWorldSpaceDirections(light, i.positionWS, i.normalWS);
    HeadDirections headDirWS = WORLD_SPACE_CHAR_HEAD_DIRECTIONS();

    // Nose Line
    float3 FdotV = pow(abs(dot(headDirWS.forward, dirWS.V)), _NoseLinePower);
    texColor.rgb = lerp(texColor.rgb, texColor.rgb * _NoseLineColor.rgb, step(1.03 - faceMap.b, FdotV));

    // Expression
    float3 exCheek = lerp(texColor.rgb, texColor.rgb * _ExCheekColor.rgb, exprMap.r);
    texColor.rgb = lerp(texColor.rgb, exCheek, _ExCheekIntensity);
    float3 exShy = lerp(texColor.rgb, texColor.rgb * _ExShyColor.rgb, exprMap.g);
    texColor.rgb = lerp(texColor.rgb, exShy, _ExShyIntensity);
    float3 exShadow = lerp(texColor.rgb, texColor.rgb * _ExShadowColor.rgb, exprMap.b);
    texColor.rgb = lerp(texColor.rgb, exShadow, _ExShadowIntensity);
    float3 exEyeShadow = lerp(texColor.rgb, texColor.rgb * _ExEyeColor.rgb, faceMap.r);
    texColor.rgb = lerp(texColor.rgb, exEyeShadow, _ExShadowIntensity);

    // Diffuse
    float3 diffuse = GetFaceOrEyeDiffuse(dirWS, headDirWS, i.uv, texColor.rgb, light.color, faceMap);

    EmissionData emissionData;
    emissionData.color = _EmissionColor.rgb;
    emissionData.value = texColor.a;
    emissionData.threshold = _EmissionThreshold;
    emissionData.intensity = _EmissionIntensity;

    float3 emission = GetEmission(emissionData, texColor.rgb);

    float3 diffuseAdd = 0;
    uint pixelLightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light lightAdd = GetAdditionalLight(lightIndex, i.positionWS);
        Directions dirWSAdd = GetWorldSpaceDirections(lightAdd, i.positionWS, i.normalWS);
        float attenuationAdd = saturate(lightAdd.distanceAttenuation);
        diffuseAdd += GetHalfLambertDiffuse(dirWSAdd.NoL, texColor.rgb, lightAdd.color) * attenuationAdd;
    LIGHT_LOOP_END

    // Output
    colorTarget = float4(diffuse + emission + diffuseAdd, texColor.a);
    bloomTarget = float4(_BloomIntensity0, 0, 0, 0);
}

void FaceWriteEyeStencilFragment(NPRBaseVaryings i)
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    float sceneDepth = GetLinearEyeDepthAnyProjection(LoadSceneDepth(i.positionHCS.xy - 0.5));
    float eyeDepth = GetLinearEyeDepthAnyProjection(i.positionHCS);
    float depthMask = step(abs(sceneDepth - eyeDepth), _MaxEyeHairDistance * _ModelScale);

    float eyeMask = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, i.uv.xy).g;

    clip(eyeMask * depthMask - 0.5);
}

NPROutlineVaryings FaceOutlineVertex(NPROutlineAttributes i)
{
    VertexPositionInputs vertexInputs = GetVertexPositionInputs(i.positionOS);

    OutlineData outlineData;
    outlineData.modelScale = _ModelScale;
    outlineData.width = _OutlineWidth;
    outlineData.zOffset = _OutlineZOffset;

    #if defined(_MODEL_GAME)
        HeadDirections headDirWS = WORLD_SPACE_CHAR_HEAD_DIRECTIONS();

        float3 viewDirWS = normalize(GetWorldSpaceViewDir(vertexInputs.positionWS));
        float FdotV = pow(max(0, dot(headDirWS.forward, viewDirWS)), 0.8);
        outlineData.width *= smoothstep(-0.05, 0, 1 - FdotV - i.color.b);
    #endif

    return CharOutlineVertex(outlineData, i, vertexInputs, _Maps_ST);
}

float4 FaceOutlineFragment(NPROutlineVaryings i) : SV_Target0
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return float4(_OutlineColor0.rgb, 1);
}

NPRShadowVaryings FaceShadowVertex(NPRShadowAttributes i)
{
    return CharShadowVertex(i, _Maps_ST);
}

void FaceShadowFragment(NPRShadowVaryings i)
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);
}

NPRDepthOnlyVaryings FaceDepthOnlyVertex(NPRDepthOnlyAttributes i)
{
    return CharDepthOnlyVertex(i, _Maps_ST);
}

float4 FaceDepthOnlyFragment(NPRDepthOnlyVaryings i) : SV_Target
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DoDitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return CharDepthOnlyFragment(i);
}

#endif
