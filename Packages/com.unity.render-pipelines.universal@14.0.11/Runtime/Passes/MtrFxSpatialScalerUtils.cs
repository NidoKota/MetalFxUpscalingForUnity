// ===== CUSTOM MODIFICATION START =====
// Modified by: Matsubara on 2025/09/02
using System;
using System.Runtime.InteropServices;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

namespace UnityEngine.Rendering.Universal
{
    public static class MtrFxSpatialScalerUtils
    {
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void LogCallbackInternal([MarshalAs(UnmanagedType.LPStr)] string message);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void LogErrorCallbackInternal([MarshalAs(UnmanagedType.LPStr)] string message);

        private static GCHandle _logCallbackInternalHandle;
        private static GCHandle _logErrorCallbackInternalHandle;
        
        private static void CallLogCallbackInternal(string str)
        {
            Debug.Log(str);
        }

        private static void CallLogErrorCallbackInternal(string str)
        {
            Debug.LogError(str);
        }

        [DllImport("RenderingPlugin")]
        private static extern void SetLogCallback(LogCallbackInternal logCallback, LogErrorCallbackInternal logErrorCallback);

#if (PLATFORM_IOS || PLATFORM_TVOS || PLATFORM_BRATWURST || PLATFORM_SWITCH) && !UNITY_EDITOR
        [DllImport("__Internal")]
#else
        [DllImport("RenderingPlugin")]
#endif
        private static extern void SetTextureFromUnity(
            nint texture, int w, int h, 
            nint upscaled, int upscaledW, int upscaledH,
            MtlFxSpatialScalerColorProcessingMode colorProcessingMode);
        
#if (PLATFORM_IOS || PLATFORM_TVOS || PLATFORM_BRATWURST || PLATFORM_SWITCH) && !UNITY_EDITOR
        [DllImport("__Internal")]
#else
        [DllImport("RenderingPlugin")]
#endif
        private static extern nint CreatePrivateTexture(int width, int height, MtlPixelFormat pixelFormat);

#if (PLATFORM_IOS || PLATFORM_TVOS || PLATFORM_BRATWURST || PLATFORM_SWITCH) && !UNITY_EDITOR
        [DllImport("__Internal")]
#else
        [DllImport("RenderingPlugin")]
#endif
        private static extern nint GetRenderEventFunc();

#if (PLATFORM_IOS || PLATFORM_TVOS || PLATFORM_BRATWURST || PLATFORM_SWITCH) && !UNITY_EDITOR
        [DllImport("__Internal")]
#else
        [DllImport("RenderingPlugin")]
#endif
        private static extern int Test();

        static MtrFxSpatialScalerUtils()
        {
            _logCallbackInternalHandle = GCHandle.Alloc((LogCallbackInternal)CallLogCallbackInternal);
            _logErrorCallbackInternalHandle = GCHandle.Alloc((LogErrorCallbackInternal)CallLogErrorCallbackInternal);

            SetLogCallback(
                (LogCallbackInternal)_logCallbackInternalHandle.Target,
                (LogErrorCallbackInternal)_logErrorCallbackInternalHandle.Target);
        }

        // protected override void Dispose(bool disposing)
        // {
        //     _logCallbackInternalHandle.Free();
        //     _logErrorCallbackInternalHandle.Free();
        // }

        public static void DoUpscale(
            CommandBuffer cmd, 
            nint sourcePtr, 
            nint upscaledPtr, 
            Vector2 inputSize, 
            Vector2 outputSize,
            MtlFxSpatialScalerColorProcessingMode colorProcessingMode)
        {
            // using (new ProfilingScope(cmd, new ProfilingSampler(ProfilerTag)))
            {
                SetTextureFromUnity(
                    sourcePtr, (int) inputSize.x, (int) inputSize.y,
                    upscaledPtr, (int) outputSize.x, (int) outputSize.y,
                    colorProcessingMode);
                
                cmd.IssuePluginEvent(GetRenderEventFunc(), 1);
            }
        }
        
        public static RTHandle CreatePrivateTexture(
            int width, 
            int height, 
            TextureFormat format, 
            bool mipmap = false, 
            bool liner = false)
        {
            nint texturePtr = CreatePrivateTexture(width, height, format.ToMtlFormat());
            
            Texture2D texture = Texture2D.CreateExternalTexture(
                width, 
                height, 
                format, 
                mipmap,
                liner,
                texturePtr
            );
            
            RTHandle rtHandle = RTHandles.Alloc(texture);
            return rtHandle;
        }
        
        private static bool PrivateTextureNeedsReAlloc(
            RTHandle handle,
            int width, 
            int height, 
            TextureFormat format,
            bool mipmap = false, 
            bool liner = false)
        {
            if (handle == null)
                return true;
            
            Texture texture = handle;
            
            if (texture.width != width || texture.height != height)
                return true;
            
            GraphicsFormat graphicsFormat = GraphicsFormatUtility.GetGraphicsFormat(format, !liner);
            
            return texture.graphicsFormat != graphicsFormat || texture.mipmapCount != 0 == mipmap;
        }
        
        public static bool ReAllocatePrivateTextureIfNeeded(
            ref RTHandle handle,
            int width, 
            int height, 
            TextureFormat format,
            bool mipmap = false, 
            bool liner = false)
        {
            if (PrivateTextureNeedsReAlloc(handle, width, height, format, mipmap, liner))
            {
                handle = CreatePrivateTexture(width, height, format, mipmap, liner);
                return true;
            }
            return false;
        }
        
        public static RTHandle CreatePrivateTexture(
            int width, 
            int height, 
            GraphicsFormat format, 
            bool mipmap = false, 
            bool liner = false)
        {
            TextureFormat textureFormat = GraphicsFormatUtility.GetTextureFormat(format);
            
            nint texturePtr = CreatePrivateTexture(width, height, textureFormat.ToMtlFormat());
            
            
            Texture2D texture = Texture2D.CreateExternalTexture(
                width, 
                height, 
                textureFormat, 
                mipmap,
                liner,
                texturePtr
            );
            
            RTHandle rtHandle = RTHandles.Alloc(texture);
            return rtHandle;
        }
        
        private static bool PrivateTextureNeedsReAlloc(
            RTHandle handle,
            int width, 
            int height, 
            GraphicsFormat format,
            bool mipmap = false, 
            bool liner = false)
        {
            if (handle == null)
                return true;
            
            Texture texture = handle;
            
            if (texture.width != width || texture.height != height)
                return true;
            
            return texture.graphicsFormat != format || texture.mipmapCount != 0 == mipmap;
        }
        
        public static bool ReAllocatePrivateTextureIfNeeded(
            ref RTHandle handle,
            int width, 
            int height, 
            GraphicsFormat format,
            bool mipmap = false, 
            bool liner = false)
        {
            if (PrivateTextureNeedsReAlloc(handle, width, height, format, mipmap, liner))
            {
                handle = CreatePrivateTexture(width, height, format, mipmap, liner);
                return true;
            }
            return false;
        }
    }
}
// ===== CUSTOM MODIFICATION END =====