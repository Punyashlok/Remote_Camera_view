Shader "Video/YUVFeedShader(unlit)-Skybox"
{
    Properties{
        _Tint("Tint Color", Color) = (.5, .5, .5, .5)
        [Gamma] _Exposure("Exposure", Range(0, 8)) = 1.0
        _Rotation("Rotation", Range(0, 360)) = 0
        [NoScaleOffset] _MainTex("Spherical  (HDR)", 2D) = "grey" {}
        [KeywordEnum(6 Frames Layout, Latitude Longitude Layout)] _Mapping("Mapping", Float) = 1
        [Enum(360 Degrees, 0, 180 Degrees, 1)] _ImageType("Image Type", Float) = 0
        [Toggle] _MirrorOnBack("Mirror on Back", Float) = 0
        [Enum(None, 0, Side by Side, 1, Over Under, 2)] _Layout("3D Layout", Float) = 0

        [Toggle(MIRROR)] _Mirror("Horizontal Mirror", Float) = 0
        [HideInEditor][NoScaleOffset] _YPlane("Y plane", 2D) = "black" {}
        [HideInEditor][NoScaleOffset] _UPlane("U plane", 2D) = "gray" {}
        [HideInEditor][NoScaleOffset] _VPlane("V plane", 2D) = "gray" {}
    }

        SubShader{
            Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
            Cull Off ZWrite Off

            Pass {

                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #pragma multi_compile_local __ _MAPPING_6_FRAMES_LAYOUT

                #include "UnityCG.cginc"

                sampler2D _MainTex;
                sampler2D _YPlane;
                sampler2D _UPlane;
                sampler2D _VPlane;

                float4 _MainTex_TexelSize;
                half4 _MainTex_HDR;
                half4 _Tint;
                half _Exposure;
                float _Rotation;
//#ifndef _MAPPING_6_FRAMES_LAYOUT
                bool _MirrorOnBack;
                int _ImageType;
                int _Layout;
//#endif    
//#ifndef _MAPPING_6_FRAMES_LAYOUT
                inline float2 ToRadialCoords(float3 coords)
                {
                    float3 normalizedCoords = normalize(coords);
                    float latitude = acos(normalizedCoords.y);
                    float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
                    float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / UNITY_PI, 1.0 / UNITY_PI);
                    return float2(0.5, 1.0) - sphereCoords;
                }
//#endif

                half3 yuv2rgb(half3 yuv)
                {
                    // The YUV to RBA conversion, please refer to: http://en.wikipedia.org/wiki/YUV
                    // Y'UV420p (I420) to RGB888 conversion section.
                    half y_value = yuv[0];
                    half u_value = yuv[1];
                    half v_value = yuv[2];
                    half r = y_value + 1.370705 * (v_value - 0.5);
                    half g = y_value - 0.698001 * (v_value - 0.5) - (0.337633 * (u_value - 0.5));
                    half b = y_value + 1.732446 * (u_value - 0.5);
                    return half3(r, g, b);
                }

                float3 RotateAroundYInDegrees(float3 vertex, float degrees)
                {
                    float alpha = degrees * UNITY_PI / 180.0;
                    float sina, cosa;
                    sincos(alpha, sina, cosa);
                    float2x2 m = float2x2(cosa, -sina, sina, cosa);
                    return float3(mul(m, vertex.xz), vertex.y).xzy;
                }

                struct appdata_t {
                    float4 vertex : POSITION;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct v2f {
                    float4 vertex : SV_POSITION;
                    float3 texcoord : TEXCOORD0;
                    float2 image180ScaleAndCutoff : TEXCOORD1;
                    float4 layout3DScaleAndOffset : TEXCOORD2;

                    UNITY_VERTEX_OUTPUT_STEREO
                };

                v2f vert(appdata_t v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
                    o.vertex = UnityObjectToClipPos(rotated);
                    o.texcoord = v.vertex.xyz;
                    // Calculate constant horizontal scale and cutoff for 180 (vs 360) image type
                    if (_ImageType == 0)  // 360 degree
                        o.image180ScaleAndCutoff = float2(1.0, 1.0);
                    else  // 180 degree
                        o.image180ScaleAndCutoff = float2(2.0, _MirrorOnBack ? 1.0 : 0.5);
                    // Calculate constant scale and offset for 3D layouts
                    if (_Layout == 0) // No 3D layout
                        o.layout3DScaleAndOffset = float4(0,0,1,1);
                    else if (_Layout == 1) // Side-by-Side 3D layout
                        o.layout3DScaleAndOffset = float4(unity_StereoEyeIndex,0,0.5,1);
                    else // Over-Under 3D layout
                        o.layout3DScaleAndOffset = float4(0, 1 - unity_StereoEyeIndex,1,0.5);
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    float2 tc = ToRadialCoords(-i.texcoord);
                    if (tc.x > i.image180ScaleAndCutoff[1])
                        return half4(0,0,0,1);
                    tc.x = fmod(tc.x * i.image180ScaleAndCutoff[0], 1);
                    tc = (tc + i.layout3DScaleAndOffset.xy) * i.layout3DScaleAndOffset.zw;

                    // display _MainTex
                    //half4 tex = tex2D(_MainTex, tc);
                    //half3 c = DecodeHDR(tex, _MainTex_HDR);
                    //c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                    //c *= _Exposure;
                    //return half4(c, 1);

                    // display YUV planes
                    half3 yuv;
                    yuv.x = tex2D(_YPlane, tc).r;
                    yuv.y = tex2D(_UPlane, tc).r;
                    yuv.z = tex2D(_VPlane, tc).r;
                    half3 rgb = yuv2rgb(yuv);
                    half4 tex2 = half4(rgb, 1);
                    half3 c = DecodeHDR(tex2, _MainTex_HDR);
                    c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                    c *= _Exposure;

                    return half4(c, 1);
                }
                ENDCG
            }
        }

            CustomEditor "SkyboxPanoramicShaderGUI"
                    Fallback Off
}