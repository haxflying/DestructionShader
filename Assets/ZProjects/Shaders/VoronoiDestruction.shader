Shader "Unlit/VoronoiDestruction"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_TessellationUniform("TessllationUniform",Range(1,64)) = 1
		_DestrucScale("Destruction Scale", Range(0, 2)) = 0
		_thickness("Destruction Thickness",Range(0,1)) = 0.02
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase"}
		LOD 100

		Pass
		{
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma hull HullProgram
			#pragma domain DomainProgram
			#pragma geometry geom
			#pragma fragment frag
			#pragma target 4.6
			#define vec3 float3
			#define vec2 float2
			#define mix lerp
			#define fract frac
			#include "UnityCG.cginc"
			#include "Tessellation.cginc"

			#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
			patch[0].fieldName * barycentricCoordinates.x + \
			patch[1].fieldName * barycentricCoordinates.y + \
			patch[2].fieldName * barycentricCoordinates.z;

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct vertexData
			{
				float4 vertex : TEXCOORD0;
				float3 normal : TEXCOORD2;
				float2 uv : TEXCOORD1;
			};

			struct d2g
			{
				float4 vertex : TEXCOORD0;
				float3 normal : TEXCOORD2;
				float2 uv : TEXCOORD1; 
			};

			struct g2f
			{
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			struct TessellationFactors{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _TessellationUniform;
			float _DestrucScale;
			float _thickness;
			float4 _LightColor0;
			
			vertexData vert (appdata v)
			{
				vertexData o;
				o.vertex = v.vertex;
				o.normal = v.normal;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}


			float4 tessDistance (vertexData v0, vertexData v1, vertexData v2) {
	            float minDist = 10;
	            float maxDist = 25;
	            return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _TessellationUniform);
	        }

	        TessellationFactors ConstantFunction(InputPatch<vertexData, 3> patch)
			{
				TessellationFactors f;	
				float4 tf = _TessellationUniform;
				tf = tessDistance(patch[0],patch[1],patch[1]);
				f.edge[0] = tf.x;
				f.edge[1] = tf.y;
				f.edge[2] = tf.z;
				f.inside = tf.w;
				return f;
			}

			[UNITY_domain("tri")] //告诉GPU要处理三角形
			[UNITY_outputcontrolpoints(3)] //告诉GPU每个patch三个顶点
			[UNITY_outputtopology("triangle_cw")] //告诉GPU 新创建三角形以顶点顺时针为正面
			[UNITY_partitioning("fractional_odd")] //定义GPU细分patch的方法 : integer, pow2, fractional_even, fractional_odd
			[UNITY_patchconstantfunc("ConstantFunction")] //定义每个patch细分数量的方法函数
			vertexData HullProgram(InputPatch<vertexData, 3> patch, uint id: SV_OutputControlPointID)
			{
				return patch[id];
			}

			d2g TessVert (vertexData v)
			{
				d2g o;
				o.vertex = v.vertex;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = v.normal;
				return o;
			}

			[UNITY_domain("tri")] //告诉GPU要处理三角形
			d2g DomainProgram(TessellationFactors factors, OutputPatch<vertexData, 3> patch, 
				float3 barycentricCoordinates : SV_DomainLocation)
			{
				vertexData data;
				MY_DOMAIN_PROGRAM_INTERPOLATE(vertex);
				MY_DOMAIN_PROGRAM_INTERPOLATE(uv);
				MY_DOMAIN_PROGRAM_INTERPOLATE(normal);

				return TessVert(data);
			}

			vec3 hash( vec3 x )
			{
				x = vec3( dot(x,vec3(127.1,311.7, 74.7)),
						  dot(x,vec3(269.5,183.3,246.1)),
						  dot(x,vec3(113.5,271.9,124.6)));

				return fract(sin(x)*43758.5453123);
			}

			vec3 voronoi( in vec3 x, out float3 fp)
			{
			    vec3 p = floor( x );
			    vec3 f = fract( x );

				float id = 0.0;
			    vec2 res = vec2( 100.0 , 100.0);
			    for( int k=-1; k<=1; k++ )
			    for( int j=-1; j<=1; j++ )
			    for( int i=-1; i<=1; i++ )
			    {
			        vec3 b = vec3( float(i), float(j), float(k) );
			        vec3 r = b - f + hash( p + b);
			        float d = dot( r, r );

			        if( d < res.x )
			        {
						id = dot( p+b, vec3(0,0,0 ) );
			            res = vec2( d, res.x );	
			            fp = hash(p + b);	
			        }
			        else if( d < res.y )
			        {
			            res.y = d;
			        }
			    }

			    return vec3( sqrt( res ), abs(id) );
			}

			float reconcile(float2 value)
			{
				return pow(1 - abs(value.y - value.x),3);
				//return value.x;
			}

			[maxvertexcount(3)]
			void geom(triangle d2g p[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;

				float4 center = 0;
				float3 normal = 0;
				for (int i = 0; i < 3; ++i)
				{
					center += p[i].vertex;
					normal += p[i].normal;
				}

				center /= 3.0;
				normal /= 3.0;

				float3 fp = 0.0;
				float3 voro = voronoi(center.xyz * 10, fp);
				float3 vnormal = fp * _DestrucScale;
				float3 vnormal1 = reconcile(voro.xy) * _DestrucScale;
				center = 0;

				//rot
				float s, c;
				sincos(_Time.y * 0.1 * _DestrucScale, s, c);
				float2x2 mm = float2x2(c,-s,s,c);

				for (int i = 0; i < 3; ++i)
				{
					center.xyz += p[i].vertex + vnormal * _DestrucScale;
					p[i].vertex.xy = mul(mm, p[i].vertex.xy);
					p[i].vertex.xz = mul(mm, p[i].vertex.xz);
					p[i].vertex.zy = mul(mm, p[i].vertex.zy);
					o.vertex = UnityObjectToClipPos(p[i].vertex + vnormal);
					o.uv = p[i].uv;
					o.normal = UnityObjectToWorldNormal(p[i].normal);
					triStream.Append(o);
				}
				/*
				triStream.RestartStrip();

				center /= 3.0;

				float3 newFp = (center.xyz - (center.xyz - fp) * _thickness) * _DestrucScale;			

				for (int i = 0; i < 2; ++i)
				{		
					float3 tnormal = normalize(cross(p[i].vertex + vnormal - newFp, p[i+1].vertex + vnormal - newFp));
					tnormal = UnityObjectToWorldNormal(tnormal * i == 1? -1 : 1);
					o.vertex = UnityObjectToClipPos(newFp);
					o.uv = 0;
					o.normal = tnormal;
					triStream.Append(o);			
					
					o.vertex = UnityObjectToClipPos(p[i].vertex + vnormal);
					o.uv = 0;
					o.normal = tnormal;
					triStream.Append(o);

					o.vertex = UnityObjectToClipPos(p[i+1].vertex + vnormal);
					o.uv = 0;
					o.normal = tnormal;
					triStream.Append(o);

					triStream.RestartStrip();			
				}

				float3 tnormal = normalize(cross(p[0].vertex + vnormal - newFp, p[2].vertex + vnormal - newFp));
				tnormal = UnityObjectToWorldNormal(-tnormal);
				o.vertex = UnityObjectToClipPos(newFp);
				o.uv = 0;
				o.normal = tnormal;
				triStream.Append(o);			
				
				o.vertex = UnityObjectToClipPos(p[0].vertex + vnormal);
				o.uv = 0;
				o.normal = tnormal;
				triStream.Append(o);

				o.vertex = UnityObjectToClipPos(p[2].vertex + vnormal);
				o.uv = 0;
				o.normal = tnormal;
				triStream.Append(o);
				triStream.RestartStrip();	*/		
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
				float3 lambert = max(0.0, dot(_WorldSpaceLightPos0.xyz, i.normal)) * _LightColor0.rgb;
				return col * fixed4(lambert + ambient, 1);
			}
			ENDCG
		}
	}
}
