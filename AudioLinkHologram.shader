Shader "orels1/AudioLinkHologram"
{
    Properties
    {
        [Header(AUDIO LOOKUP)]
        [Enum(UV, 0, Global, 1)]_BandMode("Band Lookup Mode", Int) = 0
        [IntRange]_Band("Band Selection", Range(1, 4)) = 1
        _Width("Width", Range (-1, 1)) = 1

        [Header(COLORS)]
        [HDR]_Emission("Emission", Color) = (1,1,1,1)
        [HDR]_RimEdge("Rim Darken Color ", Color) = (1,1,1,1)
        _RimEffect("Rim Effect Strength", Range(0,1)) = 1
        _GlobalStrength("Global Strength", Range(0,4)) = 1

        [Header(CUSTOMIZATION)]
        _HueSpeed("Hue Speed", Range(0, 1)) = 0.185
        _HueShift("Hue Shift", Range(0,1)) = 0
        _HueAudioStrength("Hue Audio Strength", Range(0, 1)) = 0
        _Saturation("Saturation", Range(0,1)) = 0.439
        _SaturationAudioStrength("Saturation Audio Strength", Range(0,1)) = 0.446

        [Header(FALLBACK)]
        [ToggleUI]_EnableFallback("Enable Fallback Mode", Float) = 0
        _AudioFallbackTexture("Audio Link Fallback Texture", 2D) = "black" {}
        [IntRange]_BPM("BPM", Range(70, 180)) = 128
        [IntRange]_Note("Note", Range(1,32)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue"="Transparent"
        }
        CGINCLUDE
        #pragma target 4.0
        ENDCG

        Pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }
            Cull Back
            ZWrite On
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 normal : NORMAL;
            };

            SamplerState sampler_AudioGraph_Point_Repeat;
            Texture2D<float4> _AudioTexture;
            int _BandMode;
            float _Band;
            float _Width;
            
            float4 _Emission;
            float4 _RimEdge;
            float _RimEffect;
            float _GlobalStrength;
            
            float _HueSpeed;
            float _HueShift;
            float _HueAudioStrength;
            float _Saturation;
            float _SaturationAudioStrength;
            
            float _EnableFallback;
            sampler2D _AudioFallbackTexture;
            float _BPM;
            float _Note;

            float Remap(float t, float a, float b, float u, float v)
            {
                return ((t - a) / (b - a)) * (v - u) + u;
            }

            float3 HSVToRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            float3 RGBToHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float BPMOffset(float bpm, float note)
            {
                float step = 60 / (bpm * (1 / note));
                float curr = _Time.y % step;
                curr /= step;
                return curr;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = v.normal;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }


            fixed4 frag(v2f i) : SV_Target
            {
                half testw, testh;
                testw = testh = 0.;
                _AudioTexture.GetDimensions(testw, testh);
                
                float properShift = saturate(floor(_Band - 1) / 4);
                float2 uv = float2(i.uv.x * _Width, _BandMode ? properShift : i.uv.y + properShift);
                if (_EnableFallback)
                {
                    float bpmOffset = BPMOffset(_BPM, _Note);
                    uv.x -= bpmOffset;
                }
                
                fixed4 audioData = _AudioTexture.Sample(sampler_AudioGraph_Point_Repeat, uv);
                audioData *= 10;
                fixed4 fallbackData = tex2D(_AudioFallbackTexture, uv) * 10;

                // rim effect
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float4 objViewDir = mul(unity_WorldToObject, float4(worldViewDir, 0.0));
                float ndv = saturate(dot(objViewDir, float4(i.normal, 0)));
                ndv = smoothstep(0.54, 1.35, ndv);

                if (_EnableFallback)
                {
                    audioData.rgb = fallbackData.rgb;
                }

                if ((testw > 16 || _EnableFallback) && _GlobalStrength > 0)
                {
                    float4 col = float4(0, 0, 0, 1);
                    col.rgb = audioData;
                    col *= _Emission;
                    float3 hsv = RGBToHSV(col.rgb);
                    hsv.x += _Time.y * _HueSpeed + _HueShift + audioData.x * _HueAudioStrength;
                    hsv.y = _Saturation + audioData.x * (_SaturationAudioStrength / 10);
                    col.rgb = HSVToRGB(hsv);
                    col.rgb = lerp(_RimEdge.rgb, col.rgb, lerp(1, ndv, _RimEffect));
                    col.a *= clamp(audioData.x, 0.2, 1);
                    col.rgb *= _GlobalStrength;
                    return col;
                }
                return float4(0, 0, 0, 0);
            }
            ENDCG
        }
    }
}
