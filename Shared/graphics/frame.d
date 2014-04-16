module graphics.frame;

import math.vector;
import content.texture;

struct Frame
{
	TextureID texture;
	float4 _srcRect;
	float4 coords;

	@property float4 srcRect() const 
	{
		return _srcRect;
	} 

	@property float width() 
	{
		return  _srcRect.z;
	}

	@property float height() 
	{
		return  _srcRect.w;
	}

	@property float2 dim()
	{
		return _srcRect.zw;
	}

	this(TextureID texture)
	{
		this.texture = texture;
		this.coords = float4(0,0,1,1);
		this._srcRect = float4(0, 0, texture.width, texture.height);
	}

	this(TextureID texture, float4 srcRect)
	{
		this.texture = texture;
		this._srcRect = srcRect;
		this.coords = float4(srcRect.x / texture.width,
							 srcRect.y / texture.height,
							 (srcRect.x + srcRect.z) / texture.width,
							 (srcRect.y + srcRect.w) / texture.height);
	}
}