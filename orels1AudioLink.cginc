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

fixed4 frag(v2f i) : SV_Target
{
    half testh;
    half testw = testh = 0.;
    _AudioTexture.GetDimensions(testw, testh);
    
    float properShift = saturate(floor(_Band - 1) / 4);
    float uvScale = testh > 4 && !_EnableFallback ? 0.0625 : 1;
    float remappedWidth = Remap(i.uv.x, 0, 1, 0, abs(_Width)) * (_Width < 0 ? -1 : 1);
    float2 uv = float2(remappedWidth, _BandMode ? properShift : i.uv.y + properShift);
    if (uvScale < 1)
    {
        uv.y %= 1;
    }
    uv.y *= uvScale;
    if (_EnableFallback)
    {
        float bpmOffset = BPMOffset(_BPM, _Note);
        uv.x -= bpmOffset;
    }
    
    fixed4 audioData = saturate(_AudioTexture.Sample(sampler_AudioGraph_Point_Repeat, uv));
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
        hsv.y = saturate(_Saturation + audioData.x * _SaturationAudioStrength);
        col.rgb = HSVToRGB(hsv);
        col.rgb = lerp(_RimEdge.rgb, col.rgb, lerp(1, ndv, _RimEffect));
        col.a *= clamp(audioData.x, 0.2, 1);
        col.rgb *= _GlobalStrength;
        return col;
    }
    return float4(0, 0, 0, 0);
}
