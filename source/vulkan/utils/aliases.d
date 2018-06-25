module vulkan.utils.aliases;

import vulkan.utils
     , derelict.vulkan;

// Instance
alias availableExtentions       = enumerate!vkEnumerateInstanceExtensionProperties;
alias availableLayers           = enumerate!vkEnumerateInstanceLayerProperties;
// Surface
alias surfaceFormats            = enumerate!vkGetPhysicalDeviceSurfaceFormatsKHR;
alias surfaceCapabilities       = acquire!vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
alias surfacePresentations      = enumerate!vkGetPhysicalDeviceSurfacePresentModesKHR;
alias surfaceSupport            = acquire!vkGetPhysicalDeviceSurfaceSupportKHR;
// Swapchain
alias swapchainImages           = enumerate!vkGetSwapchainImagesKHR;
alias acquireNextImage          = acquire!vkAcquireNextImageKHR;
// Physical Device
alias physicalDevices           = enumerate!vkEnumeratePhysicalDevices;
alias features                  = acquire!vkGetPhysicalDeviceFeatures;
alias properties                = acquire!vkGetPhysicalDeviceProperties;
alias queueFamilyProperties     = enumerate!vkGetPhysicalDeviceQueueFamilyProperties;
alias availableExtentions       = enumerate!vkEnumerateDeviceExtensionProperties;
