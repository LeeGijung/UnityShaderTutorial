// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShaderTutorial/anisotropic_specular" {
	Properties {
		//SPECULAR
		_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
		_Smoothness ("Smoothness", Float) = 0.2
		_AnisoBrush ("Anisotropic Spread", Range(0.0,2)) = 1.0
    }

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
			#include "Lighting.cginc"

            // exactly the same as in previous shader
            struct v2f {
                float3 worldPos : TEXCOORD0;
                half3 tspace0 : TEXCOORD1;
                half3 tspace1 : TEXCOORD2;
                half3 tspace2 : TEXCOORD3;
                float2 uv : TEXCOORD4;
                float3 worldNormal : TEXCOORD5;
                float4 pos : SV_POSITION;
            };

            //Custom SurfaceOutput
			struct SurfaceOutputCustom {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				half Specular;
				fixed Gloss;
				fixed Alpha;
				fixed3 Tangent;
			};

			 // normal map texture from shader properties
            fixed _Smoothness;
			float _AnisoBrush;

            fixed4 _HColor;
            fixed4 _SColor;

            inline half4 LightingToonyColorsCustom (inout SurfaceOutputCustom s, half3 viewDir, UnityGI gi) {
			#define IN_NORMAL s.Normal
		
				half3 lightDir = gi.light.dir;
			#if defined(UNITY_PASS_FORWARDBASE)
				half3 lightColor = _LightColor0.rgb;
				half atten = s.atten;
			#else
				half3 lightColor = gi.light.color.rgb;
				half atten = 1;
			#endif

				IN_NORMAL = normalize(IN_NORMAL);
				fixed ndl = max(0, dot(IN_NORMAL, lightDir));
				#define NDL ndl

			#if !defined(UNITY_PASS_FORWARDBASE)
				_SColor = fixed4(0,0,0,1);
			#endif
				_SColor = lerp(_HColor, _SColor, _SColor.a);	//Shadows intensity through alpha
				//Anisotropic Specular
				half3 h = normalize(lightDir + viewDir);
				float ndh = max(0, dot (IN_NORMAL, h));
				half3 binorm = cross(IN_NORMAL, s.Tangent);
				fixed ndv = dot(viewDir, IN_NORMAL);
				float aX = dot(h, s.Tangent) / _AnisoBrush;
				float aY = dot(h, binorm) / _Smoothness;
				float spec = sqrt(max(0.0, ndl / ndv)) * exp(-2.0 * (aX * aX + aY * aY) / (1.0 + ndh)) * s.Gloss * 2.0;
				spec *= atten;
				fixed4 c;
				c.rgb = s.Albedo * lightColor.rgb;
			#if (POINT || SPOT)
				c.rgb *= atten;
			#endif

				#define SPEC_COLOR	_SpecColor.rgb
				c.rgb += lightColor.rgb * SPEC_COLOR * spec;
				c.a = s.Alpha;

			#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
				c.rgb += s.Albedo * gi.indirect.diffuse;
			#endif


				return c;
			}

            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(vertex);
                o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
                half3 wNormal = UnityObjectToWorldNormal(normal);
                half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
                half tangentSign = tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                o.uv = uv;
                o.worldNormal = wNormal;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
            	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
            	float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

        		  SurfaceOutputCustom o = (SurfaceOutputCustom)0;
				  o.Albedo = 0.0;
				  o.Emission = 0.0;
				  o.Specular = 0.0;
				  o.Alpha = 0.0;
				  fixed3 normalWorldVertex = fixed3(0,0,1);
				  o.Normal = i.worldNormal;
				  normalWorldVertex = i.worldNormal;

                // Setup lighting environment
				  UnityGI gi;
				  UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				  gi.indirect.diffuse = 0;
				  gi.indirect.specular = 0;
				  gi.light.color = _LightColor0.rgb;
				  gi.light.dir = lightDir;

				  // Call GI (lightmaps/SH/reflections) lighting function
				  UnityGIInput giInput;
				  UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
				  giInput.light = gi.light;
				  giInput.worldPos = i.worldPos;
				  giInput.worldViewDir = worldViewDir;

				  #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
				    giInput.lightmapUV = IN.lmap;
				  #else
				    giInput.lightmapUV = 0.0;
				  #endif
				  #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
				    giInput.ambient = IN.sh;
				  #else
				    giInput.ambient.rgb = 0.0;
				  #endif
				  giInput.probeHDR[0] = unity_SpecCube0_HDR;
				  giInput.probeHDR[1] = unity_SpecCube1_HDR;
				  #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
				    giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
				  #endif
				  #ifdef UNITY_SPECCUBE_BOX_PROJECTION
				    giInput.boxMax[0] = unity_SpecCube0_BoxMax;
				    giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
				    giInput.boxMax[1] = unity_SpecCube1_BoxMax;
				    giInput.boxMin[1] = unity_SpecCube1_BoxMin;
				    giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
				  #endif
				  //LightingToonyColorsCustom_GI(o, giInput, gi);

				  fixed4 c = 0;

				  //realtime lighting: call lighting function
				  c += LightingToonyColorsCustom (o, worldViewDir, gi);
				  UNITY_APPLY_FOG(IN.fogCoord, c); // apply fog
				  UNITY_OPAQUE_ALPHA(c.a);
				  return c;
            }
            ENDCG
        }
    }
}