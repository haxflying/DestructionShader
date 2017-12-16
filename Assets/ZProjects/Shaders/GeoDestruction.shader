Shader "Unlit/GeoDestruction"
{
	Properties
	{
		_MainTex ("Base Texture", 2D) = "white" {}
		_NoiseTex("Noise Texture", 2D) = "black" {}
		_Offset("vertex offset", Range(0,0.05)) = 0
		_RustTex("rust Texture",2D) = "white" {}
		_OutColor("rust color", Color) = (1,1,1,1)
		_RustEmission("rust Emission", Range(0,10)) = 2
		_threshold("rust threshold", Range(0,1)) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma target 4.6
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct gsInput
			{
				float4 pos : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float3 normal : TEXCOORD2;
				uint id : TEXCOORD3;
			};

			struct g2f
			{
				float2 uv : TEXCOORD0;
				float4 height : TEXCOORD1; 
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex, _NoiseTex, _RustTex;
			float4 _MainTex_ST;
			float _Offset, _threshold, _RustEmission;
			fixed4 _OutColor;
			
			gsInput vert (appdata v, uint id : SV_VertexID)
			{
				gsInput o;
				//rot xz around center
				float s, c;
				sincos(_Time.y * _Offset, s, c);
				float2x2 rot = float2x2(c,-s,s,c);
				v.vertex.xz = mul(rot, v.vertex.xz);

				o.pos = v.vertex;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = v.normal;
				o.id = id;
				return o;
			}

			[maxvertexcount(9)]
			void geom(triangle gsInput p[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;
				//rot aroud triangle center
				float s, c;
				sincos(_Time.y * _Offset * 5 + p[2].id * _Offset * 10, s, c);
				float4 center = (p[0].pos + p[1].pos + p[2].pos)/3.0;
				float2x2 rot = float2x2(c,-s,s,c);
				for (int i = 0; i < 3; ++i)
				{
					float4 diff = p[i].pos - center;
					diff.xy = mul(rot, diff.xy);
					diff.xz = mul(rot, diff.xz);
					diff.yz = mul(rot, diff.yz);
					p[i].pos = center + diff;
				}
				
				//wireframe
				float3 proj0 = UnityObjectToClipPos(p[0].pos).xyw;
				float3 proj1 = UnityObjectToClipPos(p[1].pos).xyw;
				float3 proj2 = UnityObjectToClipPos(p[2].pos).xyw;

				float2 e0 = proj2.xy - proj1.xy;
				float2 e1 = proj2.xy - proj0.xy;
				float2 e2 = proj1.xy - proj0.xy;

				float area = abs(e1.x * e2.y - e1.y * e2.x);
				float thickness = 15 * _threshold;

				float noise = tex2Dlod(_NoiseTex, float4(p[2].uv, 0, 0));
				float4 normal = float4(p[0].normal + p[1].normal + p[2].normal, 0);
				normal = normalize(normal);
				normal += sin(_Time.y * _Offset / 5) * (noise - 0.5) * p[2].id / 1000.0;

				float3 hh[3] = {
					float3(area/length(e0),0,0) * proj0.z * thickness,
					float3(0,area/length(e1),0) * proj1.z * thickness,
					float3(0,0,area/length(e2)) * proj2.z * thickness
				};

				float ww[3] = {proj0.z, proj1.z, proj2.z};
				for (int i = 0; i < 3; ++i)
				{
					o.vertex = UnityObjectToClipPos(p[i].pos + _Offset * normal);
					o.uv = p[i].uv;
					o.height.xyz = hh[i];
					o.height.w = 1.0 / ww[i];
					triStream.Append(o);
				}
				
			}

			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed rust = tex2D(_RustTex, i.uv * 10).r;
				float l = min(i.height[0], min(i.height[1], i.height[2])) * rust;
				l = exp2(-2 * pow(l * l, 1)) * _threshold * _threshold;
				fixed4 final = lerp(col, _OutColor * _RustEmission, l);
				return final;
			}
			ENDCG
		}
	}
}
