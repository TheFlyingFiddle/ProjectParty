module world_renderer;

import state;
import ui;

struct WorldRenderer
{
	EditorState* state;

	Frame pixel, circle;
	Renderer2D* renderer;

	void renderWorld(ref Gui gui)
	{
		import graphics;
		import derelict.opengl3.gl3;
		auto area = gui.area;


		pixel	 = gui.atlas["pixel"];
		circle   = gui.atlas["circle"];	

		renderer = gui.renderer;
		renderer.end();

		gl.enable(GL_SCISSOR_TEST);
		gl.scissor(cast(int)area.x, 
				   cast(int)area.y, 
				   cast(int)area.w, 
				   cast(int)area.h);

		renderer.begin();

		import common.components;
		foreach(ref item; state.items)
		{
		    if(item.hasComp!(Sprite) &&
		       item.hasComp!(Transform))
		    {
		        auto sprite		= item.getComp!Sprite;
		        auto transform  = item.getComp!Transform;

				import std.algorithm;
				auto names = state.variables.images.get!(string[]);
				auto idx   = names.countUntil!(x => x == sprite.name);
				if(idx == -1) continue;

				auto frame = state.images[idx];
				mat3 t = mat3.CreateTransform(transform.position,
											  transform.scale, 
											  transform.rotation);
		        
		        float2 trans = transform.position + float2(200, 5) + state.camera.offset;
		        float2 min = trans - transform.scale * 4;
		        float2 max = trans + transform.scale * 4;
		        
		        renderer.drawQuad(float4(min.x, min.y, max.x, max.y), *frame, sprite.tint);
		
		    }
		}
		
		renderer.end();	
		gl.disable(GL_SCISSOR_TEST);
		renderer.begin();

		//float2 offset = gui.area.xy - float2(0, 10) - state.scroll;
		//
		//renderer = gui.renderer;	
		//
		//Rect bounds = gui.area.toFloat4;
		//renderer.end();
		//

		//foreach(row; 0 .. cast(int)(state.world.area.h / 50))
		//{
		//    
		//}
		//
		//foreach(ref layer; state.world.layers)
		//{
		//    foreach(ref item; layer.items)
		//    {
		//        Transform t = item.transform;
		//        t.position += offset;
		//        switch(item.type) with(ItemType)
		//        {
		//            case chain:
		//                renderChain(item.vertices.vertices.array, t , Color.blue, 4);
		//                break;
		//            case polygon:
		//                renderPolygon(item.vertices.vertices.array, t , Color.blue, 4);
		//                break;
		//            case circle:
		//                renderCircle(item.circle, t, Color.blue);
		//                break;
		//            case box:
		//                renderPolygon(item.box.vertices[], t , Color.blue, 0);
		//                break;
		//            case entity:
		//            case none: 
		//                break;
		//            default:
		//                assert(0, "......");
		//        }
		//    }
		//}		
		//renderer.end();
		//gl.disable(GL_SCISSOR_TEST);
		//
		//renderer.begin();
	}

	//Rendering
	//void renderCircle(CircleData circle, Transform t, Color color)
	//{
	//    renderer.drawNGonOutline!(50)(cast(float2)t.position,
	//                                  circle.radius,
	//                                  circle.radius- 1,
	//                                  pixel, Color.blue);
	//}
	//
	//void renderChain(float2[] chain, Transform t, Color color, float csize)
	//{
	//    foreach(i; 0 .. (cast(int)chain.length) - 1)
	//    {
	//        float2 v0 = t.transform(chain[i]);
	//        float2 v1 = t.transform(chain[i + 1]);
	//        renderLine(v0, v1);	
	//    }
	//
	//    foreach(ref vert; chain)
	//    {	
	//        float2 trans = t.transform(vert);
	//        float2 min = trans - float2(csize, csize);
	//        float2 max = trans + float2(csize, csize);
	//
	//        renderer.drawQuad(float4(min.x, min.y, max.x, max.y), circle, Color.blue);
	//    }
	//}
	//
	//void renderPolygon(float2[] polygon, Transform t, Color color, float csize)
	//{
	//    foreach(i; 0 .. polygon.length)
	//    {
	//        float2 v0 = t.transform(polygon[i]);
	//        float2 v1 = t.transform(polygon[(i + 1) % polygon.length]);
	//        renderLine(v0, v1);
	//    }
	//
	//    foreach(ref vert; polygon)
	//    {	
	//        float2 trans = t.transform(vert);
	//        float2 min = trans - float2(csize, csize);
	//        float2 max = trans + float2(csize, csize);
	//
	//        renderer.drawQuad(float4(min.x, min.y, max.x, max.y), circle, Color.blue);
	//    }
	//}
	//
	//void renderLine(float2 v0, float2 v1)
	//{
	//    renderer.drawLine(v0, v1, 2, pixel, Color.blue);
	//}
}
