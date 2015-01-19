module math.matrix;

alias Matrix2 mat2;
alias Matrix3 mat3;
alias Matrix4 mat4;

//Todo Add mat2x3 mat3x2 mat2x4 mat3x4 mat4x2 mat4x3 aswell (maybe kinda annoying sometimes)
import std.stdio;
import math.vector;
import std.math;
import std.traits;

struct Matrix2
{
	enum Matrix2 identity = Matrix2(1f,0f,0f,1f);

	float[4] _rep;

	this(float f00, float f01, float f10, float f11)
	{
		this._rep[0] = f00;
		this._rep[1] = f01;
		this._rep[2] = f10;
		this._rep[3] = f11;
	}

	///Expects rep to be column major
	this(float[4] rep)
	{
		this._rep = rep;
	}

	Matrix2 transpose() @property
	{
		return Matrix2(_rep[0], _rep[2], _rep[1], _rep[3]);
	}

	float determinant() @property
	{
		return _rep[0]*_rep[3] - _rep[2]*_rep[1];
	}

	Matrix2 inverse() @property
	{
		float invDet = 1.0f / determinant;
		return Matrix2(_rep[3] * invDet, -_rep[2]* invDet, 
					   -_rep[1] * invDet, _rep[0] * invDet);
	}

	unittest
	{
		auto mat1 = mat2(4.1f,42.24f,
						 6.1f,13.37f);
		auto mat2 = mat1.inverse;
		//assertEquals(mat1*mat2, identity);
	}

	bool opEquals(Matrix2 rhs)
	{
		foreach(i;0..4)
		{
			if(!approxEqual(_rep[i], rhs._rep[i]))
				return false;
		}
		return true;
	}

	Matrix2 opBinary(string op)(Matrix2 rhs) if(op == "*")
	{
		return Matrix2(rhs._rep[0] * _rep[0] + rhs._rep[1] * _rep[2],
					   rhs._rep[2] * _rep[0] + rhs._rep[3] * _rep[2],

					   rhs._rep[0] * _rep[1] + rhs._rep[1] * _rep[3],
					   rhs._rep[2] * _rep[1] + rhs._rep[3] * _rep[3]); 
	}

	unittest
	{
		auto m1 = mat2(3.4f, 1.3f,
					   2.6f, 9.8f);
		auto m2 = mat2(0.1f, 4.5f,
					   9.6f, 7.8f);
		auto result = mat2(12.82f, 25.44f,
						   94.34f, 88.14f);
		//assertEquals(m1*m2, result);
	}

	Matrix2 opBinary(string op)(Matrix2 rhs) if(op == "+" || op == "-")
	{

		return Matrix2(mixin("_rep[0]" ~ op ~ "rhs._rep[0]"), 
					   mixin("_rep[2]" ~ op ~ "rhs._rep[2]"), 
					   mixin("_rep[1]" ~ op ~ "rhs._rep[1]"), 
					   mixin("_rep[3]" ~ op ~ "rhs._rep[3]"));
	}

	unittest
	{
		auto m1 = mat2(3.4f, 1.3f,
					   2.6f, 9.8f);
		auto m2 = mat2(0.1f, 4.5f,
					   9.6f, 7.8f);
		auto result1 = mat2(3.5f,5.8f,
							12.2f, 17.6f);
		auto result2 = mat2(3.3f, -3.2f,
							-7f, 2f);
		//assertEquals(m1 + m2, result1);
		//assertEquals(m1 - m2, result2);
	}

	Matrix2 opBinary(string op)(float value) if(s == "*")
	{
		return Matrix2(_rep[] *= value);
	}

	float2 opBinary(string op)(float2 rhs) if(op == "*")
	{
		return float2(rhs.x * _rep[0] + rhs.y * _rep[1],
					  rhs.x * _rep[2] + rhs.y * _rep[3]);
	}

	unittest
	{
		float2 f = float2(4.3f, 5.1f);
		//assertEquals(f, identity*f);
	}

	static Matrix2 rotation(float angle) 
	{
		float s = sin(angle), c = cos(angle);
		return Matrix2(c, -s, s, c);
	}

	unittest
	{
		auto rot = rotation(PI_2);
		//assertEquals(rot, mat2(0,-1,
		//						   1,0));
	}

	static Matrix2 scale(float scale) 
	{
		return Matrix2(scale, 0, 0, scale);
	}
}

struct Matrix3 
{
	private float[9] _rep;
	public enum Matrix3 identity 
		= Matrix3(1f,0f,0f,
				  0f,1f,0f,
				  0f,0f,1f);

	///Constructor using column major arrays
	this(float[9] arr)
	{
		_rep = arr;
	}

	this(float f00, float f01, float f02,
		 float f10, float f11, float f12,
		 float f20, float f21, float f22)
	{
		_rep[0] = f00;	_rep[3] = f01; _rep[6]	= f02;
		_rep[1] = f10;	_rep[4] = f11; _rep[7]	= f12;
		_rep[2] = f20;	_rep[5] = f21; _rep[8]	= f22;
	}

	@property const(float)* ptr() const
	{
		return _rep.ptr;
	}

	@property Matrix3 transpose() 
	{
		auto ptr = _rep.ptr;
		return Matrix3(*ptr++, *ptr++, *ptr++, 
					   *ptr++, *ptr++, *ptr++, 
					   *ptr++, *ptr++, *ptr++); 
	}

	unittest
	{
		auto mat = mat3(
						1, 2, 3,
						5, 6, 7,
						9, 0, 1);

		//assertEquals(mat.transpose, mat3(
		//		 1, 5, 9,
		//		 2, 6, 0,
		//		 3, 7, 1));
	}

	@property float determinant()
	{          
		return _rep[0]*_rep[4]*_rep[8]
			+_rep[1]*_rep[5]*_rep[6]
			+_rep[2]*_rep[3]*_rep[7]
			-_rep[0]*_rep[5]*_rep[7]
			-_rep[2]*_rep[4]*_rep[6]
			-_rep[1]*_rep[3]*_rep[8];
	}

	unittest
	{
		auto mat = mat3(
						1, 2, 3,
						5, 6, 7,
						9, 0, 1);

		//assertEquals(mat.determinant, -40f);

		mat = mat3(
				   4.500, 4.100, 6.700,
				   4.100, 9.800, 7.900,
				   1.200, 0.100, 4.500);
		assert(approxEqual(mat.determinant, 82.072f));
	}

	void opIndexAssing(float f, int index)
	{
		_rep[index] = f;
	}

	float opIndex(int m, int n)
	{
		return _rep[m + n*3];
	}

	void opIndexAssign(float f, int m, int n)
	{
		_rep[m + n*3] = f;
	}

	unittest
	{
		mat3 mat = Matrix3.identity;
		mat[1,0] = 5;
		//	assertEquals(mat[1,0], mat._rep[1]);
	}

	Matrix3 opBinary(string op)(Matrix3 rhs) if(op == "+" || op == "-")
	{
		return Matrix3(mixin("_rep[]"~op~"rhs._rep[]"));
	}

	Matrix3 opBinary(string op)(float rhs) if(op == "*")
	{
		return Matrix3(_rep[]*rhs);
	}

	Matrix3 opBinary(string op)(Matrix3 rhs) if (op == "*") 
	{
		return mat3(
					_rep[0]*rhs._rep[0]	+ _rep[3]*rhs._rep[1]	+ _rep[6]*rhs._rep[2],
					_rep[0]*rhs._rep[3]	+ _rep[3]*rhs._rep[4]	+ _rep[6]*rhs._rep[5],
					_rep[0]*rhs._rep[6]	+ _rep[3]*rhs._rep[7]	+ _rep[6]*rhs._rep[8],

					_rep[1]*rhs._rep[0]	+ _rep[4]*rhs._rep[1]	+ _rep[7]*rhs._rep[2],
					_rep[1]*rhs._rep[3]	+ _rep[4]*rhs._rep[4]	+ _rep[7]*rhs._rep[5],
					_rep[1]*rhs._rep[6]	+ _rep[4]*rhs._rep[7]	+ _rep[7]*rhs._rep[8],

					_rep[2]*rhs._rep[0]	+ _rep[5]*rhs._rep[1]	+ _rep[8]*rhs._rep[2],
					_rep[2]*rhs._rep[3]	+ _rep[5]*rhs._rep[4]	+ _rep[8]*rhs._rep[5],
					_rep[2]*rhs._rep[6]	+ _rep[5]*rhs._rep[7]	+ _rep[8]*rhs._rep[8]);
	}

	unittest
	{
		auto m1 = mat3(
					   4.500, 4.100, 6.700,
					   4.100, 9.800, 7.900,
					   1.200, 0.100, 4.500);
		//assertEquals(m1, m1*mat3.identity);
		auto m2 = mat3(
					   1.000, 2.000, 3.000,
					   5.000, 6.000, 7.000,
					   9.000, 0.000, 1.000);

		auto result = mat3(85.3f,  33.6f,  48.9f,
						   124.2f, 67f,  88.8f,
						   42.2f,  3f,   8.8f,);

		//assertEquals(m1*m2, result);
	}

	bool opEquals(mat3 rhs)
	{
		foreach(i;0..9)
		{
			if(!approxEqual(_rep[i], rhs._rep[i]))
				return false;
		}
		return true;
	}

	float3 opBinary(string op)(float3 rhs) if (op == "*")
	{
		return float3(
					  _rep[0]*rhs.x + _rep[3]*rhs.y + _rep[6]*rhs.z,
					  _rep[1]*rhs.x + _rep[4]*rhs.y + _rep[7]*rhs.z,
					  _rep[2]*rhs.x + _rep[5]*rhs.y + _rep[8]*rhs.z
					  );									
	}

	float2 opBinary(string op)(float2 rhs) if (op == "*")
	{
		return float2(_rep[0]*rhs.x + _rep[3]*rhs.y + _rep[6],
					  _rep[1]*rhs.x + _rep[4]*rhs.y + _rep[7]);
	}

	unittest
	{
		auto vec = float3(1.493f, 56.21f, 124.9f);
		//assertEquals(identity*vec, vec);
	}

	@property Matrix3 inverse()
	in
	{
		assert(this.determinant);
	}
	body
	{
		auto inv = mat3(
						_rep[4]*_rep[8]-_rep[7]*_rep[5],		_rep[6]*_rep[5]-_rep[3]*_rep[8],		_rep[3]*_rep[7]-_rep[6]*_rep[4],
						_rep[7]*_rep[2]-_rep[1]*_rep[8],		_rep[0]*_rep[8]-_rep[6]*_rep[2],		_rep[6]*_rep[1]-_rep[0]*_rep[7],
						_rep[1]*_rep[5]-_rep[4]*_rep[2],		_rep[3]*_rep[2]-_rep[0]*_rep[5],		_rep[0]*_rep[4]-_rep[3]*_rep[1]);

		auto invDet = 1f/(determinant);
		foreach(ref e;inv._rep)
			e *= invDet;
		return inv;
	}

	unittest
	{
		auto mat1 = mat3(
						 4.5f, 4.1f, 6.7f,
						 4.1f, 9.8f, 7.9f,
						 1.2f, 0.1f, 4.5f);
		auto inv = mat3(	 0.527701, -0.216636, -0.405371,
							 -0.109293,  0.148770, -0.098449,
						-0.138292,  0.054464,  0.332509);

		//assertEquals(mat1.inverse, inv);
		//assertEquals(mat1*mat1.inverse, identity);
	}

	public static Matrix3 CreateRotationZ(float angle)
	{
		float s = sin(angle);
		float c = cos(angle);

		return Matrix3(c, -s, 0,
					   s,  c, 0,
					   0,  0, 1);
	}

	unittest
	{
		//assertEquals(CreateRotationZ(PI), 
		//			 mat3(-1,0,0,
		//				  0,-1,0,
		//				  0,0,1,));
	}

	public static Matrix3 CreateScale(float x, float y)
	{
		return Matrix3( x, 0, 0,
						0, y, 0,
					   0, 0, 1);
	}

	unittest
	{
		float x = 1.4f, y = 4.5f, z = 18.41f;
		auto mat = Matrix3(	x, 0, 0,
							0, y, 0,
						   0, 0, z);
		//assertEquals(CreateScale(x,y,z), mat);
	}


	public static Matrix3 CreateTranslation(float2 pos)
	{
		return Matrix3(1, 0, pos.x,
					   0, 1, pos.y,
					   0, 0, 1);
	}


	public static Matrix3 CreateTransform(float2 pos, float2 scale, float rotation)
	{
		mat3 tmp = Matrix3.CreateRotationZ(rotation);
		tmp      = tmp * Matrix3.CreateScale(scale.x, scale.y);
		tmp		 = tmp * Matrix3.CreateTranslation(pos);

		return tmp;
	}

	///Needs to be tested: Integration style
	public static Matrix4 CreateOrthographic(float viewWidth, float viewHeight,
											 float x, float y, float z,
											 float zNear, float zFar)
	{
		auto xMax = viewWidth - 1f;
		auto yMax = viewHeight - 1f;
		return Matrix4(2 / xMax, 0, 0, -1,
					   0, -2 / yMax, 0 , 1,
					   0, 0, 2 / (zFar - zNear),(zNear + zFar) / (zNear - zFar),
					   0, 0, 0, 1);
	}
}

struct Matrix4 
{
	public enum Matrix4 identity 
		= Matrix4(1f,0f,0f,0f,
				  0f,1f,0f,0f,
				  0f,0f,1f,0f,
				  0f,0f,0f,1f);

	///Unexposed representation
	private float[16] _rep;

	@property const(float)* ptr() const
	{
		return _rep.ptr;
	}

	@property Matrix4 transpose() 
	{
		auto ptr = _rep.ptr;
		return Matrix4(*ptr++, *ptr++, *ptr++, *ptr++, 
					   *ptr++, *ptr++, *ptr++, *ptr++, 
					   *ptr++, *ptr++, *ptr++, *ptr++, 
					   *ptr++, *ptr++, *ptr++, *ptr++); 
	}

	unittest
	{
		auto mat = mat4(
						1.000, 2.000, 3.000, 4.000,
						5.000, 6.000, 7.000, 8.000,
						9.000, 0.000, 1.000, 2.000,
						3.000, 4.000, 5.000, 6.000);
		auto result = mat4(
						   1,5,9,3,
						   2,6,0,4,
						   3,7,1,5,
						   4,8,2,6);

		//assertEquals(mat.transpose, result);
	}

	@property float determinant()
	{          
		return _rep[0] * _rep[5] * _rep[10] * _rep[15] - _rep[0] * _rep[5] * _rep[14] * _rep[11] + _rep[0] * _rep[9] * _rep[14] * _rep[7] - _rep[0] * _rep[9] * _rep[6] * _rep[15]
			+ _rep[0] * _rep[13] * _rep[6] * _rep[11] - _rep[0] * _rep[13] * _rep[10] * _rep[7] - _rep[4] * _rep[9] * _rep[14] * _rep[3] + _rep[4] * _rep[9] * _rep[2] * _rep[15]
			- _rep[4] * _rep[13] * _rep[2] * _rep[11] + _rep[4] * _rep[13] * _rep[10] * _rep[3] - _rep[4] * _rep[1] * _rep[10] * _rep[15] + _rep[4] * _rep[1] * _rep[14] * _rep[11]
			+ _rep[8] * _rep[13] * _rep[2] * _rep[7] - _rep[8] * _rep[13] * _rep[6] * _rep[3] + _rep[8] * _rep[1] * _rep[6] * _rep[15] - _rep[8] * _rep[1] * _rep[14] * _rep[7]
			+ _rep[8] * _rep[5] * _rep[14] * _rep[3] - _rep[8] * _rep[5] * _rep[2] * _rep[15] - _rep[12] * _rep[1] * _rep[6] * _rep[11] + _rep[12] * _rep[1] * _rep[10] * _rep[7]
			- _rep[12] * _rep[5] * _rep[10] * _rep[3] + _rep[12] * _rep[5] * _rep[2] * _rep[11] - _rep[12] * _rep[9] * _rep[2] * _rep[7] + _rep[12] * _rep[9] * _rep[6] * _rep[3];
	}

	unittest
	{
		auto mat = mat4(
						1.000, 2.000, 3.000, 4.000,
						5.000, 6.000, 7.000, 8.000,
						9.000, 0.000, 1.000, 2.000,
						3.000, 4.000, 5.000, 6.000);

		//assertEquals(mat.determinant, 0f);

		mat = mat4(
				   4.500, 4.100, 6.700, 8.900,
				   4.100, 9.800, 7.900, 7.600,
				   1.200, 0.100, 4.500, 6.700,
				   4.100, 3.400, 5.600, 7.800);
		assert(approxEqual(mat.determinant, 19.247f));
	}

	///Constructor using column major arrays
	this(float[16] arr)
	{
		_rep = arr;
	}

	this(float f00, float f01, float f02, float f03,
		 float f10, float f11, float f12, float f13,
		 float f20, float f21, float f22, float f23,
		 float f30, float f31, float f32, float f33)
	{
		_rep[0] = f00;  _rep[4] = f01; _rep[8]  = f02; _rep[12] = f03;
		_rep[1] = f10;  _rep[5] = f11; _rep[9]  = f12; _rep[13] = f13;
		_rep[2] = f20;  _rep[6] = f21; _rep[10] = f22; _rep[14] = f23;
		_rep[3] = f30;  _rep[7] = f31; _rep[11] = f32; _rep[15] = f33;
	}

	float opIndex(int m, int n)
	{
		return _rep[m + n*4];
	}

	void opIndexAssign(float f, int m, int n)
	{
		_rep[m + n*4] = f;
	}

	unittest
	{
		mat4 mat = Matrix4.identity;
		mat[1,3] = 5;
		//assertEquals(mat[1,3], mat._rep[13]);
	}

	Matrix4 opBinary(string op)(Matrix4 rhs) if(op == "+" || op == "-")
	{
		return Matrix4(mixin("_rep[]"~op~"rhs._rep[]"));
	}

	Matrix4 opBinary(string op)(float rhs) if(op == "*")
	{
		return Matrix4(_rep[]*rhs);
	}

	Matrix4 opBinary(string op)(Matrix4 rhs) if (op == "*") 
	{
		return mat4(
					_rep[0]*rhs._rep[0]	+ _rep[4]*rhs._rep[1]	+ _rep[8]*rhs._rep[2]	+ _rep[12]*rhs._rep[3],
					_rep[0]*rhs._rep[4]	+ _rep[4]*rhs._rep[5]	+ _rep[8]*rhs._rep[6]	+ _rep[12]*rhs._rep[7],
					_rep[0]*rhs._rep[8]	+ _rep[4]*rhs._rep[9]	+ _rep[8]*rhs._rep[10]	+ _rep[12]*rhs._rep[11],
					_rep[0]*rhs._rep[12]	+ _rep[4]*rhs._rep[13]	+ _rep[8]*rhs._rep[14]	+ _rep[12]*rhs._rep[15],

					_rep[1]*rhs._rep[0]	+ _rep[5]*rhs._rep[1]	+ _rep[9]*rhs._rep[2]	+ _rep[13]*rhs._rep[3],
					_rep[1]*rhs._rep[4]	+ _rep[5]*rhs._rep[5]	+ _rep[9]*rhs._rep[6]	+ _rep[13]*rhs._rep[7],
					_rep[1]*rhs._rep[8]	+ _rep[5]*rhs._rep[9]	+ _rep[9]*rhs._rep[10]	+ _rep[13]*rhs._rep[11],
					_rep[1]*rhs._rep[12]	+ _rep[5]*rhs._rep[13]	+ _rep[9]*rhs._rep[14]	+ _rep[13]*rhs._rep[15],

					_rep[2]*rhs._rep[0]	+ _rep[6]*rhs._rep[1]	+ _rep[10]*rhs._rep[2]	+ _rep[14]*rhs._rep[3],
					_rep[2]*rhs._rep[4]	+ _rep[6]*rhs._rep[5]	+ _rep[10]*rhs._rep[6]	+ _rep[14]*rhs._rep[7],
					_rep[2]*rhs._rep[8]	+ _rep[6]*rhs._rep[9]	+ _rep[10]*rhs._rep[10]	+ _rep[14]*rhs._rep[11],
					_rep[2]*rhs._rep[12]	+ _rep[6]*rhs._rep[13]	+ _rep[10]*rhs._rep[14]	+ _rep[14]*rhs._rep[15],

					_rep[3]*rhs._rep[0]	+ _rep[7]*rhs._rep[1]	+ _rep[11]*rhs._rep[2]	+ _rep[15]*rhs._rep[3],
					_rep[3]*rhs._rep[4]	+ _rep[7]*rhs._rep[5]	+ _rep[11]*rhs._rep[6]	+ _rep[15]*rhs._rep[7],
					_rep[3]*rhs._rep[8]	+ _rep[7]*rhs._rep[9]	+ _rep[11]*rhs._rep[10]	+ _rep[15]*rhs._rep[11],
					_rep[3]*rhs._rep[12]	+ _rep[7]*rhs._rep[13]	+ _rep[11]*rhs._rep[14]	+ _rep[15]*rhs._rep[15]);
	}

	unittest
	{
		auto m1 = mat4(
					   4.500, 4.100, 6.700, 8.900,
					   4.100, 9.800, 7.900, 7.600,
					   1.200, 0.100, 4.500, 6.700,
					   4.100, 3.400, 5.600, 7.800);
		//	assertEquals(m1, m1*mat4.identity);
		auto m2 = mat4(
					   1.000, 2.000, 3.000, 4.000,
					   5.000, 6.000, 7.000, 8.000,
					   9.000, 0.000, 1.000, 2.000,
					   3.000, 4.000, 5.000, 6.000);

		auto result = mat4(32.700,  37.600,  58.400,  75.400,
						   88.300, 107.200, 157.200, 199.400,
						   49.900,  43.800,  76.000, 102.400,
						   60.500,  72.400, 107.800, 137.400);

		//assertEquals(m2*m1, result);
	}

	bool opEquals(mat4 rhs)
	{
		foreach(i;0..16)
		{
			if(!approxEqual(_rep[i], rhs._rep[i]))
				return false;
		}
		return true;
	}

	float4 opBinaryRight(string op)(float4 rhs) if (op == "*")
	{
		return float4(
					  _rep[0]*rhs.x + _rep[4]*rhs.y + _rep[8]*rhs.z + _rep[12]*rhs.w,
					  _rep[1]*rhs.x + _rep[5]*rhs.y + _rep[9]*rhs.z + _rep[13]*rhs.w,
					  _rep[2]*rhs.x + _rep[6]*rhs.y + _rep[10]*rhs.z + _rep[14]*rhs.w,
					  _rep[3]*rhs.x + _rep[7]*rhs.y + _rep[11]*rhs.z + _rep[15]*rhs.w
					  );
	}

	@property Matrix4 inverse()
	in
	{
		assert(this.determinant);
	}
	body
	{
		mat4 inv;
		inv._rep[ 0] =  _rep[5] * _rep[10] * _rep[15] - _rep[5] * _rep[11] * _rep[14] - _rep[9] * _rep[6] * _rep[15] + _rep[9] * _rep[7] * _rep[14] + _rep[13] * _rep[6] * _rep[11] - _rep[13] * _rep[7] * _rep[10];
		inv._rep[ 4] = -_rep[4] * _rep[10] * _rep[15] + _rep[4] * _rep[11] * _rep[14] + _rep[8] * _rep[6] * _rep[15] - _rep[8] * _rep[7] * _rep[14] - _rep[12] * _rep[6] * _rep[11] + _rep[12] * _rep[7] * _rep[10];
		inv._rep[ 8] =  _rep[4] * _rep[ 9] * _rep[15] - _rep[4] * _rep[11] * _rep[13] - _rep[8] * _rep[5] * _rep[15] + _rep[8] * _rep[7] * _rep[13] + _rep[12] * _rep[5] * _rep[11] - _rep[12] * _rep[7] * _rep[ 9];
		inv._rep[12] = -_rep[4] * _rep[ 9] * _rep[14] + _rep[4] * _rep[10] * _rep[13] + _rep[8] * _rep[5] * _rep[14] - _rep[8] * _rep[6] * _rep[13] - _rep[12] * _rep[5] * _rep[10] + _rep[12] * _rep[6] * _rep[ 9];
		inv._rep[ 1] = -_rep[1] * _rep[10] * _rep[15] + _rep[1] * _rep[11] * _rep[14] + _rep[9] * _rep[2] * _rep[15] - _rep[9] * _rep[3] * _rep[14] - _rep[13] * _rep[2] * _rep[11] + _rep[13] * _rep[3] * _rep[10];
		inv._rep[ 5] =  _rep[0] * _rep[10] * _rep[15] - _rep[0] * _rep[11] * _rep[14] - _rep[8] * _rep[2] * _rep[15] + _rep[8] * _rep[3] * _rep[14] + _rep[12] * _rep[2] * _rep[11] - _rep[12] * _rep[3] * _rep[10];
		inv._rep[ 9] = -_rep[0] * _rep[ 9] * _rep[15] + _rep[0] * _rep[11] * _rep[13] + _rep[8] * _rep[1] * _rep[15] - _rep[8] * _rep[3] * _rep[13] - _rep[12] * _rep[1] * _rep[11] + _rep[12] * _rep[3] * _rep[ 9];
		inv._rep[13] =  _rep[0] * _rep[ 9] * _rep[14] - _rep[0] * _rep[10] * _rep[13] - _rep[8] * _rep[1] * _rep[14] + _rep[8] * _rep[2] * _rep[13] + _rep[12] * _rep[1] * _rep[10] - _rep[12] * _rep[2] * _rep[ 9];
		inv._rep[ 2] =  _rep[1] * _rep[ 6] * _rep[15] - _rep[1] * _rep[ 7] * _rep[14] - _rep[5] * _rep[2] * _rep[15] + _rep[5] * _rep[3] * _rep[14] + _rep[13] * _rep[2] * _rep[ 7] - _rep[13] * _rep[3] * _rep[ 6];
		inv._rep[ 6] = -_rep[0] * _rep[ 6] * _rep[15] + _rep[0] * _rep[ 7] * _rep[14] + _rep[4] * _rep[2] * _rep[15] - _rep[4] * _rep[3] * _rep[14] - _rep[12] * _rep[2] * _rep[ 7] + _rep[12] * _rep[3] * _rep[ 6];
		inv._rep[10] =  _rep[0] * _rep[ 5] * _rep[15] - _rep[0] * _rep[ 7] * _rep[13] - _rep[4] * _rep[1] * _rep[15] + _rep[4] * _rep[3] * _rep[13] + _rep[12] * _rep[1] * _rep[ 7] - _rep[12] * _rep[3] * _rep[ 5];
		inv._rep[14] = -_rep[0] * _rep[ 5] * _rep[14] + _rep[0] * _rep[ 6] * _rep[13] + _rep[4] * _rep[1] * _rep[14] - _rep[4] * _rep[2] * _rep[13] - _rep[12] * _rep[1] * _rep[ 6] + _rep[12] * _rep[2] * _rep[ 5];
		inv._rep[ 3] = -_rep[1] * _rep[ 6] * _rep[11] + _rep[1] * _rep[ 7] * _rep[10] + _rep[5] * _rep[2] * _rep[11] - _rep[5] * _rep[3] * _rep[10] - _rep[ 9] * _rep[2] * _rep[ 7] + _rep[ 9] * _rep[3] * _rep[ 6];
		inv._rep[ 7] =  _rep[0] * _rep[ 6] * _rep[11] - _rep[0] * _rep[ 7] * _rep[10] - _rep[4] * _rep[2] * _rep[11] + _rep[4] * _rep[3] * _rep[10] + _rep[ 8] * _rep[2] * _rep[ 7] - _rep[ 8] * _rep[3] * _rep[ 6];
		inv._rep[11] = -_rep[0] * _rep[ 5] * _rep[11] + _rep[0] * _rep[ 7] * _rep[ 9] + _rep[4] * _rep[1] * _rep[11] - _rep[4] * _rep[3] * _rep[ 9] - _rep[ 8] * _rep[1] * _rep[ 7] + _rep[ 8] * _rep[3] * _rep[ 5];
		inv._rep[15] =  _rep[0] * _rep[ 5] * _rep[10] - _rep[0] * _rep[ 6] * _rep[ 9] - _rep[4] * _rep[1] * _rep[10] + _rep[4] * _rep[2] * _rep[ 9] + _rep[ 8] * _rep[1] * _rep[ 6] - _rep[ 8] * _rep[2] * _rep[ 5];

		auto invDet = 1f/(_rep[0] * inv._rep[0] + _rep[1] * inv._rep[4] + _rep[2] * inv._rep[8] + _rep[3] * inv._rep[12]); //We don't want to recalculate the determinant completely

		foreach(ref e; inv._rep)
			e *= invDet;
		return inv;
	}

	unittest
	{
		auto mat1 = mat4(
						 4.500, 4.100, 6.700, 8.900,
						 4.100, 9.800, 7.900, 7.600,
						 1.200, 0.100, 4.500, 6.700,
						 4.100, 3.400, 5.600, 7.800);
		auto inv = mat4(
						1.977409936,	 -0.326901296,	 -0.597275476,	 -1.424711909,
						-2.285971092,	  0.314328169,	  0.189687958,	  2.139146066,
						5.983665326,	 -0.411172418,	 -0.477882727,	 -6.016397020,
						-4.338923699,	  0.330018600,	  0.574363291,	  4.264108399);


		//assertEquals(mat1.inverse, inv);
	}

	public static Matrix4 CreateRotationZ(float angle)
	{
		float s = sin(angle);
		float c = cos(angle);

		return Matrix4(c, -s, 0, 0,
					   s,  c, 0, 0,
					   0,  0, 1, 0,
					   0,  0, 0, 1);
	}

	unittest
	{
		//	assertEquals(CreateRotationZ(PI), 
		//			 mat4(-1,0,0,0,
		//				  0,-1,0,0,
		//				  0,0,1,0,
		//				  0,0,0,1));
	}

	public static Matrix4 CreateRotationX(float angle)
	{
		float s = sin(angle);
		float c = cos(angle);

		return Matrix4(1, 0,  0, 0,
					   0, c, -s, 0,
					   0, s,  c, 0,
					   0, 0,  0, 1);
	}

	unittest
	{
		//	assertEquals(CreateRotationX(PI), 
		//			 mat4(1,0,0,0,
		//				  0,-1,0,0,
		//				  0,0,-1,0,
		//				  0,0,0,1));
	}

	public static Matrix4 CreateRotationY(float angle)
	{
		float s = sin(angle);
		float c = cos(angle);

		return Matrix4( c, 0, s, 0,
						0, 1, 0, 0,
					   -s, 0, c, 0,
					   0, 0, 0, 1);
	}

	unittest
	{
		//	assertEquals(CreateRotationY(PI), 
		//			 mat4(-1,0,0,0,
		//				  0,1,0,0,
		//				  0,0,-1,0,
		//				  0,0,0,1));
	}

	public static Matrix4 CreateRotation(float x, float y, float z)
	{
		float Cx = cos(x), Sx = sin(x);
		float Cy = cos(y), Sy = sin(y);
		float Cz = cos(z), Sz = sin(z);

		return Matrix4(		Cy*Cz,				-Cy*Sz,			   Sy,	0,
							Sx*Sy*Cz + Cx*Sz,  -Sx*Sy*Sz + Cx*Cz, -Sx*Cy,	0,
					   -Cx*Sy*Cz + Sx*Sz,   Cx*Sy*Sz + Sx*Cz,  Cx*Cy, 0,
					   0,							0,					0,		1);

	}

	unittest
	{
		float xAngle = 1.312f, yAngle = 5.245f, zAngle = 3.415;
		auto rotX = CreateRotationX(xAngle);
		auto rotY = CreateRotationY(yAngle);
		auto rotZ = CreateRotationZ(zAngle);

		auto rotXYZ = rotX*rotY*rotZ;

		//assertEquals(CreateRotation(xAngle, yAngle, zAngle), rotXYZ);
	}

	public static Matrix4 CreateScale(float x, float y, float z)
	{
		return Matrix4( x, 0, 0, 0,
						0, y, 0, 0,
					   0, 0, z, 0,
					   0, 0, 0, 1);
	}

	unittest
	{
		float x = 1.4f, y = 4.5f, z = 18.41f;
		auto mat = Matrix4(	x, 0, 0, 0,
							0, y, 0, 0,
						   0, 0, z, 0,
						   0, 0, 0, 1);
		//	assertEquals(CreateScale(x,y,z), mat);
	}

	public static Matrix4 CreateOrthographic(float left, float right, float top, float bottom, float near, float far)
	{
		return Matrix4(2 / (right - left), 0, 0, -(right + left) / (right - left),
					   0, 2 / (top - bottom), 0 , -(top + bottom) / (top - bottom),
					   0, 0, -2 / (far - near), -(far + near) / (far - near),
					   0, 0, 0, 1);
	}

	public static Matrix4 CreateInvOrthographic(float left, float right, float top, float bottom, float near, float far)
	{
		return Matrix4((right - left)/2, 0, 0, (right + left)/2,
					   0, (top - bottom)/2, 0 , (top + bottom)/2,
					   0, 0, (far - near)/(-2), (far + near)/(-2),
					   0, 0, 0, 1);
	}

	unittest
	{
		float left = 1.31f, right = 21.3f, top = 4.234f, bottom = 3.14f, near = 42.213f, far = 14.12f;
		auto orto = CreateOrthographic(left, right, top, bottom, near, far);
		auto inv = CreateInvOrthographic(left, right, top, bottom, near, far);
		//assertEquals(orto * inv, identity);
	}
}