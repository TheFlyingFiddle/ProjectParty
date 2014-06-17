module graphics.enums;
import derelict.opengl3.gl3;

enum TRUE = GL_TRUE;
enum FALSE = GL_FALSE;

enum TextureUnit
{
	zero     = GL_TEXTURE0,
	one      = GL_TEXTURE0 + 1,
	two      = GL_TEXTURE0 + 2,
	three    = GL_TEXTURE0 + 3,
	four     = GL_TEXTURE0 + 4,
	five     = GL_TEXTURE0 + 5,
	six      = GL_TEXTURE0 + 6,
	seven    = GL_TEXTURE0 + 7,
	eigth    = GL_TEXTURE0 + 8,
	nine     = GL_TEXTURE0 + 9,
	ten      = GL_TEXTURE0 + 10,
	eleven   = GL_TEXTURE0 + 11,
	twelve   = GL_TEXTURE0 + 12,
	thirteen = GL_TEXTURE0 + 13,
	forteen  = GL_TEXTURE0 + 14,
	fifteen  = GL_TEXTURE0 + 15,
	sixteen  = GL_TEXTURE0 + 16
}

enum ClearFlags
{
	color = GL_COLOR_BUFFER_BIT,
	depth = GL_DEPTH_BUFFER_BIT,
	stencil = GL_STENCIL_BUFFER_BIT,
	colorDepth = color | depth,
	colorStencil = color | stencil,
	depthStencil = depth | stencil,
	all = color | depth | stencil
}

enum LogicOp
{
	clear			 = GL_CLEAR,
	set			 = GL_SET,
	copy			 = GL_COPY,
	copyInverted = GL_COPY_INVERTED,
	noop			 = GL_NOOP,
	invert		 = GL_INVERT,
	and			 = GL_AND,
	nand			 = GL_NAND,
	or				 = GL_OR,
	nor			 = GL_NOR,
	xor			 = GL_XOR,
	equiv			 = GL_EQUIV,
	andReverse   = GL_AND_REVERSE,
	andInverted  = GL_AND_INVERTED,
	orReverse	 = GL_OR_REVERSE,
	orInverted	 = GL_OR_INVERTED
}

enum StencilOp
{
	zero		= GL_ZERO,
	keep		= GL_KEEP,
	replace  = GL_REPLACE,
	incr		= GL_INCR,
	incrWrap = GL_INCR_WRAP,
	decr		= GL_DECR,
	decrWrap = GL_DECR_WRAP,
	invert	= GL_INVERT
}

enum CompareFunc
{
	never = GL_NEVER,
	always = GL_ALWAYS,
	less = GL_LESS,
	greater = GL_GREATER,
	equal = GL_EQUAL,
	notEqual = GL_NOTEQUAL,
	lessEqual = GL_LEQUAL,
	greaterEqual = GL_GEQUAL,
}

enum PrimitiveType
{
	points = GL_POINTS,
	lines = GL_LINES,
	lineStrip = GL_LINE_STRIP,
	lineLoop = GL_LINE_LOOP,
	triangles = GL_TRIANGLES,
	triangleStrip = GL_TRIANGLE_STRIP
}

enum BlitFilter 
{
	nearest = GL_NEAREST,
	linear = GL_LINEAR
}

enum RenderBufferTarget
{
	renderBuffer = GL_RENDERBUFFER
}

enum PixelStoreParam
{
	packSwapBytes	   = GL_PACK_SWAP_BYTES,
	packLSBFirst	   = GL_PACK_LSB_FIRST,
	packRowLength	   = GL_PACK_ROW_LENGTH,
	packImageHeight   = GL_PACK_IMAGE_HEIGHT,
	packSkipPixels    = GL_PACK_SKIP_PIXELS,
	packSkipRows	   = GL_PACK_SKIP_ROWS,
	packSkipImages    = GL_PACK_SKIP_IMAGES,
	packAlignment	   = GL_PACK_ALIGNMENT,
	unpackSwapBytes   = GL_UNPACK_SWAP_BYTES,
	unpackLSBFirst    = GL_UNPACK_LSB_FIRST,
	unpackRowLength   = GL_UNPACK_ROW_LENGTH,
	unpackImageHeight = GL_UNPACK_IMAGE_HEIGHT,
	unpackSkipPixels  = GL_UNPACK_SKIP_PIXELS,
	unpackSkipRows	   = GL_UNPACK_SKIP_ROWS,
	unpackAlignment	= GL_UNPACK_ALIGNMENT
}

enum Capability
{
	blend						  = GL_BLEND,
	clipDistance0		     = GL_CLIP_DISTANCE0,
	clipDistance1			  = GL_CLIP_DISTANCE1,
	clipDistance2			  = GL_CLIP_DISTANCE2,
	clipDistance3			  = GL_CLIP_DISTANCE3,
	clipDistance4			  = GL_CLIP_DISTANCE4,
	clipDistance5			  = GL_CLIP_DISTANCE5,
	clipDistance6			  = GL_CLIP_DISTANCE6,
	clipDistance7			  = GL_CLIP_DISTANCE7,
	colorLogicOp			  = GL_COLOR_LOGIC_OP,
	cullFace					  = GL_CULL_FACE,
	depthClamp				  = GL_DEPTH_CLAMP,
	depthTest				  = GL_DEPTH_TEST,
	dither					  = GL_DITHER,
	frameBufferSRGB		  = GL_FRAMEBUFFER_SRGB,
	lineSmooth				  = GL_LINE_SMOOTH,
	multisample				  = GL_MULTISAMPLE,
	polygonOffsetFil		  = GL_POLYGON_OFFSET_FILL,
	polygonOffsetLine		  = GL_POLYGON_OFFSET_LINE,
	polygonOffsetPoint	  = GL_POLYGON_OFFSET_POINT,
	primitiveRestart		  = GL_PRIMITIVE_RESTART,
	sampleAlphaToCoverage  = GL_SAMPLE_ALPHA_TO_COVERAGE,
	sampleAlphaToOne		  = GL_SAMPLE_ALPHA_TO_ONE,
	sampleCoverage			  = GL_SAMPLE_COVERAGE,
	scissorTest				  = GL_SCISSOR_TEST,
	stencilTest				  = GL_STENCIL_TEST,
	textureCubeMapSeamless = GL_TEXTURE_CUBE_MAP_SEAMLESS,
	programPointSize       = GL_PROGRAM_POINT_SIZE,
	rasterizerDiscard		  = GL_RASTERIZER_DISCARD
}


enum FrameBufferTarget
{
	draw = GL_DRAW_FRAMEBUFFER,
	read = GL_READ_FRAMEBUFFER,
	framebuffer = GL_FRAMEBUFFER
}

enum BlitMode
{
	color = GL_COLOR_BUFFER_BIT,
	depth = GL_DEPTH_BUFFER_BIT, 
	stencil = GL_STENCIL_BUFFER_BIT,
	colorDepth = color | depth,
	colorStencil = color | stencil,
	depthStencil = depth | stencil,
	all = color | depth | stencil
}


enum HintTarget
{
	lineSmooth				  = GL_LINE_SMOOTH_HINT,
	polygonSmooth			  = GL_POLYGON_SMOOTH_HINT,
	textureCompression	  = GL_TEXTURE_COMPRESSION_HINT,
	fragmentShaderDerivate = GL_FRAGMENT_SHADER_DERIVATIVE_HINT
}

enum HintQuality
{
	fastest		= GL_FASTEST,
	nicest	   = GL_NICEST,
	dontCare	   = GL_DONT_CARE
}

enum ConditionalRenderMode 
{
	queryWait = GL_QUERY_WAIT,
	queryNoWait = GL_QUERY_NO_WAIT,
	queryByRegionWait = GL_QUERY_BY_REGION_WAIT,
	queryByRegionNoWait = GL_QUERY_BY_REGION_NO_WAIT
}

enum DrawBuffer
{
	none				  = GL_NONE,
	frontLeft		  = GL_FRONT_LEFT,
	frontRight		  = GL_FRONT_RIGHT,
	backLeft			  = GL_BACK_LEFT,
	backRight		  = GL_BACK_RIGHT,
	color0		  = GL_COLOR_ATTACHMENT0,
	color1		  = GL_COLOR_ATTACHMENT1,
	color2		  = GL_COLOR_ATTACHMENT2,
	color3		  = GL_COLOR_ATTACHMENT3,
	color4		  = GL_COLOR_ATTACHMENT4,
	color5		  = GL_COLOR_ATTACHMENT5,
	color6		  = GL_COLOR_ATTACHMENT6,
	color7		  = GL_COLOR_ATTACHMENT7,
	color8		  = GL_COLOR_ATTACHMENT8,
	color9		  = GL_COLOR_ATTACHMENT9,
	color10		  = GL_COLOR_ATTACHMENT10,
	color11		  = GL_COLOR_ATTACHMENT11,
	color12		  = GL_COLOR_ATTACHMENT12,
	color13		  = GL_COLOR_ATTACHMENT13,
	color14		  = GL_COLOR_ATTACHMENT14,
	color15		  = GL_COLOR_ATTACHMENT15,
}

enum BlendFactor
{
	zero = GL_ZERO,
	one = GL_ONE,
	srcColor = GL_SRC_COLOR,
	oneMinusSrcColor = GL_ONE_MINUS_SRC_COLOR,
	srcAlpha = GL_SRC_ALPHA,
	oneMinusSourceAlpha = GL_ONE_MINUS_SRC_ALPHA,
	dstColor = GL_DST_COLOR,
	oneMinusDstColor = GL_ONE_MINUS_DST_COLOR,
	dstAlpha = GL_DST_ALPHA,
	oneMinusDstAlpha = GL_ONE_MINUS_DST_ALPHA,
	constantColor = GL_CONSTANT_COLOR,
	oneMinusConstantColor = GL_ONE_MINUS_CONSTANT_COLOR,
	constantAlpha = GL_CONSTANT_ALPHA,
	oneMinusConstantAlpha = GL_ONE_MINUS_CONSTANT_ALPHA,
	srcAlphaSaturate = GL_SRC_ALPHA_SATURATE
}

enum BlendEquation
{
	add = GL_FUNC_ADD,
	subtract = GL_FUNC_SUBTRACT,
	reverseSubtract = GL_FUNC_REVERSE_SUBTRACT,
	min = GL_MIN,
	max = GL_MAX
}

enum PolygonMode
{
	fill = GL_FILL,
	line = GL_LINE,
	point = GL_POINT
}

enum FrontFace
{
	clockWise = GL_CW,
	counterClockWise = GL_CCW
}

enum Face
{
	back = GL_BACK,
	front = GL_FRONT
}

enum FloatPName
{
	pointSize = GL_POINT_SIZE,
	pointSizeGranularity = GL_POINT_SIZE_GRANULARITY
}

enum Float2Pname
{
	pointSizeGranularity = GL_POINT_SIZE_RANGE
}

enum PointSpriteOrigin
{
	lowerLeft	= GL_LOWER_LEFT,
	upperLeft	= GL_UPPER_LEFT
}	

enum PointParam
{
	pointFadeThresholdSize = GL_POINT_FADE_THRESHOLD_SIZE,
	pointSpriteCoordOrigin = GL_POINT_SPRITE_COORD_ORIGIN
}

enum ProvokingMode
{
	fistVertexConvention = GL_FIRST_VERTEX_CONVENTION,
	lastVertexConvention = GL_LAST_VERTEX_CONVENTION
}


enum FrameBufferAttachement
{
	depth			  = GL_DEPTH_ATTACHMENT,
	stencil		  = GL_STENCIL_ATTACHMENT,
	depthStencil  = GL_DEPTH_STENCIL_ATTACHMENT,
	color0		  = GL_COLOR_ATTACHMENT0,
	color1		  = GL_COLOR_ATTACHMENT1,
	color2		  = GL_COLOR_ATTACHMENT2,
	color3		  = GL_COLOR_ATTACHMENT3,
	color4		  = GL_COLOR_ATTACHMENT4,
	color5		  = GL_COLOR_ATTACHMENT5,
	color6		  = GL_COLOR_ATTACHMENT6,
	color7		  = GL_COLOR_ATTACHMENT7,
	color8		  = GL_COLOR_ATTACHMENT8,
	color9		  = GL_COLOR_ATTACHMENT9,
	color10		  = GL_COLOR_ATTACHMENT10,
	color11		  = GL_COLOR_ATTACHMENT11,
	color12		  = GL_COLOR_ATTACHMENT12,
	color13		  = GL_COLOR_ATTACHMENT13,
	color14		  = GL_COLOR_ATTACHMENT14,
	color15		  = GL_COLOR_ATTACHMENT15,
}

enum ProgramProperty : uint
{
	deleted = GL_DELETE_STATUS,
	linked = GL_LINK_STATUS,
	valid = GL_VALIDATE_STATUS,
	infoLogLength = GL_INFO_LOG_LENGTH,
	numAttachedShaders = GL_ATTACHED_SHADERS,
	activeAttributes = GL_ACTIVE_ATTRIBUTES,
	activeAttributesMaxLength = GL_ACTIVE_ATTRIBUTE_MAX_LENGTH,
	activeUniforms = GL_ACTIVE_UNIFORMS,
	activeUniformsMaxLength = GL_ACTIVE_UNIFORM_MAX_LENGTH,
	activeUniformBlocks = GL_ACTIVE_UNIFORM_BLOCKS,
	activeUniformsBlocksMaxNameLength = GL_ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH,
	transformFeedbackBufferMode = GL_TRANSFORM_FEEDBACK_BUFFER_MODE,
	transformFeedbackVaryings = GL_TRANSFORM_FEEDBACK_VARYINGS,
	transformFeedbackVaryingMaxLength = GL_TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH,
	geometryVerticesOut = GL_GEOMETRY_VERTICES_OUT,
	geometryInputType = GL_GEOMETRY_INPUT_TYPE,
	geometryOutputType = GL_GEOMETRY_OUTPUT_TYPE
}

enum FeedbackMode 
{
	separateAttribs = GL_SEPARATE_ATTRIBS,
	interleavedAttribs = GL_INTERLEAVED_ATTRIBS
}

enum UniformType
{
	float_ = GL_FLOAT,
	float2 = GL_FLOAT_VEC2,
	float3 = GL_FLOAT_VEC3,
	float4 = GL_FLOAT_VEC4,
	int_ = GL_INT,
	int2 = GL_INT_VEC2,
	int3 = GL_INT_VEC3,
	int4 = GL_INT_VEC4,
	uint_ = GL_UNSIGNED_INT,
	uint2 = GL_UNSIGNED_INT_VEC2,
	uint3 = GL_UNSIGNED_INT_VEC3,
	uint4 = GL_UNSIGNED_INT_VEC4,
	mat2 = GL_FLOAT_MAT2,
	mat3 = GL_FLOAT_MAT3,
	mat4 = GL_FLOAT_MAT4,
	mat2x3 = GL_FLOAT_MAT2x3,
	mat2x4 = GL_FLOAT_MAT2x4,
	mat3x2 = GL_FLOAT_MAT3x2,
	mat3x4 = GL_FLOAT_MAT3x4,
	mat4x2 = GL_FLOAT_MAT4x2,
	mat4x3 = GL_FLOAT_MAT4x3,
	sampler1D = GL_SAMPLER_1D,
	sampler2D = GL_SAMPLER_2D,
	sampler3D = GL_SAMPLER_3D,
	samplerCube = GL_SAMPLER_CUBE,
	sampler1DShadow = GL_SAMPLER_1D_SHADOW,
	sampler2DShadow = GL_SAMPLER_2D_SHADOW,
	sampler1DArray = GL_SAMPLER_1D_ARRAY,
	sampler2DArray = GL_SAMPLER_2D_ARRAY,
	sampler1DArrayShadow = GL_SAMPLER_1D_ARRAY_SHADOW,
	sampler2DArrayShadow = GL_SAMPLER_2D_ARRAY_SHADOW,
	sampler2DMultisample = GL_SAMPLER_2D_MULTISAMPLE,
	sampler2DMultisampleArray = GL_SAMPLER_2D_MULTISAMPLE_ARRAY,
	samplerCubeShadow = GL_SAMPLER_CUBE_SHADOW,
	samplerBuffer = GL_SAMPLER_BUFFER,
	sampler2DRect = GL_SAMPLER_2D_RECT,
	sampler2DRectShadow = GL_SAMPLER_2D_RECT_SHADOW,
	sampler1Di = GL_INT_SAMPLER_1D,
	sampler2Di = GL_INT_SAMPLER_2D,
	sampler3Di = GL_INT_SAMPLER_3D,
	samplerCubei = GL_INT_SAMPLER_CUBE,
	sampler1DArrayi = GL_INT_SAMPLER_1D_ARRAY,
	sampler2DArrayi = GL_INT_SAMPLER_2D_ARRAY,
	sampler2DMultisamplei = GL_INT_SAMPLER_2D_MULTISAMPLE,
	sampler2DMultisampleArrayi = GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY,
	samplerBufferi = GL_INT_SAMPLER_BUFFER,
	sampler2DRecti = GL_INT_SAMPLER_2D_RECT,
	sampler1Dui = GL_UNSIGNED_INT_SAMPLER_1D,
	sampler2Dui = GL_UNSIGNED_INT_SAMPLER_2D,
	sampler3Dui = GL_UNSIGNED_INT_SAMPLER_3D,
	samplerCubeui = GL_UNSIGNED_INT_SAMPLER_CUBE,
	sampler1DArrayui = GL_UNSIGNED_INT_SAMPLER_1D_ARRAY,
	sampler2DArrayui = GL_UNSIGNED_INT_SAMPLER_2D_ARRAY,
	sampler2DMultisampleui = GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE,
	sampler2DMultisampleArrayui = GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY,
	samplerBufferui = GL_UNSIGNED_INT_SAMPLER_BUFFER,
	sampler2DRectui = GL_UNSIGNED_INT_SAMPLER_2D_RECT
}


enum QueryTarget
{	
	samplesPassed = GL_SAMPLES_PASSED,
	anySamplesPassed = GL_ANY_SAMPLES_PASSED,
	primitivesGenerated = GL_PRIMITIVES_GENERATED,
	transformFeedbackPrimitivesWritten = GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN,
	timeElapsed = GL_TIME_ELAPSED,
	timeStamp = GL_TIMESTAMP
}


enum ShaderType 
{
	vertex = GL_VERTEX_SHADER,
	fragment = GL_FRAGMENT_SHADER, 
	geometry = GL_GEOMETRY_SHADER
}

enum ShaderParameter
{
	shaderType = GL_SHADER_TYPE,
	compileStatus = GL_COMPILE_STATUS,
	deleteStatus = GL_DELETE_STATUS,
	infoLogLength = GL_INFO_LOG_LENGTH,
	shaderSourceLength = GL_SHADER_SOURCE_LENGTH
}



enum SamplerParam
{
	wrapT		   = GL_TEXTURE_WRAP_T,
	wrapR		   = GL_TEXTURE_WRAP_R,
	wrapS		   = GL_TEXTURE_WRAP_S,
	minFilter   = GL_TEXTURE_MIN_FILTER,
	magFilter   = GL_TEXTURE_MAG_FILTER,
	minLod	   = GL_TEXTURE_MIN_LOD,
	maxLod	   = GL_TEXTURE_MAX_LOD,
	lodBias	   = GL_TEXTURE_LOD_BIAS,
	compareMode = GL_TEXTURE_COMPARE_MODE,
	compareFunc = GL_TEXTURE_COMPARE_FUNC
}

enum TextureMinFilter
{
	nearest				   = GL_NEAREST,
	linear				   = GL_LINEAR,
	nearestMipmapNearest = GL_NEAREST_MIPMAP_NEAREST,
	linearMipmapNearest	= GL_LINEAR_MIPMAP_NEAREST,
	nearestMipmapLinear	= GL_NEAREST_MIPMAP_LINEAR,
	linearMipmapLinear	= GL_LINEAR_MIPMAP_LINEAR
}

enum TextureMagFilter
{
	nearest	= GL_NEAREST,
	linear	= GL_LINEAR
}	

enum WrapMode
{
	clampToEdge		= GL_CLAMP_TO_EDGE,
	clampToBorder	= GL_CLAMP_TO_BORDER,
	mirroredRepeat = GL_MIRRORED_REPEAT,
	repeat			= GL_REPEAT
}

enum CompareMode
{
	compareRefToTexture = GL_COMPARE_REF_TO_TEXTURE,
	none = GL_NONE
}


enum TextureTarget
{
	texture1D = GL_TEXTURE_1D,
	texture2D = GL_TEXTURE_2D,
	texture3D = GL_TEXTURE_3D,
	textureRect = GL_TEXTURE_RECTANGLE,
	textureCube = GL_TEXTURE_CUBE_MAP,
	texture1DArray = GL_TEXTURE_1D_ARRAY,
	texture2DArray = GL_TEXTURE_2D_ARRAY,
	texture2DMultisample = GL_TEXTURE_2D_MULTISAMPLE,
	texture2DMultisampleArray = GL_TEXTURE_2D_MULTISAMPLE_ARRAY,
	textureBuffer = GL_TEXTURE_BUFFER
}

enum TextureCubeFace 
{
	posetiveX = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
	negativeX = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
	posetiveY = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
	negativeY = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
	posetiveZ = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
	negativeZ = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
}

enum InternalFormat
{
	//RED
	red8 = GL_R8,
	red8i = GL_R8I,
	red8ui = GL_R8UI,
	red8snorm = GL_R8_SNORM,

	red16 = GL_R16,
	red16i = GL_R16I,
	red16ui = GL_R16UI,
	red16f = GL_R16F,
	red16snorm = GL_R16_SNORM,

	red32i = GL_R32I,
	red32ui = GL_R32UI,
	red32f = GL_R32F,

	//RG
	rg8 = GL_RG8,
	rg8i = GL_RG8I,
	rg8ui = GL_RG8UI,
	rg8snorm = GL_RG8_SNORM,

	rg16 = GL_RG16,
	rg16i = GL_RG16I,
	rg16ui = GL_RG16UI,
	rg16f = GL_RG16F,
	rg16snorm = GL_RG16_SNORM,

	rg32i = GL_RG32I,
	rg32ui = GL_RG32UI,
	rg32f = GL_RG32F,

	//RGBA
	rgba8 = GL_RGBA8,
	rgba8i = GL_RGBA8I,
	rgba8ui = GL_RGBA8UI,
	rgba8snorm = GL_RGBA8_SNORM,

	rgba16 = GL_RGBA16,
	rgba16i = GL_RGBA16I,
	rgba16ui = GL_RGBA16UI,
	rgba16f = GL_RGBA16F,
	rgba16snorm = GL_RGBA16_SNORM,

	rgba32i = GL_RGBA32I,
	rgba32ui = GL_RGBA32UI,
	rgba32f = GL_RGBA32F,

	//RGB
	rgb8 = GL_RGB8,
	rgb8i = GL_RGB8I,
	rgb8ui = GL_RGB8UI,
	rgb8snorm = GL_RGB8_SNORM,

	rgb16 = GL_RGB16,
	rgb16i = GL_RGB16I,
	rgb16ui = GL_RGB16UI,
	rgb16f = GL_RGB16F,
	rgb16snorm = GL_RGB16_SNORM,

	rgb32i = GL_RGB32I,
	rgb32ui = GL_RGB32UI,
	rgb32f = GL_RGB32F,

	//Compressed
	compressedRedRGTC1 = GL_COMPRESSED_RED_RGTC1,
	compressedRgRGTC2 = GL_COMPRESSED_RG_RGTC2,

	//TODO implement dtx compressed textures here.

	//Special Required
	rgb9_e5 = GL_RGB9_E5,
	rgb10_a2 = GL_RGB10_A2,
	rbg10_a2ui = GL_RGB10_A2UI,
	r11f_g11f_b10f = GL_R11F_G11F_B10F,
	srgb8 = GL_SRGB8,
	srgb8_alpha8 = GL_SRGB8_ALPHA8,
	depthComponent16 = GL_DEPTH_COMPONENT16,
	depthComponent24 = GL_DEPTH_COMPONENT24,
	depthComponrnt32f = GL_DEPTH_COMPONENT32F,
	depth24_stencil8 = GL_DEPTH24_STENCIL8,
	depth32f_stencil8 = GL_DEPTH32F_STENCIL8
}

enum ColorFormat
{
	depthComponent = GL_DEPTH_COMPONENT,
	stencilIndex = GL_STENCIL_INDEX,
	depthStencil = GL_DEPTH_STENCIL,
	red = GL_RED,
	green = GL_GREEN,
	blue = GL_BLUE,
	rg = GL_RG,
	rgb = GL_RGB,
	bgr = GL_BGR,
	rgba = GL_RGBA,
	bgra = GL_BGRA,
	redInt = GL_RED_INTEGER,
	greenInt = GL_GREEN_INTEGER,
	blueInt = GL_BLUE_INTEGER,
	rbInt = GL_RG_INTEGER,
	rgbInt = GL_RGB_INTEGER,
	bgrInt = GL_BGR_INTEGER,
	rgbaInt = GL_RGBA_INTEGER,
	bgraInt = GL_BGRA_INTEGER,
}

enum IndexBufferType
{
	ushort_ = GL_UNSIGNED_SHORT,
	uint_	= GL_UNSIGNED_INT
}

enum ColorType
{
	byte_ = GL_BYTE,
	short_ = GL_SHORT,
	int_ = GL_INT,
	float_ = GL_FLOAT,
	halfFloat = GL_HALF_FLOAT,
	ubyte_ = GL_UNSIGNED_BYTE,
	ushort_ = GL_UNSIGNED_SHORT,
	uint_ = GL_UNSIGNED_INT,

	ubyte_3_3_2 = GL_UNSIGNED_BYTE_3_3_2,
	ubyte_2_3_3_rev = GL_UNSIGNED_BYTE_2_3_3_REV,

	ushort_5_6_5 = GL_UNSIGNED_SHORT_5_6_5,
	ushort_5_6_5_rev = GL_UNSIGNED_SHORT_5_6_5_REV,
	ushort_5_5_5_1 = GL_UNSIGNED_SHORT_5_5_5_1,
	ushort_1_5_5_5_rev = GL_UNSIGNED_SHORT_1_5_5_5_REV, 
	ushort_4_4_4_4 = GL_UNSIGNED_SHORT_4_4_4_4,
	ushort_4_4_4_4_rev = GL_UNSIGNED_SHORT_4_4_4_4_REV,

	uint_8_8_8_8 = GL_UNSIGNED_INT_8_8_8_8,
	uint_8_8_8_8_rev = GL_UNSIGNED_INT_8_8_8_8_REV,
	uint_10_10_10_2 = GL_UNSIGNED_INT_10_10_10_2,
	uint_2_10_10_10 = GL_UNSIGNED_INT_2_10_10_10_REV
}

enum TextureParameter
{
	baseLevel = GL_TEXTURE_BASE_LEVEL,
	maxLevel = GL_TEXTURE_MAX_LEVEL
}


enum VertexAttributeType
{
	float_ = GL_FLOAT,
	float2 = GL_FLOAT_VEC2,
	float3 = GL_FLOAT_VEC3,
	float4 = GL_FLOAT_VEC4,
	int_ = GL_INT,
	int2 = GL_INT_VEC2,
	int3 = GL_INT_VEC3,
	int4 = GL_INT_VEC4,
	uint_ = GL_UNSIGNED_INT,
	uint2 = GL_UNSIGNED_INT_VEC2,
	uint3 = GL_UNSIGNED_INT_VEC3,
	uint4 = GL_UNSIGNED_INT_VEC4,
	mat2 = GL_FLOAT_MAT2,
	mat3 = GL_FLOAT_MAT3,
	mat4 = GL_FLOAT_MAT4,
	mat2x3 = GL_FLOAT_MAT2x3,
	mat2x4 = GL_FLOAT_MAT2x4,
	mat3x2 = GL_FLOAT_MAT3x2,
	mat3x4 = GL_FLOAT_MAT3x4,
	mat4x2 = GL_FLOAT_MAT4x2,
	mat4x3 = GL_FLOAT_MAT4x3,
}

enum BufferHint 
{
	streamDraw = GL_STREAM_DRAW,
	streamRead = GL_STREAM_READ,
	streamCopy = GL_STREAM_COPY,
	staticDraw = GL_STATIC_DRAW,
	staticRead = GL_STATIC_READ,
	staticCopy = GL_STATIC_COPY,
	dynamicDraw = GL_DYNAMIC_DRAW,
	dynamicRead = GL_DYNAMIC_READ,
	dynamicCopy = GL_DYNAMIC_COPY
}

enum BufferAccess
{
	read = GL_READ_ONLY,
	write = GL_WRITE_ONLY,
	readWrite = GL_READ_WRITE
}

enum BufferRangeAccess
{
	read = GL_MAP_READ_BIT,
	write = GL_MAP_WRITE_BIT,
	readWrite = read | write,
	invalidateRangeWrite = GL_MAP_INVALIDATE_RANGE_BIT | write,
	invalidateBufferWrite = GL_MAP_INVALIDATE_BUFFER_BIT | write,
	flushExplicitWrite = GL_MAP_FLUSH_EXPLICIT_BIT | write,
	unsynchronizedRead = GL_MAP_UNSYNCHRONIZED_BIT | read,
	unsynchronizedWrite = GL_MAP_UNSYNCHRONIZED_BIT | write,
	unsynchronizedReadWrite = GL_MAP_UNSYNCHRONIZED_BIT | readWrite
}

enum BufferTarget
{
	vertex = GL_ARRAY_BUFFER,
	index = GL_ELEMENT_ARRAY_BUFFER,
	pixelPack = GL_PIXEL_PACK_BUFFER,
	pixelUnpack = GL_PIXEL_UNPACK_BUFFER,
	texture = GL_TEXTURE_BUFFER,
	uniform = GL_UNIFORM_BUFFER,
	read    = GL_COPY_READ_BUFFER,
	write   = GL_COPY_WRITE_BUFFER
}

bool isUniformType(T)(UniformType ut)
{
	import math, graphics.color;

	alias U = UniformType;
	static if(is(T == float))
		return ut == U.float_;
	static if(is(T == float2))
		return ut == U.float2;
	static if(is(T == float3))
		return ut == U.float3_;
	static if(is(T == float4) || is(T == Color))
		return ut == U.float4;

	static if(is(T == int))
		return ut == U.int_ ||
			ut == U.sampler1D || 
			ut == U.sampler2D || 
			ut == U.sampler3D;

	static if(is(T == int2))
		return ut == U.int2;
	static if(is(T == int3))
		return ut == U.int3_;
	static if(is(T == int4))
		return ut == U.int4;

	static if(is(T == uint))
		return ut == U.uint_;
	static if(is(T == uint2))
		return ut == U.uint2;
	static if(is(T == uint3))
		return ut == U.uint3_;
	static if(is(T == uint4))
		return ut == U.uint4;

	static if(is(T == mat2))
		return ut == U.mat2;
	static if(is(T == mat3))
		return ut == U.mat3;
	static if(is(T == mat4))
		return ut == U.mat4;
	else 
		static assert("Uniform type not yet supported! Add it!");
}

bool isVertexArrayType(T)(VertexAttributeArray at)
{
	alias A = VertexAttributeArray;
	static if(is(T == float))
		return ut == A.float_;
	static if(is(T == float2))
		return ut == A.float2;
	static if(is(T == float3))
		return ut == A.float3_;
	static if(is(T == float4))
		return ut == A.float4;

	static if(is(T == int))
		return ut == U.int_;
	static if(is(T == int2))
		return ut == A.int2;
	static if(is(T == int3))
		return ut == A.int3_;
	static if(is(T == int4))
		return ut == A.int4;

	static if(is(T == uint))
		return ut == A.uint_;
	static if(is(T == uint2))
		return ut == A.uint2;
	static if(is(T == uint3))
		return ut == A.uint3_;
	static if(is(T == uint4))
		return ut == A.uint4;

	static if(is(T == mat2))
		return ut == A.mat2;
	static if(is(T == mat3))
		return ut == A.mat3;
	static if(is(T == mat4))
		return ut == A.mat4;
	else 
		static assert("Uniform type not yet supported! Add it!");
}