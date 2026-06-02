#pragma once

// Do not remove this. This variable is initialized in main program
extern CGSize screenSize;
// Emit mouse event or wrap cursor. Default is warp cursor
bool emitMouseEvent = true;

// Helper function: lower and upper has to be without 0 to 1 inclusive
static inline double rangeRatio(double n, double lower, double upper) {
    if (n < lower || n > upper) {
        return -1;
    }
    return (n - lower) / (upper - lower);
}

// Compulsory: Modify this function to change how relative position of trackpad is mapped to normalized screen coordinates. Return negative number for invalid finger position
static inline MTPoint map(double normx, double normy) {
    // whole trackpad to whole screen
    MTPoint point = {
        .x = normx,
        .y = normy,
    };
    //scaling the points up to the screen size
    point.x *= screenSize.width;
    point.y *= screenSize.height;
    return point;
}


// Jitter / smoothing settings for absolute cursor mode
static const double JITTER_THRESHOLD = 4.0;  // in screen pixels (try 4–10)

// Smoothing factor for cursor motion (0..1).
// If set to 0, it will be clamped to 0.1 in trackpad_mapper_util.c to avoid the cursor getting stuck.
static const double JITTER_ALPHA = 0.6;

// Disable cursor when more than one finger is within the active mapping region
// Fingers/palm touches outside the region are ignored
// Prevents palm or accidental touches from interrupting active finger
static const bool DISABLE_CURSOR_ON_MULTITOUCH = true;
