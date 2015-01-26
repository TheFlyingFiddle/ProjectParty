module rendering.shapes;

public import
math,
	graphics.color, 
	graphics.texture, 
	graphics.frame,
	graphics.font;


void drawText(R)(ref R renderer, const(char)[] text, float2 pos, float2 size, ref Font font, Color color, float2 thresholds, float4 bounds = float4(0,0,0,0))
{
	if(bounds == float4(0,0,0,0)) 
		bounds = float4(-100000, -10000000, 1000000000000, 10000000000000);

	import std.algorithm;
	auto lines = text.count("\n");

	float2 scale = float2(size.x / font.size,  size.y / font.size);

	CharInfo spaceInfo = font[' '];
	float2 cursor = float2(0,0);
	cursor.y = lines * font.lineHeight * scale.y;
	foreach(dchar c; text)
	{
		if(c == ' ') 
		{
			cursor.x += spaceInfo.advance * scale.x;
			continue;
		}  
		else if(c == '\n') 
		{
			cursor.y -= font.lineHeight * scale.y;
			cursor.x = 0;
			continue;
		} 
		else if(c == '\t') 
		{
			cursor.x += spaceInfo.advance * font.tabSpaceCount * scale.x;
			continue;
		}
		CharInfo info = font[c];

		float2 off = float2(0, font.size * scale.y);
		float2 position = cursor - off + pos + float2(info.offset.x * scale.x,
													  info.offset.y * scale.y);

		float4 distPos = float4(position.x,
								position.y,
								position.x + info.srcRect.z * scale.x,
								position.y + info.srcRect.w * scale.y);

		Frame page    = Frame(font.page, info.srcRect);
		float3 thresh = float3(font.layer, thresholds.x, thresholds.y);

		renderer.drawDistQuad(distPos, bounds, page, thresh, color);

		cursor.x += info.advance * scale.x;
	}
}


void drawDistQuad(R)(ref R renderer, ref float4 quad, ref Frame frame, ref float3 thresh, Color color)
{
	import rendering.renderer;

	static uint[6] indecies = [ 0, 1, 2, 0, 2, 3 ]; 

	float4 coords = frame.coords;

	DistVertex[4] vertices;
	vertices[0] = DistVertex(quad.xy, coords.xy, thresh, color);
	vertices[1] = DistVertex(quad.zy, coords.zy, thresh, color);
	vertices[2] = DistVertex(quad.zw, coords.zw, thresh, color);
	vertices[3] = DistVertex(quad.xw, coords.xw, thresh, color);

	renderer.addItems(vertices, indecies, frame.texture);
}

void drawDistQuad(R)(ref R renderer, 
					 ref float4 quad, 
					 ref float4 bounds, 
					 ref Frame frame, 
					 ref float3 thresh,
					 Color color)
{	
	if(quad.x > bounds.z ||
	   quad.y > bounds.w ||
	   quad.z < bounds.x || 
	   quad.w < bounds.y)
		return;

	if(quad.x >= bounds.x &&
	   quad.y >= bounds.y &&
	   quad.z <= bounds.z &&
	   quad.w <= bounds.w)
	{
		drawDistQuad(renderer, quad, frame, thresh, color);
	}
	else 
	{
		fixQuad(quad, frame.coords, bounds);
		drawDistQuad(renderer, quad, frame, thresh, color);
	}
}


void fixQuad(ref float4 quad, ref float4 coords, ref float4 bounds)
{
	import std.algorithm, std.math;
	float4 fixed;

	fixed.x = max(quad.x, bounds.x);
	fixed.y = max(quad.y, bounds.y);
	fixed.z = min(quad.z, bounds.z);
	fixed.w = min(quad.w, bounds.w);

	float width = abs(quad.z - quad.x);
	float height = abs(quad.w - quad.y);

	float cwidth  = coords.z - coords.x;
	float cheight = coords.w - coords.y;

	coords.x += ((fixed.x - quad.x) / width) * cwidth;
	coords.y += ((fixed.y - quad.y) / height) * cheight;
	coords.z += ((fixed.z - quad.z) / width) * cwidth;
	coords.w += ((fixed.w - quad.w) / height) * cheight;

	quad = fixed;
}


void drawQuad(R)(ref R renderer, float4 quad, Frame frame, Color color, float4 bounds)
{
	import rendering.renderer;
	static uint[6] indecies = [ 0, 1, 2, 0, 2, 3 ]; 

	if(quad.x > bounds.z ||
	   quad.y > bounds.w ||
	   quad.z < bounds.x || 
	   quad.w < bounds.y)
		return;

	fixQuad(quad, frame.coords, bounds);

	float4 coords = frame.coords;

	Vertex[4] vertices;
	vertices[0] = Vertex(quad.xy, coords.xy, color);
	vertices[1] = Vertex(quad.zy, coords.zy, color);
	vertices[2] = Vertex(quad.zw, coords.zw, color);
	vertices[3] = Vertex(quad.xw, coords.xw, color);

	renderer.addItems(vertices[], indecies[], frame.texture);
}

void drawQuad(R)(ref R renderer, float4 quad, Frame frame, Color color)
{
	drawQuad(renderer, quad, frame, color, quad);
}	

void drawQuad(R)(ref R renderer, float4 quad, float rotation, Frame frame, Color color)
{
	import rendering.renderer;

	static uint[6] indecies = [0, 1, 2, 0, 2, 3];

	float4 coords = frame.coords;

	Vertex[4] vertices;

	float2 center	   = float2((quad.x + quad.z) / 2, (quad.y + quad.w) / 2);
	float2 bottomLeft  = (float2(quad.x, quad.y) - center).rotate(rotation) + center;
	float2 bottomRight = (float2(quad.z, quad.y) - center).rotate(rotation) + center;
	float2 topRight    = (float2(quad.z, quad.w) - center).rotate(rotation) + center;
	float2 topLeft     = (float2(quad.x, quad.w) - center).rotate(rotation) + center;

	vertices[0] = Vertex(bottomLeft, coords.xy, color);
	vertices[1] = Vertex(bottomRight, coords.zy, color);
	vertices[2] = Vertex(topRight, coords.zw, color);
	vertices[3] = Vertex(topLeft, coords.xw, color);

	renderer.addItems(vertices, indecies, frame.texture);
}

void drawTriangle(R)(ref R renderer, float2 a, float2 b, float2 c, Texture2D texture, Color color)
{
	static uint[3] indices = [0, 1, 2];

	alias Vertex = R.Vertex;
	Vertex[3] vertices;
	vertices[0] = Vertex(a, float2.zero, color);
	vertices[1] = Vertex(b, float2(1, 0), color);
	vertices[2] = Vertex(c, float2(0.5, 1), color);

	renderer.addItems(vertices, indices, texture);
}

void drawQuadOutline(R)(ref R renderer, float4 rect, float width, Frame frame, Color color)
{
	import rendering.renderer;
	if(rect.x == rect.z || rect.y == rect.w) return;


	static uint[24] indices =
	[	
		0, 3, 1,
		3, 2, 1,
		3, 5, 2,
		5, 4, 2,

		5, 7, 4,
		7, 6, 4,
		7, 0, 6,
		0, 1, 6
	];

	float2 center = (frame.coords.xy + frame.coords.zw) / 2;

	Vertex[8] vertices;
	vertices[0] = Vertex(rect.xy, center, color);
	vertices[1] = Vertex(rect.xy + float2(width), center, color);

	vertices[2] = Vertex(rect.zy + float2(-width, width), center, color);
	vertices[3] = Vertex(rect.zy, center, color);


	vertices[4] = Vertex(rect.zw + float2(-width), center, color);
	vertices[5] = Vertex(rect.zw, center, color);

	vertices[6] = Vertex(rect.xw + float2(width,-width), center, color);
	vertices[7] = Vertex(rect.xw, center, color);

	renderer.addItems(vertices[], indices[], frame.texture);
}

void drawLine(R)(ref R renderer, float2 start, float2 end, float width, Frame frame, Color color)
{
	import rendering.renderer;
	static uint[6] indices = [0, 1, 2,  0, 2, 3];
	Vertex[4] vertices;

	float2 perp = float2((end - start).y, -(end - start).x).normalized;

	vertices[0] = Vertex(start - perp * width / 2,	frame.coords.xy, color);
	vertices[1] = Vertex(end - perp * width / 2,    frame.coords.zy, color);
	vertices[2] = Vertex(end + perp * width / 2,	frame.coords.zw, color);
	vertices[3] = Vertex(start + perp * width / 2,  frame.coords.xw, color);

	renderer.addItems(vertices, indices, frame.texture);
}

uint[N * 3] makeNGonIndices(size_t N)()
{
	uint[N * 3] indices;
	foreach(i; 0 .. N - 1)
	{
		indices[i * 3] = 0;
		indices[i * 3 + 1] = i + 1;
		indices[i * 3 + 2] = i + 2;
	}

	indices[N * 3 - 3] = 0;
	indices[N * 3 - 2] = N;
	indices[N * 3 - 1] = 1;

	return indices;
}

Vertex[N] makeNGonVertices(size_t N, Vertex)()
{

}

import rendering.combined;
void drawNGon(size_t N, R)(ref R renderer, float2 origin, 
						   float radius, Frame frame,
						   Color color)
{
	enum N = 50;


	import rendering.renderer;
	static uint[N * 3]   indecies   = makeNGonIndices!N;

	Vertex[N] vertices;
	foreach(i; 0 .. N)
	{
		float angle	  = (1.0f / N) * i * TAU + TAU / 4;
		float2 pos	  = Polar!(float)(angle, 1).toCartesian;
		float2 coord  = Polar!(float)(angle, 1).toCartesian;

		vertices[i] = Vertex(pos, coord, Color.white);
	}


	Vertex[N + 1] verts;
	float4 coords = frame.coords;
	float2 center	  = float2((coords.z - coords.x) / 2 + coords.x,
							   (coords.w - coords.y) / 2 + coords.y);
	float2 coordScale = float2((coords.z - coords.x) / 2,
							   (coords.w - coords.y) / 2);

	verts[0] = Vertex(origin, center, color);
	foreach(i; 0 .. N)
	{
		verts[i + 1] = Vertex(origin + vertices[i].position * radius, 
						      vertices[i].coords * coordScale + center, 
							  color);
	}
	renderer.addItems(verts, indecies, frame.texture);
}


uint[N * 12] makeNGonOutlineIndices(size_t N)()
{
	uint[N * 12] indices;
	foreach(i; 0 .. N * 2)
	{
		indices[i * 6 + 0] = i;
		indices[i * 6 + 1] = (i + 1) % (N * 2);
		indices[i * 6 + 2] = (i + 2) % (N * 2);

		indices[i * 6 + 3] = (i + 2) % (N * 2);
		indices[i * 6 + 4] = (i + 1) % (N * 2);
		indices[i * 6 + 5] = (i + 3) % (N * 2);
	}
	return indices;
}

void drawNGonOutline(size_t N, R)(ref R renderer, float2 origin,
								  float innerRadius, float outerRadius,
								  Frame frame, Color color)
{
	import rendering.renderer;
	static uint[N * 12]   indecies   = makeNGonOutlineIndices!N;

	Vertex[N] vertices;
	foreach(i; 0 .. N)
	{
		float angle	  = (1.0f / N) * i * TAU + TAU / 4;
		float2 pos	  = Polar!(float)(angle, 1).toCartesian;
		float2 coord  = Polar!(float)(angle, 1).toCartesian;

		vertices[i] = Vertex(pos, coord, Color.white);
	}

	Vertex[N * 2] verts;

	float4 coords = frame.coords;
	float2 center	  = float2((coords.z - coords.x) / 2 + coords.x,
							   (coords.w - coords.y) / 2 + coords.y);
	float2 coordScale = float2((coords.z - coords.x) / 2,
							   (coords.w - coords.y) / 2);
	foreach(i; 0 .. N)
	{
		verts[i * 2 + 0] = Vertex(origin + vertices[i].position * innerRadius, 
								  vertices[i].coords * coordScale + center, 
								  color);

		verts[i * 2 + 1] = Vertex(origin + vertices[i].position * outerRadius, 
								  vertices[i].coords * coordScale + center, 
								  color);
	}

	renderer.addItems(verts, indecies, frame.texture);
}

uint[N * 3] makeCircleSectionIndices(size_t N)()
{
	uint[N * 3] indices;
	foreach(i; 0 .. N)
	{
		indices[i * 3] = 0;
		indices[i * 3 + 1] = i + 1;
		indices[i * 3 + 2] = i + 2;
	}
	return indices;
}

void drawCircleSection(size_t N, R)(ref R renderer, float2 origin, 
									float radius, float startAngle,
									float endAngle, Texture2D texture, 
									Color color)
{
	alias Vertex = R.Vertex;
	static uint[N * 3] indices = makeCircleSectionIndices!(N);
	static Vertex[N + 2] vertices;

	float4 coords = float4(0,0 ,1,1);
	float2 center	  = float2((coords.z - coords.x) / 2 + coords.x,
							   (coords.w - coords.y) / 2 + coords.y);
	float2 coordScale = float2((coords.z - coords.x) / 2,
							   (coords.w - coords.y) / 2);

	vertices[0] = Vertex(origin, center, color);
	foreach(i; 0 .. N + 1)
	{
		float angle	  = (1.0f / N) * i * (endAngle - startAngle) + startAngle;
		float2 pos	  = Polar!(float)(angle, radius).toCartesian + origin;
		float2 coord  = Polar!(float)(angle, 1).toCartesian * coordScale + center;

		vertices[i + 1] = Vertex(pos, coord, color);
	}
	renderer.addItems(vertices, indices, texture);
}

T quadraticBezier(T)(float t, T a, T b, T c)
{
	assert(t >= 0 && t <= 1);
	return ((1 - t) ^^ 2) * a + 2 * (1 - t) * t * b + t * t * c;
}

T cubiqBezier(T)(float t, T a, T b, T c, T d)
{
	assert(t >= 0 && t <= 1);

	float u = 1 - t;
	return  a * (u ^^ 3) + b * 3 * (u ^^ 2) * t + c * 3 * u * t * t + d * (t ^^ 3);
}

uint[N * 6] makeBezierIndices(size_t N)()
{
	uint[N * 6] indices;
	foreach(i; 0 .. N  * 2)
	{
		indices[i * 3 + 0] = i;
		indices[i * 3 + 1] = i + 1;
		indices[i * 3 + 2] = i + 2;
	}

	return indices;
}

void drawBezier(size_t N, R)(ref R renderer, 
							 float2 start, float2 c0, 
							 float2 c1, float2 end, 
							 float width, Texture2D texture, 
							 Color color, float rotation = 0)
{
	alias Vertex = R.Vertex;
	uint[N * 6] indices  = makeBezierIndices!(N);
	Vertex[(N + 1) * 2]   vertices; 

	float2 perp = Polar!(float)(rotation, width / 2).toCartesian;
	float2[4] upper = [ start + perp, c0 + perp, c1 + perp, end + perp];
	float2[4] lower = [ start - perp, c0 - perp, c1 - perp, end - perp];

	foreach(i; 0 .. N + 1)
	{
		float value = (1f / N) * i;

		float2 up   = cubiqBezier(value, upper[0], upper[1], upper[2], upper[3]);
		float2 down = cubiqBezier(value, lower[0], lower[1], lower[2], lower[3]);

		vertices[i * 2 + 0] = Vertex(down,  float2(0.5,	0.5), color);
		vertices[i * 2 + 1] = Vertex(up,	float2(0.5,	0.5), color);
	}

	renderer.addItems(vertices, indices, texture);
}

void drawPath(R)(ref R renderer, float2[] path, float width, Texture2D texture, Color color)
{
	float rotation = (path[0] - path[3]).toPolar.angle;
	renderer.drawBezier!20(path[0], path[1], path[2], path[3], width, texture, color, rotation);
	for(int i = 3; i < path.length - 1; i += 3)
	{
		renderer.drawBezier!20(path[i], path[i + 1], path[i + 2], path[i + 3], 
							   width, texture, color, rotation);
	}
}