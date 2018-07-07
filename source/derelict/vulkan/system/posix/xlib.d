/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/

module derelict.vulkan.system.posix.xlib;
version (VK_USE_PLATFORM_XLIB_KHR):
extern(System):

public {
  import derelict.vulkan.base;
  import derelict.vulkan.types;
}

mixin VK_DEFINE_NON_DISPATCHABLE_HANDLE!"XLibDisplayHandle";
alias XLibWindow   = uint;
alias XLibVisualID = uint;

enum VK_KHR_xlib_surface = 1;
enum VK_KHR_XLIB_SURFACE_SPEC_VERSION   = 6;
enum VK_KHR_XLIB_SURFACE_EXTENSION_NAME = "VK_KHR_xlib_surface";

alias VkXlibSurfaceCreateFlagsKHR = VkFlags;

struct VkXlibSurfaceCreateInfoKHR {
  VkStructureType             sType ;
  const(void)*                pNext ;
  VkXlibSurfaceCreateFlagsKHR flags ;
  XLibDisplayHandle           dpy   ;
  XLibWindow                  window;
}

alias PFN_vkCreateXlibSurfaceKHR = nothrow 
    VkResult function( VkInstance                         instance
                     , const(VkXlibSurfaceCreateInfoKHR)* pCreateInfo
                     , const(VkAllocationCallbacks)*      pAllocator
                     , VkSurfaceKHR*                      pSurface );
alias PFN_vkGetPhysicalDeviceXlibPresentationSupportKHR = nothrow 
    VkBool32 function( VkPhysicalDevice  physicalDevice
                     , uint              queueFamilyIndex
                     , XLibDisplayHandle dpy
                     , XLibVisualID      visualID);

mixin template XLibFunctions() {
  PFN_vkCreateXlibSurfaceKHR                        vkCreateXlibSurfaceKHR;
  PFN_vkGetPhysicalDeviceXlibPresentationSupportKHR vkGetPhysicalDeviceXlibPresentationSupportKHR;
  pragma(inline, true)
  void bindFunctionsXLib(alias bind)() {
    bind(cast(void**)&vkCreateXlibSurfaceKHR, "vkCreateXlibSurfaceKHR");
    bind( cast(void**)&vkGetPhysicalDeviceXlibPresentationSupportKHR
        , "vkGetPhysicalDeviceXlibPresentationSupportKHR" );
  }
}

version (none) {
  VkResult vkCreateXlibSurfaceKHR( VkInstance                         instance
                                 , const(VkXlibSurfaceCreateInfoKHR)* pCreateInfo
                                 , const(VkAllocationCallbacks)*      pAllocator
                                 , VkSurfaceKHR*                      pSurface );
  VkBool32 vkGetPhysicalDeviceXlibPresentationSupportKHR( VkPhysicalDevice  physicalDevice
                                                        , uint              queueFamilyIndex
                                                        , XLibDisplayHandle dpy
                                                        , XLibVisualID      visualID );
}
