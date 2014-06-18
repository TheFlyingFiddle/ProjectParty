module spacial.transform;
import math.vector;

struct Transform
{
	float2 position, scale;
	float rotation;

	Transform ident()
	{
		return Transform(float2.zero, float2.one, 0);
	}
	
	void opBinary(string s : "*")(auto ref Transform other)
	{
		Transform2D result = void;
		result.position = rotate(this.position, other.rotation) * other.scale + other.position;
		result.scale    = this.scale * other.scale;
		result.rotation = this.rotation + other.rotation;
		return result;
	}

	ref Transform opOpAssign(string s : "*")(auto ref Transform other)
	{
		this.position = rotate(this.position, other.rotation) * other.scale + other.position;
		this.scale    = this.scale * other.scale;
		this.rotation = this.rotation + other.rotation;
		return this;
	}
}