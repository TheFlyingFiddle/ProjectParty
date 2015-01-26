module rendering.asyncrenderbuffer;
import graphics;

struct AsyncRenderBuffer(Vertex)
{
	private VAO!Vertex vao;
	private VBO vbo;
	private IBO ibo;

	private Vertex* mappedPtr;
	private uint*   mappedIndexPtr;

	private const int batchSize, batchCount;
	private int mappedStart;
	private int elements;
	private int numVertices;

	this(U)(size_t batchSize, size_t batchCount, ref Program!(U, Vertex) program)
	{
		this.elements   = this.mappedStart = 0;
		this.batchSize  = batchSize;
		this.batchCount = batchCount; 

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vbo.bind();
		this.vbo.initialize(Vertex.sizeof * batchSize * batchCount);

		this.ibo = IBO.create(BufferHint.streamDraw);
		this.ibo.bind();
		this.ibo.initialize(batchSize * 12 * batchCount);

		this.vao = VAO!Vertex.create();
		setupVertexBindings(vao, program, vbo, &ibo);

		vao.unbind();
	}

	void addItems(Vertex[] vertices, uint[] indecies)
	{
		assert(mappedPtr !is null);
		assert(elements + indecies.length <= (mappedStart + batchSize) * 3);
		assert(numVertices + vertices.length < mappedStart + batchSize);

		mappedPtr[0 .. vertices.length] = vertices[];
		mappedPtr += vertices.length;

		mappedIndexPtr[0 .. indecies.length] = indecies[] + numVertices;
		mappedIndexPtr += indecies.length;

		elements += cast(int)indecies.length;
		numVertices += cast(int)vertices.length;
	}

	void map()
	{
		assert(mappedPtr is null, "Can only begin rendering if we are not already rendering!");

		vbo.bind();
		mappedPtr = vbo.mapRange!Vertex(mappedStart,
										batchSize, 
										BufferRangeAccess.unsynchronizedWrite);

		ibo.bind();
		mappedIndexPtr = ibo.mapRange!uint(mappedStart * 3,
										   batchSize * 3,
										   BufferRangeAccess.unsynchronizedWrite);
	}

	int unmap()
	{
		vbo.bind();
		vbo.unmapBuffer();
		mappedPtr = null;

		ibo.bind();
		ibo.unmapBuffer();
		mappedIndexPtr = null;

		int start  = mappedStart * 3;
		mappedStart = (mappedStart + batchSize) % (batchSize * batchCount);
		elements    = mappedStart * 3; 
		numVertices = mappedStart;

		return start;
	}

	void render(U)(uint start, uint count, ref Program!(U,Vertex) program)
	{
		drawElements!(uint, Vertex, U)(this.vao, program, PrimitiveType.triangles, start, count);
	}
}
