#include <pthread.h>
#include <Carbon/Carbon.h>
#include <CoreGraphics/CoreGraphics.h>
#include "MultitouchSupport.h"
#include "../settings.h"

#define try(...) \
    if ((__VA_ARGS__) == -1) { \
        fprintf(stderr, "`%s` failed", #__VA_ARGS__); \
        exit(1); \
    }

typedef struct {
    float lowx, lowy, upx, upy;
} Range;

typedef struct {
    bool useArg;
    Range trackpadRange;
    Range screenRange;
    bool emitMouseEvent;
    bool requireCommandKey;
} Settings;

Settings settings = { false, { 0.25, 0.25, 0.75, 0.75 }, { 0, 0, 1, 1, }, true, false };
CGSize screenSize;

int mouseEventNumber = 0;
pthread_mutex_t mouseEventNumber_mutex;
#define MAGIC_NUMBER 12345

bool isCmdKeyPressed() {
    CGEventFlags flags = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState);
    return (flags & kCGEventFlagMaskCommand) != 0;
}

double _rangeRatio(double n, double lower, double upper) {
    if (n < lower || n > upper) {
        return -1;
    }
    return (n - lower) / (upper - lower);
}

double _reverseRangeRatio(double n, double lower, double upper) {
    if (n < 0) {
        return n;
    }
    return n * (upper - lower) + lower;
}

MTPoint _map(double normx, double normy) {
    MTPoint point = {
        .x = _rangeRatio(
            normx, settings.trackpadRange.lowx, settings.trackpadRange.upx),
        .y = _rangeRatio(
            normy, settings.trackpadRange.lowy, settings.trackpadRange.upy),
    };

    point.x = _reverseRangeRatio(
            point.x, settings.screenRange.lowx, settings.screenRange.upx);
    point.y = _reverseRangeRatio(
            point.y, settings.screenRange.lowy, settings.screenRange.upy);

    point.x *= screenSize.width;
    point.y *= screenSize.height;
    return point;
}

void moveCursor(double x, double y) {
    if (settings.requireCommandKey && !isCmdKeyPressed()) {
        return;
    }

    static double lastX = -1.0;
    static double lastY = -1.0;

    const double threshold = JITTER_THRESHOLD;
    double alpha = JITTER_ALPHA;

    if (alpha <= 0.0) {
        alpha = 0.1;
    } else if (alpha > 1.0) {
        alpha = 1.0;
    }

    if (lastX >= 0.0 && lastY >= 0.0) {
        double dx = x - lastX;
        double dy = y - lastY;
        double dist2 = dx * dx + dy * dy;

        if (dist2 < threshold * threshold) {
            return;
        }

        x = lastX + alpha * dx;
        y = lastY + alpha * dy;
    }

    lastX = x;
    lastY = y;

    CGPoint point = (CGPoint){
        .x = x < 0 ? 0 : x >= screenSize.width  ? screenSize.width  - 1 : x,
        .y = y < 0 ? 0 : y >= screenSize.height ? screenSize.height - 1 : y,
    };

    if (settings.useArg && settings.emitMouseEvent ||
        !settings.useArg && emitMouseEvent)
    {
        CGEventRef event = CGEventCreateMouseEvent(
            NULL,
            kCGEventMouseMoved,
            point,
            kCGMouseButtonLeft);
        CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);
        CGEventSetIntegerValueField(event, kCGMouseEventSubtype, 3);

        try(pthread_mutex_lock(&mouseEventNumber_mutex));
        CGEventSetIntegerValueField(event, kCGMouseEventNumber, mouseEventNumber);
        try(pthread_mutex_unlock(&mouseEventNumber_mutex));

        CGEventPost(kCGHIDEventTap, event);
    } else {
        CGWarpMouseCursorPosition(point);
    }
}

int trackpadCallback(
    MTDeviceRef device,
    MTTouch *data,
    size_t nFingers,
    double timestamp,
    size_t frame)
{
    #define GESTURE_PHASE_NONE 0
    #define GESTURE_PHASE_MAYSTART 1
    #define GESTURE_PHASE_BEGAN 2
    #define GESTURE_TIMEOUT 0.02

    static MTPoint fingerPosition = { 0, 0 },
                   oldFingerPosition = { 0, 0 };
    static int32_t oldPathIndex = -1;
    static double oldTimeStamp = 0,
                  startTrackTimeStamp = 0;
    static size_t oldFingerCount = 1;
    static int gesturePhase = GESTURE_PHASE_NONE;
    static bool gesturePaths[20] = { 0 };

    if (nFingers == 0) {
        for (int i = 0; i < 20; i++) {
            gesturePaths[i] = false;
        }
        gesturePhase = GESTURE_PHASE_NONE;
        oldFingerCount = 0;
        startTrackTimeStamp = 0;
        return 0;
    }

    size_t activeFingers = 0;
    for (size_t i = 0; i < nFingers; i++) {
        float nx = data[i].normalizedVector.position.x;
        float ny = 1 - data[i].normalizedVector.position.y;
        if (nx >= settings.trackpadRange.lowx && nx <= settings.trackpadRange.upx &&
            ny >= settings.trackpadRange.lowy && ny <= settings.trackpadRange.upy) {
            activeFingers++;
        }
    }

    // No fingers in active region — ignore all outside touches
    if (activeFingers == 0) {
        return 0;
    }

    if (!startTrackTimeStamp) {
        startTrackTimeStamp = timestamp;
    }

    if (oldFingerCount != 1 && activeFingers == 1 && !gesturePhase) {
        gesturePhase = GESTURE_PHASE_MAYSTART;
        oldFingerCount = activeFingers;
        return 0;
    };

    if (activeFingers == 1 && timestamp - startTrackTimeStamp < GESTURE_TIMEOUT) {
        return 0;
    }

    if (activeFingers > 1 && (
        timestamp - startTrackTimeStamp < GESTURE_TIMEOUT ||
        gesturePhase != GESTURE_PHASE_NONE))
    {
        gesturePhase = GESTURE_PHASE_BEGAN;
        for (int i = 0; i < nFingers; i++) {
            gesturePaths[data[i].pathIndex] = true;
        }
        if (!(DISABLE_CURSOR_ON_MULTITOUCH && activeFingers > 1)) {
            moveCursor(fingerPosition.x, fingerPosition.y);
        }
        oldFingerCount = activeFingers;
        return 0;
    };

    if (gesturePhase == GESTURE_PHASE_BEGAN) {
        for (int i = 0; i < nFingers; i++) {
            if (gesturePaths[data[i].pathIndex]) {
                if (!(DISABLE_CURSOR_ON_MULTITOUCH && activeFingers > 1)) {
                    moveCursor(fingerPosition.x, fingerPosition.y);
                }
                if (activeFingers > 1) {
                    return 0;
                }
                break;
            }
        }
    }

    gesturePhase = GESTURE_PHASE_NONE;
    oldFingerCount = activeFingers;

    MTTouch *f = &data[0];
    for (int i = 0; i < nFingers; i++){
        if (data[i].pathIndex == oldPathIndex) {
            f = &data[i];
            break;
        }
    }
    // If tracked finger is outside region but active fingers exist inside, switch
    if (activeFingers > 0) {
        float fx = f->normalizedVector.position.x;
        float fy = 1 - f->normalizedVector.position.y;
        if (fx < settings.trackpadRange.lowx || fx > settings.trackpadRange.upx ||
            fy < settings.trackpadRange.lowy || fy > settings.trackpadRange.upy) {
            for (int i = 0; i < nFingers; i++) {
                float nx = data[i].normalizedVector.position.x;
                float ny = 1 - data[i].normalizedVector.position.y;
                if (nx >= settings.trackpadRange.lowx && nx <= settings.trackpadRange.upx &&
                    ny >= settings.trackpadRange.lowy && ny <= settings.trackpadRange.upy) {
                    f = &data[i];
                    oldPathIndex = f->pathIndex;
                    break;
                }
            }
        }
    }

    oldFingerPosition = fingerPosition;
    fingerPosition = (settings.useArg ? _map : map)(
            f->normalizedVector.position.x, 1 - f->normalizedVector.position.y);
    MTPoint velocity = f->normalizedVector.velocity;

    if (fingerPosition.x < 0 || fingerPosition.y < 0) {
        if (f->pathIndex == oldPathIndex) {
            if (fingerPosition.x < 0) {
                fingerPosition.x = oldFingerPosition.x +
                    velocity.x * (timestamp - oldTimeStamp) * 1000;
            }
            if (fingerPosition.y < 0) {
                fingerPosition.y = oldFingerPosition.y -
                    velocity.y * (timestamp - oldTimeStamp) * 1000;
            }

        } else {
            fingerPosition = oldFingerPosition;
        }
    } else {
        oldPathIndex = f->pathIndex;
    }

    if (!(DISABLE_CURSOR_ON_MULTITOUCH && activeFingers > 1)) {
        moveCursor(fingerPosition.x, fingerPosition.y);
    }

    oldTimeStamp = timestamp;
    return 0;
}

bool check_privileges(void) {
    bool result;
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *values[] = { kCFBooleanTrue };

    CFDictionaryRef options;
    options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys, values, sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);

    return result;
}

Range parseRange(char* s) {
    char* token[4 + 1];
    int i = 0;
    for (;(token[i] = strsep(&s, ",")) != NULL && i < 4; i++) { }
    if (i != 4 || token[4] != NULL) {
        fputs("Range format: lowx,lowy,upx,upy and numbers in range [0, 1]", stderr);
        exit(1);
    }
    float num[4];
    for (i = 0; i < 4; i++){
        char* endptr;
        num[i] = strtof(token[i], &endptr);
        if (*endptr) {
            fprintf(stderr, "Invalid number %s\n", token[i]);
            exit(1);
        }
    }
    return (Range) {
        num[0], num[1], num[2], num[3]
    };
}

void parseSettings(int argc, char** argv) {
    int opt;
    while ((opt = getopt(argc, argv, "i:o:ec")) != -1) {
        switch (opt) {
            case 'i':
                settings.trackpadRange = parseRange(optarg);
                settings.useArg = true;
                break;
            case 'o':
                settings.screenRange = parseRange(optarg);
                settings.useArg = true;
                break;
            case 'e':
                settings.emitMouseEvent = true;
                settings.useArg = true;
                break;
            case 'c':
                settings.requireCommandKey = true;
                settings.useArg = true;
                break;
            default:
                fprintf(stderr, "Usage: %s [-i lowx,lowy,upx,upy] [-o lowx,lowy,upx,upy] [-e] [-c]\n", argv[0]);
                exit(EXIT_FAILURE);
        }
    }
}

CGEventRef loggerCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void* context)
{
    int magic_number = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    if (magic_number == MAGIC_NUMBER) {
        return event;
    }
    int eventNumber = CGEventGetIntegerValueField(event, kCGMouseEventNumber);
    try(pthread_mutex_lock(&mouseEventNumber_mutex));
    mouseEventNumber = eventNumber;
    try(pthread_mutex_unlock(&mouseEventNumber_mutex));
    return event;
}

int main(int argc, char** argv) {
    parseSettings(argc, argv);
    screenSize = CGDisplayBounds(CGMainDisplayID()).size;

    try(pthread_mutex_init(&mouseEventNumber_mutex, NULL));

    CFArrayRef deviceList = MTDeviceCreateList();
    for (CFIndex i = 0; i < CFArrayGetCount(deviceList); i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(deviceList, i);
        int familyId;
        MTDeviceGetFamilyID(device, &familyId);
        if (
            familyId >= 98
            && familyId != 112 && familyId != 113
        ) {
            MTRegisterContactFrameCallback(device, (MTFrameCallbackFunction)trackpadCallback);
            MTDeviceStart(device, 0);
        }
    }

    CFRunLoopRun();
    return 0;
}
