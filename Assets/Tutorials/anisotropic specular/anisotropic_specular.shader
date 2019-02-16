// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShaderTutorial/A" {
	Properties {
		_MainTex ("Main Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)

		//SPECULAR
		_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
		_Smoothness ("Smoothness", Float) = 0.2
		_AnisoBrush ("Anisotropic Spread", Range(0.0,2)) = 1.0
    }

    SubShader
    {
    	Tags { "RenderType"="Opaque" }

        Pass
        {
        	Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            // exactly the same as in previous shader
            struct v2f {
                float3 worldPos : TEXCOORD0;
                half3 tspace0 : TEXCOORD1;
                half3 tspace1 : TEXCOORD2;
                half3 tspace2 : TEXCOORD3;
                float2 uv : TEXCOORD4;
                float3 worldNormal : TEXCOORD5;
                float3 tangentDir : TEXCOORD6;
                float4 pos : SV_POSITION;
            };

            //Custom SurfaceOutput
			struct SurfaceOutputCustom {
				half atten;
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

            sampler2D _MainTex;
            fixed4 _Color;

            inline half4 LightingCustom (inout SurfaceOutputCustom s, half3 viewDir, UnityGI gi) {
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
                o.tangentDir = tangent.xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
            	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
            	float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

	  			SurfaceOutputCustom o = (SurfaceOutputCustom)0;
			  	o.Emission = 0.0;
			  	o.Normal = i.worldNormal;

			  	// Texture
			  	half2 uv_MainTex;
				uv_MainTex.x = 1.0;
				uv_MainTex = i.uv;

				fixed4 mainTex = tex2D(_MainTex, uv_MainTex);
				o.Albedo = mainTex.rgb * _Color.rgb;
				o.Alpha = mainTex.a * _Color.a;

				// Specular
				o.Gloss = 1;
				o.Specular = _Smoothness;
				o.Tangent = i.tangentDir;

		        // Setup lighting environment
			  	UnityGI gi;
			  	UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
			  	gi.indirect.diffuse = 0;
			  	gi.indirect.specular = 0;
			  	gi.light.color = _LightColor0.rgb;
			  	gi.light.dir = lightDir;

			  	fixed4 c = 0;

			  	c += LightingCustom (o, worldViewDir, gi);
			  	UNITY_OPAQUE_ALPHA(c.a);
			  	return c;
            }
            ENDCG
        }
    }
}