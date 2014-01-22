module graphics.frame;

import graphics.texture;
import math.vector;

struct Frame
{
	Texture2D texture;
	float4 _srcRect;
	float4 coords;

	@property float4 srcRect() const 
	{
		return _srcRect;
	} 

	this(Texture2D texture)
	{
		this.texture = texture;
		this.coords = float4(0,0,1,1);
		this._srcRect = float4(0, 0, 1, 1);
	}

	this(Texture2D texture, float4 srcRect)
	{
		this.texture = texture;
		this._srcRect = srcRect;
		this.coords = float4(srcRect.x / texture.width,
							 srcRect.y / texture.height,
							 (srcRect.x + srcRect.z) / texture.width,
							 (srcRect.y + srcRect.w) / texture.height);
	}
}