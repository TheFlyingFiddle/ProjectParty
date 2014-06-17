module graphics.framebuffer;

import graphics;
import math;

struct Renderbuffer
{
	package const uint glName, width, height;

	this(InternalFormat format, uint width, uint height, uint samples = 0)
	{
		uint glName;
		gl.genRenderbuffers(1, &glName);

		this.glName = glName;
		this.width = width;
		this.height = height;

		gl.bindRenderbuffer(RenderBufferTarget.renderBuffer, glName);
		if(samples > 0) {
			gl.renderbufferStorageMultisample(RenderBufferTarget.renderBuffer, samples, format, width, height);
		} else {
			gl.renderbufferStorage(RenderBufferTarget.renderBuffer, format, width, height);			
		}
	}

	bool deleted() @property
	{
		return gl.isRenderbuffer(glName) == FALSE;
	}

	void destroy()
	{
		gl.deleteRenderbuffers(1, &glName);
	}
}

alias FBO = FrameBuffer;
struct FrameBuffer 
{
	uint glName;
	
	//Need to fix this.
	uint glImageType, glImageName;
	uint width, height;

	static auto FrameBuffer create()
	{
		uint glName;
		gl.genFramebuffers(1, &glName);
		return FrameBuffer(glName);
	}

	bool deleted() @property
	{
		return gl.isFramebuffer(glName) == FALSE;
	}

	void destroy()
	{
		gl.deleteFramebuffers(1, &glName);
	}

	void attachRenderBuffer(FrameBufferAttachement attachement,
							Renderbuffer buffer)
	{
		gl.framebufferRenderbuffer(FrameBufferTarget.draw, attachement, RenderBufferTarget.renderBuffer, buffer.glName);
	}

	void attachTexture(FrameBufferAttachement attachement,
					   Texture2D texture, uint mipLevel)
	{
		this.width  = texture.width;
		this.height = texture.height;

		this.glImageType = texture.target;
		this.glImageName = texture.glName;

		gl.framebufferTexture2D(FrameBufferTarget.framebuffer, 
								attachement,
								texture.target,
								texture.glName, 
								mipLevel);
	}

	void attachTexture(FrameBufferAttachement attachement,
					   Texture2DMultisample texture)
	{
		this.width  = texture.width;
		this.height = texture.height;

		this.glImageType = texture.target;
		this.glImageName = texture.glName;

		gl.framebufferTexture2D(FrameBufferTarget.framebuffer, 
								attachement,
								texture.target,
								texture.glName, 
								0);
	}

	void attachLayeredTexture(FrameBufferAttachement attachement,
							  Texture2D texture, uint mipLevel, uint layer)	
	{
		gl.framebufferTextureLayer(FrameBufferTarget.draw, attachement, texture.glName, mipLevel, layer);
	}

	void obliterate()
	{
		if(glImageType)
			gl.deleteTextures(1, &glImageName);
		
		gl.deleteFramebuffers(1, &glName);
	}
}	

static void blit(FrameBuffer from, 
				 FrameBuffer to,
				 uint4 fromRect, 
				 uint4 toRect, 
				 BlitMode mode, 
				 BlitFilter filter)
{

	gl.bindFramebuffer(FrameBufferTarget.read, from.glName);
	gl.bindFramebuffer(FrameBufferTarget.draw, to.glName);

	gl.blitFramebuffer(fromRect.x, fromRect.y, fromRect.z, fromRect.w,
					   toRect.x, toRect.y, toRect.z, toRect.w,
					   mode, filter);
}

static void blitToBackbuffer(FrameBuffer from,
							 uint4 fromRect, 
							 uint4 toRect, 
							 BlitMode mode, 
							 BlitFilter filter)
{

	gl.bindFramebuffer(FrameBufferTarget.read, from.glName);
	gl.bindFramebuffer(FrameBufferTarget.draw, 0);

	gl.blitFramebuffer(fromRect.x, fromRect.y, fromRect.z, fromRect.w,
					   toRect.x, toRect.y, toRect.z, toRect.w,
					   mode, filter);
}