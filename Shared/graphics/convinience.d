module graphics.convinience;

import graphics;


Texture2D createStandardTexture(uint width, uint height, void[] data)
{
	return Texture2D.create(ColorFormat.rgba,
							ColorType.ubyte_,
							InternalFormat.rgba8,
							width,
							height,
							data);
}

	
FBO createSimpleFBO(uint width, uint height)
{
	auto fbo = FBO.create();
	gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);

	auto tex = createStandardTexture(width, height, null);
	fbo.attachTexture(FrameBufferAttachement.color0, tex, 0);

	gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);

	return fbo;
}

FBO createMultisampleFBO(uint width, uint height, uint samples)
{

	auto fbo = FBO.create();
	gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);

	auto tex = Texture2DMultisample.create(InternalFormat.rgba8, samples, width, height, true);
	fbo.attachTexture(FrameBufferAttachement.color0, tex);

	gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);

	return fbo;
}