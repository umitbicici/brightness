// Private macOS APIs used for display control. The same calls are used by
// established open-source tools (MonitorControl, Lunar); none of them are
// available as public API.

#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>

CF_ASSUME_NONNULL_BEGIN

/// Apple Silicon: an external display's AV service, used for DDC/CI over I2C.
typedef CFTypeRef IOAVServiceRef;

extern IOAVServiceRef _Nullable IOAVServiceCreateWithService(CFAllocatorRef _Nullable allocator,
                                                             io_service_t service) CF_RETURNS_RETAINED;

extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset,
                                   void *outputBuffer, uint32_t outputBufferSize);

extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress,
                                    const void *inputBuffer, uint32_t inputBufferSize);

/// Display information (product name, IORegistry location, EDID, …).
extern CFDictionaryRef _Nullable CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID display)
    CF_RETURNS_RETAINED;

CF_ASSUME_NONNULL_END
