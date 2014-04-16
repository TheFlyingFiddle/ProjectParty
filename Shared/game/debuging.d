module game.debuging;


import graphics;
import game.rendering;
import content, math;
import std.math;


Frame pixel;
Frame circle;


void initDebugging(string pixelPath)
{
	auto pixelTex = TextureManager.load(pixelPath);
	pixel = Frame(pixelTex);
}	

void addRect(Renderer* renderer, 
			 float4 rect, 
			 Color color = Color.white,
			 float2 origin = float2.zero,
			 float rotation = 0)
{
	renderer.addFrame(pixel, 
					  rect,
					  color,
					  origin,
					  rotation);
}

void addRectOutline(Renderer* renderer,
					float4 rect,
					Color color = Color.white,
					float width = 1,
					float2 origin = float2.zero,
					float rotation = 0)
{
	auto s = sin(rotation), 
		 c = cos(rotation);
	
	auto bottomLeft  = rect.xy + rotate(-origin, rotation),
		 bottomRight = rect.xy + rotate(-origin + float2(rect.z, 0), rotation),
		 topLeft     = rect.xy + rotate(-origin + float2(0, rect.w), rotation),
		 topRight    = rect.xy + rotate(-origin + rect.zw, rotation);

	renderer.addLine(bottomLeft, bottomRight, color, width);
	renderer.addLine(bottomRight, topRight, color, width);
	renderer.addLine(topRight, topLeft, color, width);
	renderer.addLine(topLeft, bottomLeft, color, width);
}

void addLine(Renderer* renderer,
			 float2 start, 
			 float2 end, 
			 Color color = Color.white,
			 float width = 1)
{
	auto angle = atan2(end.y - start.y, end.x - start.x);
	auto dist  = distance(start, end);

	renderer.addFrame(pixel, 
					  float4(start.x, start.y, dist, width), 
					  color,
					  float2(0, width / 2), angle);
}

void addCircleOutline(Renderer* renderer,
					  float2 center,
					  float radius,
					  Color color = Color.white,
					  float width = 1,
					  uint numLines = 10)
{
	float angle = 0;
	foreach(i; 1 .. numLines + 1)
	{
		float angle2 = TAU * (i  / cast(float)numLines);
		
		float2 start = center + float2(radius * cos(angle),  radius * sin(angle));
		float2 end   = center + float2(radius * cos(angle2), radius * sin(angle2));

		renderer.addLine(start, end, color, width);

		angle = angle2;
	}
}