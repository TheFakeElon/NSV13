// Optimized version of ISABOUTEQUAL
#define ISEQUIVALENT(a, b, variance) (abs((a) - (b)) < variance)

// 60 / 2pi ~= 9.5488
/// Conversion constant between radians/s and rotations per minute (RPM)
#define RAD_RPM_CONSTANT (60 / (2 * PI))

/// Rotations per minute to radians per second
#define RPM_TO_RADS(R) ((R) / RAD_RPM_CONSTANT)

/// Radians per second to Rotations per minute
#define RADS_TO_RPM(R) ((R) * RAD_RPM_CONSTANT)

/// Calculates torque from wattage (W) and RPM (R)
#define CALC_TORQUE(W, R) (R ? ((W) / RAD_RPM_CONSTANT) / (R) : 0)

/// Calculates power from torque (T) and RPM (R)
#define CALC_POWER(T, R) (R ? ((R) / RAD_RPM_CONSTANT) * (T) : 0)
