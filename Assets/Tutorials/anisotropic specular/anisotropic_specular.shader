// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShaderTutorial/anisotropic_specular" {
	Properties {
        // normal map texture on the material,
        // default to dummy "flat surface" normalmap
        _BumpMap("Normal Map", 2D) = "bump" {}
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
			#include "AutoLight.cginc"

            // exactly the same as in previous shader
            struct v2f {
                float3 worldPos : TEXCOORD0;
                half3 tspace0 : TEXCOORD1;
                half3 tspace1 : TEXCOORD2;
                half3 tspace2 : TEXCOORD3;
                float2 uv : TEXCOORD4;
                float4 pos : SV_POSITION;
            };

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
                return o;
            }

            // normal map texture from shader properties
            sampler2D _BumpMap;
        
            fixed4 frag (v2f i) : SV_Target
            {
            	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
            	float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

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
				  //c += LightingToonyColorsCustom (o, worldViewDir, gi);
				  //UNITY_APPLY_FOG(IN.fogCoord, c); // apply fog
				  UNITY_OPAQUE_ALPHA(c.a);
				  return c;
            }
            ENDCG
        }
    }
}