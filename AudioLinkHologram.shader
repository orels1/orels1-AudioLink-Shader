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

            #include "orels1AudioLink.cginc"

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = v.normal;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }
            ENDCG
        }
    }
}
