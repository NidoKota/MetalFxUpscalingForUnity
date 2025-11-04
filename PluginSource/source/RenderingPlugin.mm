#include "PlatformBase.h"
#include "RenderAPI.h"

#include <assert.h>
#include <math.h>
#include <vector>
#include <string>

#include "Unity/IUnityGraphicsMetal.h"
#include "DebugUtility.hpp"
#import <Metal/Metal.h>
#import <MetalFX/MetalFX.h>

// --------------------------------------------------------------------------
// SetTextureFromUnity

void* g_TextureHandle = NULL;
int   g_TextureWidth  = 0;
int   g_TextureHeight = 0;

void* g_UpscaledTextureHandle = NULL;
int   g_UpscaledTextureWidth  = 0;
int   g_UpscaledTextureHeight = 0;

IUnityGraphicsMetal*   g_MetalGraphics;
id<MTLDevice>          g_Device;
id<MTLCommandQueue>    g_CommandQueue;
id<MTLFXSpatialScaler> g_SpatialScaler;
MTLFXSpatialScalerColorProcessingMode g_ColorProcessingMode;

extern "C" int Test()
{
    return 123;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API SetLogCallback(void (*logCallback)(const char*), void (*logErrorCallback)(const char*))
{
    g_logCallback = logCallback;
    g_logErrorCallback = logErrorCallback;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API SetTextureFromUnity(
    void* textureHandle, int w, int h,
    void* upscaled, int upscaledW, int upscaledH,
    MTLFXSpatialScalerColorProcessingMode colorProcessingMode)
{
    g_TextureHandle = textureHandle;
    g_TextureWidth = w;
    g_TextureHeight = h;
    
    g_UpscaledTextureHandle = upscaled;
    g_UpscaledTextureWidth = upscaledW;
    g_UpscaledTextureHeight = upscaledH;
    
    g_ColorProcessingMode = colorProcessingMode;
}

extern "C" id<MTLTexture> UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API CreatePrivateTexture(int width, int height, MTLPixelFormat pixelFormat)
{
    MTLTextureDescriptor* desc = [[MTLTextureDescriptor alloc] init];
    desc.pixelFormat = pixelFormat;
    desc.width = width;
    desc.height = height;
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    desc.textureType = MTLTextureType2D;
    desc.mipmapLevelCount = 1;
    return [g_Device newTextureWithDescriptor:desc];
}

// --------------------------------------------------------------------------
// UnitySetInterfaces

void UNITY_INTERFACE_API OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType);
void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces);

IUnityInterfaces* s_UnityInterfaces = NULL;
IUnityGraphics* s_Graphics = NULL;

extern "C" void	UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginLoad(IUnityInterfaces* unityInterfaces)
{
	s_UnityInterfaces = unityInterfaces;
	s_Graphics = s_UnityInterfaces->Get<IUnityGraphics>();
	s_Graphics->RegisterDeviceEventCallback(OnGraphicsDeviceEvent);

	OnGraphicsDeviceEvent(kUnityGfxDeviceEventInitialize);
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginUnload()
{
	s_Graphics->UnregisterDeviceEventCallback(OnGraphicsDeviceEvent);
}

// --------------------------------------------------------------------------
// GraphicsDeviceEvent

UnityGfxRenderer s_DeviceType = kUnityGfxRendererNull;

void UNITY_INTERFACE_API OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType)
{
	if (eventType == kUnityGfxDeviceEventInitialize)
	{
		s_DeviceType = s_Graphics->GetRenderer();
	}
    
    ProcessDeviceEvent(eventType, s_UnityInterfaces);

	if (eventType == kUnityGfxDeviceEventShutdown)
	{
		s_DeviceType = kUnityGfxRendererNull;
	}
}


// --------------------------------------------------------------------------
// OnRenderEvent

void CreateResources()
{
    g_SpatialScaler = nil;
}

void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces)
{
    if (type == kUnityGfxDeviceEventInitialize)
    {
        g_MetalGraphics = interfaces->Get<IUnityGraphicsMetal>();
        
        g_Device = g_MetalGraphics->MetalDevice();
        g_CommandQueue = [g_Device newCommandQueue];
        
        CreateResources();
    }
    else if (type == kUnityGfxDeviceEventShutdown)
    {
        g_CommandQueue = nil;
        g_Device = nil;
        g_SpatialScaler = nil;
    }
}

void Upscale()
{
    LOG("log by objective-cpp aaaaaaiiiiiiuuuu");
    
    id<MTLTexture> tex = (__bridge id<MTLTexture>)g_TextureHandle;
    id<MTLTexture> upscaledTex = (__bridge id<MTLTexture>)g_UpscaledTextureHandle;
    
    if (!g_Device || !g_CommandQueue || !tex)
    {
        return;
    }
    
    if (!g_SpatialScaler ||
        g_SpatialScaler.inputWidth != g_TextureWidth ||
        g_SpatialScaler.inputHeight != g_TextureHeight ||
        g_SpatialScaler.outputWidth != g_UpscaledTextureWidth ||
        g_SpatialScaler.outputHeight != g_UpscaledTextureHeight)
    {
        MTLFXSpatialScalerDescriptor* desc = [[MTLFXSpatialScalerDescriptor alloc] init];
        
        desc.inputWidth = g_TextureWidth;
        desc.inputHeight = g_TextureHeight;
        desc.outputWidth = g_UpscaledTextureWidth;
        desc.outputHeight = g_UpscaledTextureHeight;
        desc.colorTextureFormat = tex.pixelFormat;
        desc.outputTextureFormat = upscaledTex.pixelFormat;
        desc.colorProcessingMode = g_ColorProcessingMode;
        
        LOG("tex.usage : " << tex.usage << "\n" <<
            "tex.storageMode : " << tex.storageMode << "\n" <<
            "tex.width : " << tex.width << "\n" <<
            "tex.height : " << tex.height << "\n" <<
            "desc.inputWidth : " << desc.inputWidth << "\n" <<
            "desc.inputHeight : " << desc.inputHeight << "\n" <<
            "\n" <<
            "upscaledTex.usage : " << upscaledTex.usage << "\n" <<
            "upscaledTex.storageMode : " << upscaledTex.storageMode << "\n" <<
            "upscaledTex.width : " << upscaledTex.width << "\n" <<
            "upscaledTex.height : " << upscaledTex.height << "\n" <<
            "desc.outputWidth : " << desc.outputWidth << "\n" <<
            "desc.outputHeight : " << desc.outputHeight);
        
        g_SpatialScaler = [desc newSpatialScalerWithDevice:g_Device];
    }
    
    if (upscaledTex && g_SpatialScaler && g_MetalGraphics)
    {
        g_MetalGraphics->EndCurrentCommandEncoder();
        
        id<MTLCommandBuffer> commandBuffer = [g_CommandQueue commandBuffer];
        //id<MTLCommandBuffer> commandBuffer = g_MetalGraphics->CurrentCommandBuffer();
        if (commandBuffer)
        {
            g_SpatialScaler.colorTexture = tex;
            g_SpatialScaler.outputTexture = upscaledTex;
            [g_SpatialScaler encodeToCommandBuffer:commandBuffer];
            
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
        }
    }
}

void UNITY_INTERFACE_API OnRenderEvent(int eventID)
{
	if (eventID == 1)
	{
        Upscale();
	}
}

// --------------------------------------------------------------------------
// GetRenderEventFunc

extern "C" UnityRenderingEvent UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API GetRenderEventFunc()
{
	return OnRenderEvent;
}
