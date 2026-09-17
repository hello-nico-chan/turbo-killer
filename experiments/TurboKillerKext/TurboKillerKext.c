//
//  TurboKillerKext.c
//  TurboKillerKext
//
//  Read-only feasibility prototype. This target contains no MSR write path.
//

#include <i386/proc_reg.h>
#include <libkern/libkern.h>
#include <mach/mach_types.h>

static const uint32_t kIA32MiscEnable = 0x1A0;
static const uint64_t kTurboModeDisableMask = 1ULL << 38;

kern_return_t TurboKillerKext_start(kmod_info_t *ki, void *data);
kern_return_t TurboKillerKext_stop(kmod_info_t *ki, void *data);

kern_return_t TurboKillerKext_start(kmod_info_t *ki, void *data)
{
    #pragma unused(ki, data)

    uint32_t low = 0;
    uint32_t high = 0;

    if (rdmsr_carefully(kIA32MiscEnable, &low, &high) != 0) {
        printf("TurboKillerKext: IA32_MISC_ENABLE is unavailable; no changes made.\n");
        return KERN_NOT_SUPPORTED;
    }

    const uint64_t value = ((uint64_t)high << 32) | low;
    const bool turboDisabled = (value & kTurboModeDisableMask) != 0;

    printf(
        "TurboKillerKext: read-only probe: Turbo Boost is %s; no changes made.\n",
        turboDisabled ? "disabled" : "enabled"
    );

    return KERN_SUCCESS;
}

kern_return_t TurboKillerKext_stop(kmod_info_t *ki, void *data)
{
    #pragma unused(ki, data)
    return KERN_SUCCESS;
}
