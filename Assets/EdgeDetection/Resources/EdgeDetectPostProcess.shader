Shader "Hidden/EdgeDetect"
{
	HLSLINCLUDE

		#pragma multi_compile _ APPLY_FOG
		#pragma multi_compile __ FOG_LINEAR FOG_EXP FOG_EXP2

		#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
		#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Builtins/Fog.hlsl"

		// Functions and macros from UnityCG, because we can't include it here (causes duplicates from StdLib)
		// Copied from UnityCG.cginc v2017.1.0f3

		inline float DecodeFloatRG( float2 enc )
		{
			float2 kDecodeDot = float2(1.0, 1/255.0);
			return dot( enc, kDecodeDot );
		}

		#if !defined(SHADER_TARGET_GLSL) && !defined(SHADER_API_PSSL) && !defined(SHADER_API_GLES3) && !defined(SHADER_API_VULKAN) && !(defined(SHADER_API_METAL) && defined(UNITY_COMPILER_HLSLCC))
			#define sampler2D_float sampler2D
		#endif

		#undef SAMPLE_DEPTH_TEXTURE
		#if defined(SHADER_API_PSP2)
			half4 SAMPLE_DEPTH_TEXTURE(sampler2D s, float4 uv) { return tex2D<float>(s, (float3)uv); }
			half4 SAMPLE_DEPTH_TEXTURE(sampler2D s, float3 uv) { return tex2D<float>(s, uv); }
			half4 SAMPLE_DEPTH_TEXTURE(sampler2D s, float2 uv) { return tex2D<float>(s, uv); }
		#else
			#define SAMPLE_DEPTH_TEXTURE(sampler, uv) (tex2D(sampler, uv).r)
		#endif

		//--------------------------------------------------------------------------------------------------------------------------------

		// Source image
		TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
		float4 _MainTex_ST;
		float4 _MainTex_TexelSize;

		// Camera Depth/Normals
		sampler2D _CameraDepthNormalsTexture;
		half4 _CameraDepthNormalsTexture_ST;
		sampler2D_float _CameraDepthTexture;
		half4 _CameraDepthTexture_ST;

		// Settings
		half4 _Sensitivity; 
		half4 _BgColor;
		half _BgFade;
		half _SampleDistance;
		float _Exponent;
		float _Threshold;
		half4 _EdgesColor;

		//--------------------------------------------------------------------------------------------------------------------------------

		struct Varyings
		{
			float4 vertex : SV_POSITION;
			float2 texcoord[5] : TEXCOORD0;
			float2 texcoordStereo : TEXCOORD5;
		};

		struct VaryingsThin {
			float4 vertex : SV_POSITION;
			float2 texcoord[3] : TEXCOORD0;
			float2 texcoordStereo : TEXCOORD3;
		};

		struct VaryingsD
		{
			float4 vertex : SV_POSITION;
			float2 texcoord[2] : TEXCOORD0;
			float2 texcoordStereo : TEXCOORD2;
		};

		struct VaryingsLum
		{
			float4 vertex : SV_POSITION;
			float2 texcoord[4] : TEXCOORD0;
			float2 texcoordStereo : TEXCOORD4;
		};

		//--------------------------------------------------------------------------------------------------------------------------------

		inline half CheckSame (half2 centerNormal, float centerDepth, half4 theSample)
		{
			// Difference in normals
			// do not bother decoding normals - there's no need here
			half2 diff = abs(centerNormal - theSample.xy) * _Sensitivity.y;
			half isSameNormal = 1 - step(0.1, (diff.x + diff.y) * _Sensitivity.y);
			// Difference in depth
			float sampleDepth = DecodeFloatRG (theSample.zw);
			float zdiff = abs(centerDepth-sampleDepth);
			// Scale the required threshold by the distance
			half isSameDepth = 1 - step(0.09 * centerDepth, zdiff * _Sensitivity.x);
			
			// return:
			// 1 - if normals and depth are similar enough
			// 0 - otherwise
			return (isSameNormal * isSameDepth);
		}

		//--------------------------------------------------------------------------------------------------------------------------------

		Varyings VertRobert(AttributesDefault v)
		{
			Varyings o;

			o.vertex = float4(v.vertex.xy, 0.0, 1.0);
			float2 texcoord = TransformTriangleVertexToUV(v.vertex.xy);

		#if UNITY_UV_STARTS_AT_TOP
			texcoord = texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
		#endif
			
			o.texcoordStereo = TransformStereoScreenSpaceTex(texcoord, 1.0);
			o.texcoord[0] = UnityStereoScreenSpaceUVAdjust(texcoord, _MainTex_ST);
			
			o.texcoord[1] = UnityStereoScreenSpaceUVAdjust(texcoord + _MainTex_TexelSize.xy * half2(1,1) * _SampleDistance, _MainTex_ST);
			o.texcoord[2] = UnityStereoScreenSpaceUVAdjust(texcoord + _MainTex_TexelSize.xy * half2(-1,-1) * _SampleDistance, _MainTex_ST);
			o.texcoord[3] = UnityStereoScreenSpaceUVAdjust(texcoord + _MainTex_TexelSize.xy * half2(-1,1) * _SampleDistance, _MainTex_ST);
			o.texcoord[4] = UnityStereoScreenSpaceUVAdjust(texcoord + _MainTex_TexelSize.xy * half2(1,-1) * _SampleDistance, _MainTex_ST);

			return o;
		}

		float4 FragRobert(Varyings i) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[0]);

			half4 center = tex2D(_CameraDepthNormalsTexture, i.texcoord[0].xy);
			half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.texcoord[1].xy);
			half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.texcoord[2].xy);
			half4 sample3 = tex2D(_CameraDepthNormalsTexture, i.texcoord[3].xy);
			half4 sample4 = tex2D(_CameraDepthNormalsTexture, i.texcoord[4].xy);

			half edge = 1.0;
			edge *= CheckSame(sample1.xy, DecodeFloatRG(sample1.zw), sample2);
			edge *= CheckSame(sample3.xy, DecodeFloatRG(sample3.zw), sample4);

			half fog = 0.0;
		#if (APPLY_FOG)
			float d = DecodeFloatRG(center.zw);
			d = ComputeFogDistance(d);
			fog = 1.0 - ComputeFog(d);
		#endif

			color = lerp(lerp(_EdgesColor, _FogColor, fog), lerp(color, _BgColor, _BgFade), edge);
			return color;
		}

		//--------------------------------------------------------------------------------------------------------------------------------

		VaryingsThin VertThin(AttributesDefault v)
		{
			VaryingsThin o;

			o.vertex = float4(v.vertex.xy, 0.0, 1.0);
			float2 texcoord = TransformTriangleVertexToUV(v.vertex.xy);

		#if UNITY_UV_STARTS_AT_TOP
			texcoord = texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
		#endif
			
			o.texcoordStereo = TransformStereoScreenSpaceTex(texcoord, 1.0);
			o.texcoord[0] = UnityStereoScreenSpaceUVAdjust(texcoord, _MainTex_ST);
			
			// Offsets for two additional samples
			o.texcoord[1] = UnityStereoScreenSpaceUVAdjust(texcoord + float2(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _SampleDistance, _MainTex_ST);
			o.texcoord[2] = UnityStereoScreenSpaceUVAdjust(texcoord + float2(+_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _SampleDistance, _MainTex_ST);

			return o;
		}

		float4 FragThin(VaryingsThin i) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[0]);

			half4 center = tex2D(_CameraDepthNormalsTexture, i.texcoord[0]);
			half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.texcoord[1]);
			half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.texcoord[2]);
			
			// Encoded normal
			half2 centerNormal = center.xy;
			// Decoded depth
			float centerDepth = DecodeFloatRG(center.zw);
			
			half edge = 1.0;
			edge *= CheckSame(centerNormal, centerDepth, sample1);
			edge *= CheckSame(centerNormal, centerDepth, sample2);
			
			half fog = 0.0;
		#if (APPLY_FOG)
			float d = DecodeFloatRG(center.zw);
			d = ComputeFogDistance(d);
			fog = 1.0 - ComputeFog(d);
		#endif

			color = lerp(lerp(_EdgesColor, _FogColor, fog), lerp(color, _BgColor, _BgFade), edge);

			return color;
		}

		//--------------------------------------------------------------------------------------------------------------------------------

		VaryingsD VertD(AttributesDefault v)
		{
			VaryingsD o;

			o.vertex = float4(v.vertex.xy, 0.0, 1.0);
			float2 texcoord = TransformTriangleVertexToUV(v.vertex.xy);

		#if UNITY_UV_STARTS_AT_TOP
			texcoord = texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
		#endif
			
			o.texcoordStereo = TransformStereoScreenSpaceTex(texcoord, 1.0);
			o.texcoord[0] = UnityStereoScreenSpaceUVAdjust(texcoord, _MainTex_ST);
			o.texcoord[1] = texcoord;

			return o;
		}

		float4 FragD(VaryingsD i) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[0]);

		#if defined(FRAGD_CHEAP)
			float centerDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.texcoord[1]));
		#else
			float centerDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1], _CameraDepthTexture_ST)));
		#endif
			
			float4 depthsDiag;
			float4 depthsAxis;

			float2 uvDist = _SampleDistance * _MainTex_TexelSize.xy;

			depthsDiag.x = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]+uvDist, _CameraDepthTexture_ST))); // TR
			depthsDiag.y = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]+uvDist*float2(-1,1), _CameraDepthTexture_ST))); // TL
			depthsDiag.z = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]-uvDist*float2(-1,1), _CameraDepthTexture_ST))); // BR
			depthsDiag.w = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]-uvDist, _CameraDepthTexture_ST))); // BL

			depthsAxis.x = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]+uvDist*float2(0,1), _CameraDepthTexture_ST))); // T
			depthsAxis.y = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]-uvDist*float2(1,0), _CameraDepthTexture_ST))); // L
			depthsAxis.z = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]+uvDist*float2(1,0), _CameraDepthTexture_ST))); // R
			depthsAxis.w = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[1]-uvDist*float2(0,1), _CameraDepthTexture_ST))); // B

		#if !defined(FRAGD_CHEAP)
			// Make it work nicely with depth based image effects such as depth of field:
			depthsDiag = (depthsDiag > centerDepth.xxxx) ? depthsDiag : centerDepth.xxxx;
			depthsAxis = (depthsAxis > centerDepth.xxxx) ? depthsAxis : centerDepth.xxxx;
		#endif
			
			depthsDiag -= centerDepth;
			depthsAxis /= centerDepth;

			const float4 HorizDiagCoeff = float4(1,1,-1,-1);
			const float4 VertDiagCoeff = float4(-1,1,-1,1);
			const float4 HorizAxisCoeff = float4(1,0,0,-1);
			const float4 VertAxisCoeff = float4(0,1,-1,0);

			float4 SobelH = depthsDiag * HorizDiagCoeff + depthsAxis * HorizAxisCoeff;
			float4 SobelV = depthsDiag * VertDiagCoeff + depthsAxis * VertAxisCoeff;

			float SobelX = dot(SobelH, float4(1,1,1,1));
			float SobelY = dot(SobelV, float4(1,1,1,1));
			float Sobel = sqrt(SobelX * SobelX + SobelY * SobelY);

			half fog = 0.0;
		#if (APPLY_FOG)
			float d = ComputeFogDistance(centerDepth);
			fog = 1.0 - ComputeFog(d);
		#endif

			Sobel = 1.0-pow(saturate(Sobel), _Exponent);
			color = lerp(lerp(_EdgesColor, _FogColor, fog), lerp(color, _BgColor, _BgFade), Sobel);
			return color;
		}

		//--------------------------------------------------------------------------------------------------------------------------------

		VaryingsLum VertLum(AttributesDefault v)
		{
			VaryingsLum o;

			o.vertex = float4(v.vertex.xy, 0.0, 1.0);
			float2 texcoord = TransformTriangleVertexToUV(v.vertex.xy);

		#if UNITY_UV_STARTS_AT_TOP
			texcoord = texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
		#endif
			
			o.texcoordStereo = TransformStereoScreenSpaceTex(texcoord, 1.0);

			o.texcoord[0] = UnityStereoScreenSpaceUVAdjust(texcoord, _MainTex_ST);
			o.texcoord[1] = UnityStereoScreenSpaceUVAdjust(texcoord + float2(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _SampleDistance, _MainTex_ST);
			o.texcoord[2] = UnityStereoScreenSpaceUVAdjust(texcoord + float2(+_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _SampleDistance, _MainTex_ST);
			o.texcoord[3] = texcoord;

			return o;
		}

		float4 FragLum(VaryingsLum i) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[0]);

		#if defined(FRAGD_CHEAP)
			float centerDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.texcoord[3]));
		#else
			float centerDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoScreenSpaceUVAdjust(i.texcoord[3], _CameraDepthTexture_ST)));
		#endif

			// A very simple cross gradient filter
			half3 p1 = color.rgb;
			half3 p2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[1]).rgb;
			half3 p3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[2]).rgb;
			
			half3 diff = p1 * 2 - p2 - p3;
			half len = dot(diff, diff);
			len = step(len, _Threshold);

			half fog = 0.0;
		#if (APPLY_FOG)
			float d = ComputeFogDistance(centerDepth);
			fog = 1.0 - ComputeFog(d);
		#endif

			color = lerp(lerp(_EdgesColor, _FogColor, fog), lerp(color, _BgColor, _BgFade), len);
			return color;
		}

	ENDHLSL
	
	//--------------------------------------------------------------------------------------------------------------------------------

	Subshader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass // 1 - Triangle Depth Normals
		{
			HLSLPROGRAM
				#pragma vertex VertThin
				#pragma fragment FragThin
			ENDHLSL
		}

		Pass // 2 - Roberts Cross Depth Normals
		{
			HLSLPROGRAM
				#pragma vertex VertRobert
				#pragma fragment FragRobert
			ENDHLSL
		}
			
		Pass // 3 - Sobel Depth
		{
			HLSLPROGRAM
				#pragma multi_compile FRAGD_CHEAP
				#pragma vertex VertD
				#pragma fragment FragD
			ENDHLSL
		}

		Pass // 4 - Sobel Depth Thin
		{
			HLSLPROGRAM
				#pragma vertex VertD
				#pragma fragment FragD
			ENDHLSL
		}

		Pass // 5 - Triangle Luminance
		{
			HLSLPROGRAM
				#pragma vertex VertLum
				#pragma fragment FragLum
			ENDHLSL
		}
	}

	Fallback off
}